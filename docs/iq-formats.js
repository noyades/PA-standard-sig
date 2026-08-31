/*
 * iq-formats.js -- turning the library's raw I/Q files into something a signal
 * generator will actually load.
 *
 * Every waveform in Signals/ is written by the MATLAB generators in Code/ as
 * interleaved 32-bit floats, I then Q, little-endian, with no header
 * (Code/WiFi/pa_wifi_*.m: fwrite(interleaved_data, 'single')). That is a fine
 * archival format and a useless instrument format: an ARB wants fixed-point
 * samples, a sample clock, and -- for Rohde & Schwarz -- a level reference so
 * it knows what RF power the file's full scale corresponds to.
 *
 * This module does that conversion in the browser, so the site can hand out a
 * file that loads without an intermediate MATLAB or Python step.
 *
 * Sample rate is not recoverable from the files themselves, so it is supplied:
 *   - Multi-carrier: the generators run wlanWaveformGenerator at
 *     OversamplingFactor osf on a channel of the stated bandwidth, so
 *     fs = bandwidth * osf exactly (20 MHz at 4x is 80 MSa/s).
 *   - Single-carrier: the files are pulse-shaped symbols with no carrier and
 *     no defined symbol rate, so the user picks one. See scRates() for why the
 *     sample rate and the occupied bandwidth cannot be chosen independently.
 */

// MATLAB on x86 writes native byte order, which is little-endian, and every
// browser this site runs in is little-endian too. The check is here so that a
// big-endian host reads the archive correctly rather than silently producing
// garbage samples.
const PLATFORM_LITTLE_ENDIAN = (() => {
  const probe = new ArrayBuffer(2);
  new DataView(probe).setInt16(0, 1, true);
  return new Int16Array(probe)[0] === 1;
})();

const BYTES_PER_FLOAT32_SAMPLE = 8; // float32 I + float32 Q

// Full scale for both instrument formats. -32768 is representable but is
// avoided on purpose: Keysight's ARB documentation asks for a symmetric
// +/-32767 range, and clipping one code costs nothing measurable.
const INT16_FULL_SCALE = 32767;

/*
 * The generator list exists to pick a sensible default format, not to gate
 * anything -- the format checkboxes stay editable whichever generator is
 * chosen, because a user may well be preparing a file for an instrument that
 * is not on this list.
 *
 * typicalMaxClockHz is the base model's ARB sample clock as a rough sanity
 * check only. Options change it on most of these instruments, so it drives a
 * warning that says "check your instrument", never a refusal.
 */
const GENERATORS = [
  {
    id: "generic",
    label: "Other / not listed (raw I/Q)",
    vendor: "",
    defaultFormats: ["raw"],
    typicalMaxClockHz: null,
  },
  {
    id: "keysight-esg",
    label: "Keysight E4438C ESG",
    vendor: "Keysight",
    defaultFormats: ["keysight"],
    typicalMaxClockHz: 100e6,
  },
  {
    id: "keysight-mxg",
    label: "Keysight N5182B MXG / N5172B EXG",
    vendor: "Keysight",
    defaultFormats: ["keysight"],
    typicalMaxClockHz: 200e6,
  },
  {
    id: "keysight-vxg",
    label: "Keysight M9384B / M9383B VXG",
    vendor: "Keysight",
    defaultFormats: ["keysight"],
    typicalMaxClockHz: 2.5e9,
  },
  {
    id: "rs-smbv",
    label: "Rohde & Schwarz SMBV100B",
    vendor: "Rohde & Schwarz",
    defaultFormats: ["rs"],
    typicalMaxClockHz: 300e6,
  },
  {
    id: "rs-smm",
    label: "Rohde & Schwarz SMM100A",
    vendor: "Rohde & Schwarz",
    defaultFormats: ["rs"],
    typicalMaxClockHz: 600e6,
  },
  {
    id: "rs-smw",
    label: "Rohde & Schwarz SMW200A",
    vendor: "Rohde & Schwarz",
    defaultFormats: ["rs"],
    typicalMaxClockHz: 2.4e9,
  },
];

const FORMATS = {
  raw: {
    id: "raw",
    label: "Raw binary — interleaved float32 I/Q (.bin)",
    extension: ".bin",
  },
  keysight: {
    id: "keysight",
    label: "Keysight ARB — 16-bit big-endian I/Q (.wfm)",
    extension: ".wfm",
  },
  rs: {
    id: "rs",
    label: "Rohde & Schwarz ARB — tagged .wv",
    extension: ".wv",
  },
};

/* ------------------------------------------------------------------ *
 * Reading and reshaping
 * ------------------------------------------------------------------ */

// Returns the file as one interleaved Float32Array, [I0, Q0, I1, Q1, ...].
// A trailing partial sample is dropped rather than guessed at; it would mean
// the file is truncated, and half a sample is not a sample.
function readFloat32Iq(arrayBuffer) {
  const wholeSamples = Math.floor(arrayBuffer.byteLength / BYTES_PER_FLOAT32_SAMPLE);
  const usableFloats = wholeSamples * 2;

  if (PLATFORM_LITTLE_ENDIAN) {
    return new Float32Array(arrayBuffer, 0, usableFloats);
  }

  const view = new DataView(arrayBuffer);
  const out = new Float32Array(usableFloats);
  for (let i = 0; i < usableFloats; i += 1) {
    out[i] = view.getFloat32(i * 4, true);
  }
  return out;
}

// Truncates to, or tiles up to, targetSamples complex samples. Tiling repeats
// the waveform end-to-start, which is what an ARB does anyway when it loops a
// segment, so the seam is no worse than the one the instrument would create.
function fitToLength(interleaved, targetSamples) {
  const sourceSamples = interleaved.length / 2;
  if (!targetSamples || targetSamples <= 0 || targetSamples === sourceSamples) {
    return interleaved;
  }
  const out = new Float32Array(targetSamples * 2);
  for (let n = 0; n < targetSamples; n += 1) {
    const src = (n % sourceSamples) * 2;
    out[n * 2] = interleaved[src];
    out[n * 2 + 1] = interleaved[src + 1];
  }
  return out;
}

/*
 * Peak and RMS of the complex envelope, and the ratio between them.
 *
 * Both instrument formats are fixed-point, so the float samples have to be
 * scaled to full scale, and the scaling has to be by the peak *envelope*
 * rather than by the largest |I| or |Q| separately. Scaling per-axis would let
 * the envelope reach sqrt(2) times full scale on a sample where I and Q are
 * both large, which the DAC cannot represent -- the peaks would clip, and
 * peaks are exactly what a PA test waveform exists to exercise.
 */
function iqStats(interleaved) {
  const sampleCount = interleaved.length / 2;
  let peakPower = 0;
  let sumPower = 0;

  for (let n = 0; n < sampleCount; n += 1) {
    const i = interleaved[n * 2];
    const q = interleaved[n * 2 + 1];
    const power = i * i + q * q;
    if (power > peakPower) peakPower = power;
    sumPower += power;
  }

  const peak = Math.sqrt(peakPower);
  const rms = sampleCount > 0 ? Math.sqrt(sumPower / sampleCount) : 0;

  return {
    sampleCount,
    peak,
    rms,
    // Guard the degenerate all-zero case rather than emitting -Infinity into
    // a file header the instrument has to parse.
    paprDb: peak > 0 && rms > 0 ? 20 * Math.log10(peak / rms) : 0,
    // Full scale is the peak envelope, so a normalised file peaks at exactly 1.
    normaliseScale: peak > 0 ? 1 / peak : 1,
  };
}

function quantiseToInt16(value, scale) {
  const scaled = Math.round(value * scale * INT16_FULL_SCALE);
  if (scaled > INT16_FULL_SCALE) return INT16_FULL_SCALE;
  if (scaled < -INT16_FULL_SCALE) return -INT16_FULL_SCALE;
  return scaled;
}

/* ------------------------------------------------------------------ *
 * Keysight ARB (.wfm)
 * ------------------------------------------------------------------ */

/*
 * The ESG/MXG/EXG/VXG waveform format: signed 16-bit, big-endian, I and Q
 * interleaved, no header. The sample rate is not in the file -- it is set on
 * the instrument when the segment is played, which is why a .txt sidecar with
 * the SCPI carrying that rate is written alongside it.
 *
 * Markers are deliberately not written. Downloading a waveform without a
 * marker file makes the instrument create an all-zero marker file for it,
 * which is the right default for a PA test waveform played as a continuous
 * loop.
 */
function toKeysightWfm(interleaved, stats) {
  const sampleCount = interleaved.length / 2;
  const buffer = new ArrayBuffer(sampleCount * 4);
  const view = new DataView(buffer);
  const scale = stats.normaliseScale;

  for (let n = 0; n < sampleCount; n += 1) {
    view.setInt16(n * 4, quantiseToInt16(interleaved[n * 2], scale), false);
    view.setInt16(n * 4 + 2, quantiseToInt16(interleaved[n * 2 + 1], scale), false);
  }

  return buffer;
}

function keysightSection(name, clockHz, stats) {
  return [
    `${name}.wfm -- Keysight ARB`,
    "",
    "  Signed 16-bit integers, big-endian, I and Q interleaved (I0 Q0 I1 Q1 ...),",
    `  no header. ${stats.sampleCount} complex samples, ${stats.sampleCount * 4} bytes.`,
    "  The sample clock is NOT in the file; set it on the instrument.",
    "",
    "  Loading it (N5182B/N5172B; the E4438C uses :MEM:DATA for :MMEM:DATA):",
    `    :MMEM:DATA "NVWFM:${name}",#<block containing the .wfm bytes>`,
    `    :SOUR:RAD:ARB:WAV "NVWFM:${name}"`,
    `    :SOUR:RAD:ARB:SCL:RATE ${clockHz.toFixed(0)}`,
    "    :SOUR:RAD:ARB:STAT ON",
    "    :OUTP:STAT ON",
    "",
    "  No marker file is supplied. The instrument creates an all-zero marker file",
    "  on download, which is what a continuously looped test waveform wants.",
  ].join("\n");
}

/* ------------------------------------------------------------------ *
 * Rohde & Schwarz ARB (.wv)
 * ------------------------------------------------------------------ */

/*
 * The .wv container is a run of ASCII {TAG: value} pairs followed by the I/Q
 * block, which unlike the Keysight format carries its own sample clock and
 * level reference. Samples are signed 16-bit *little*-endian, interleaved.
 *
 * Two details are easy to get wrong:
 *
 * WAVEFORM-<n> counts the bytes after the colon, which is 4 bytes per complex
 * sample plus one for the '#' that introduces the block.
 *
 * LEVEL OFFS carries the RMS and peak levels as positive dB *below* full
 * scale, in that order, and the instrument uses the RMS figure to work out
 * what RF power to produce for a given level setting. Because the samples are
 * normalised to a peak envelope of 1.0, the peak offset is 0 dB and the RMS
 * offset is the waveform's PAPR. Getting these wrong does not corrupt the
 * waveform, but it does shift the output power, so they are computed from the
 * samples actually being written rather than copied from the manifest.
 *
 * The TYPE tag's second field is a checksum over the I/Q block. It is written
 * as 0, which instructs the instrument to skip verification -- the same choice
 * R&S's own IQ tools make. A checksum that is merely believed to be right
 * would turn a loadable file into a rejected one, and it guards against
 * nothing that an HTTPS download and a ZIP CRC have not already covered.
 */
function toRohdeSchwarzWv(interleaved, stats, options) {
  const { clockHz, comment } = options;
  const sampleCount = interleaved.length / 2;
  const scale = stats.normaliseScale;

  const payload = new ArrayBuffer(sampleCount * 4);
  const view = new DataView(payload);
  for (let n = 0; n < sampleCount; n += 1) {
    view.setInt16(n * 4, quantiseToInt16(interleaved[n * 2], scale), true);
    view.setInt16(n * 4 + 2, quantiseToInt16(interleaved[n * 2 + 1], scale), true);
  }

  const rmsOffsetDb = stats.paprDb; // peak is normalised to full scale
  const peakOffsetDb = 0;

  const header =
    "{TYPE: SMU-WV,0}" +
    "{COPYRIGHT: PA Standard Signal Library}" +
    `{COMMENT: ${sanitiseTagValue(comment)}}` +
    `{DATE: ${wvTimestamp(new Date())}}` +
    `{CLOCK: ${clockHz.toFixed(6)}}` +
    `{LEVEL OFFS: ${rsFloat(rmsOffsetDb)},${rsFloat(peakOffsetDb)}}` +
    `{SAMPLES: ${sampleCount}}` +
    `{WAVEFORM-${sampleCount * 4 + 1}: #`;

  const headerBytes = asciiBytes(header);
  const out = new Uint8Array(headerBytes.length + payload.byteLength + 1);
  out.set(headerBytes, 0);
  out.set(new Uint8Array(payload), headerBytes.length);
  out[out.length - 1] = 0x7d; // '}'
  return out;
}

function rsSection(name, clockHz, stats) {
  return [
    `${name}.wv -- Rohde & Schwarz ARB`,
    "",
    "  Tagged .wv container: an ASCII {TAG: value} header followed by signed",
    "  16-bit little-endian I/Q pairs. Unlike the Keysight file this one carries",
    "  its own sample clock and level reference, so selecting it is enough.",
    "",
    "  Header values written:",
    `    CLOCK      ${formatHz(clockHz)}`,
    `    LEVEL OFFS RMS ${stats.paprDb.toFixed(4)} dB, peak 0.0000 dB below full scale`,
    `    SAMPLES    ${stats.sampleCount}`,
    "    TYPE       SMU-WV, checksum 0 (verification skipped, which is what R&S's",
    "               own IQ tools write)",
    "",
    "  Loading it (SMW200A / SMBV100B / SMM100A):",
    `    :SOUR1:BB:ARB:WAV:SEL "/var/user/${name}.wv"`,
    "    :SOUR1:BB:ARB:STAT ON",
    "    :OUTP1:STAT ON",
  ].join("\n");
}

/*
 * One README per bundle rather than a sidecar per format. The things a user
 * has to get right -- what the sample rate is and where it came from, what the
 * amplitude scaling did, and which PAPR figure applies -- are shared across
 * the formats, and repeating them three times invites them to drift.
 */
function exportNotes(context) {
  const {
    entryName,
    sourceFileName,
    safeName,
    formats,
    stats,
    clockHz,
    symbolRateHz,
    occupiedBandwidthHz,
    signalClass,
    rolloff,
    oversampling,
    generatorLabel,
    catalogPapr,
    catalogMeanPacketPapr,
    targetLength,
    rateWarning,
  } = context;

  const lines = [
    `PA Standard Signal Library -- export of ${entryName}`,
    "https://noyades.github.io/PA-standard-sig/",
    "",
    `Source file in the repository : ${sourceFileName}`,
    `Prepared for                  : ${generatorLabel}`,
    "",
    "SAMPLE RATE",
    "",
  ];

  // A raw-only export was never given a rate, so it says so rather than
  // printing "unknown" into a section written as though one were chosen.
  if (!clockHz) {
    lines.push(
      "  None recorded: only the raw archive format was exported, and it carries",
      "  no rate of its own. A multi-carrier file plays at its channel bandwidth",
      "  times its oversampling factor; a single-carrier file has no inherent",
      "  rate at all.",
    );
  } else if (signalClass === "MC") {
    lines.push(
      `  ${formatHz(clockHz)}.`,
      "",
      "  This rate is a property of the file, not a choice. The waveform was",
      `  generated by MATLAB's wlanWaveformGenerator at ${oversampling} oversampling on a`,
      `  ${occupiedBandwidthHz ? formatBandwidthHz(occupiedBandwidthHz) : "?"} channel, so playing it at any other rate moves the whole`,
      "  spectrum and the signal is no longer the standard it claims to be.",
    );
  } else {
    lines.push(
      `  ${formatHz(clockHz)}, giving a symbol rate of ${formatHz(symbolRateHz)} and an`,
      `  occupied bandwidth of ${formatBandwidthHz(occupiedBandwidthHz)}.`,
      "",
      "  Single-carrier files are pulse-shaped symbols with no rate of their own,",
      "  so you chose one. The three figures are not independent:",
      "",
      `      symbol rate = sample rate / ${oversampling.replace("x", "")}   (the files are ${oversampling} oversampled)`,
      `      occupied BW = symbol rate x (1 + ${rolloff})   (RRC roll-off)`,
      "",
      "  Fixing any one of them fixes the other two. Nothing was resampled, so",
      "  the samples -- and the PAPR below -- are exactly those in the archive.",
    );
  }

  if (rateWarning) {
    lines.push("", `  NOTE: ${rateWarning}`);
  }

  lines.push(
    "",
    "AMPLITUDE",
    "",
    `  ${stats.sampleCount} complex samples.`,
    "",
    "  The archived file holds 32-bit floats that are not normalised. Both",
    "  instrument formats are 16-bit fixed point, so the samples were scaled by",
    `  ${stats.normaliseScale.toFixed(6)} to put the peak envelope exactly at full scale`,
    `  (+/-${INT16_FULL_SCALE}). Scaling by the peak envelope rather than by the largest |I|`,
    "  or |Q| separately is what guarantees no sample clips. Quantisation to 16",
    "  bits leaves an error floor below -85 dB relative to the signal, far under",
    "  any PA's own distortion, and moves the PAPR by less than 0.01 dB.",
    "",
    "PAPR AND SETTING THE LEVEL",
    "",
    `  Whole-file PAPR : ${stats.paprDb.toFixed(2)} dB`,
  );

  if (catalogPapr && catalogPapr !== "N/A") {
    lines.push(`  Catalogue PAPR  : ${catalogPapr}`);
  }
  if (catalogMeanPacketPapr && catalogMeanPacketPapr !== "N/A") {
    lines.push(`  Mean packet PAPR: ${catalogMeanPacketPapr}`);
  }

  lines.push(
    "",
    "  These can differ, and the difference is not an error. The catalogue figure",
    "  skips inter-packet idle and trailing zero pad, because that is the honest",
    "  way to describe the signal. The whole-file figure counts them, because the",
    "  instrument plays them: they are part of the average power that comes out",
    "  of the RF port. The whole-file figure is therefore the one written into",
    "  the .wv header and the one to use for headroom.",
    "",
    "  Set the instrument's RF level to the average power you want, and leave at",
    `  least ${stats.paprDb.toFixed(2)} dB of headroom above it so the peaks are not compressed by`,
    "  the generator before they ever reach the device under test.",
    "",
  );

  if (targetLength) {
    lines.push(
      "LENGTH",
      "",
      `  Trimmed or repeated to ${targetLength} samples at your request, on complex-sample`,
      "  boundaries. If it was repeated, the waveform wraps end-to-start, which is",
      "  the same seam the ARB creates when it loops the segment.",
      "",
    );
  }

  lines.push("FILES", "");
  formats.forEach((formatId) => {
    if (formatId === "raw") {
      lines.push(
        `${sourceFileName} -- raw archive format`,
        "",
        "  Interleaved 32-bit floats, I then Q, little-endian, no header. Exactly",
        "  as written by the MATLAB generators in Code/, unmodified except for any",
        "  length change noted above. Read it with numpy.fromfile(path, '<f4') or",
        "  MATLAB's fread(fid, Inf, 'single').",
        "",
      );
    } else if (formatId === "keysight" && clockHz) {
      lines.push(keysightSection(safeName, clockHz, stats), "");
    } else if (formatId === "rs" && clockHz) {
      lines.push(rsSection(safeName, clockHz, stats), "");
    }
  });

  return lines.join("\n");
}

// R&S writes header floats as a 6-decimal mantissa with a two-digit exponent
// ("3.010300e+00"). JavaScript's toExponential produces the shortest exponent
// it can ("3.010300e+0"), so the exponent is padded back out rather than
// handing the instrument's parser a form it has never been shown.
function rsFloat(value) {
  const [mantissa, exponent] = value.toExponential(6).split("e");
  const sign = exponent.startsWith("-") ? "-" : "+";
  const digits = exponent.replace(/^[+-]/, "").padStart(2, "0");
  return `${mantissa}e${sign}${digits}`;
}

function wvTimestamp(date) {
  const pad = (value) => String(value).padStart(2, "0");
  return (
    `${date.getFullYear()}-${pad(date.getMonth() + 1)}-${pad(date.getDate())};` +
    `${pad(date.getHours())}:${pad(date.getMinutes())}:${pad(date.getSeconds())}`
  );
}

// Braces terminate a tag, and non-ASCII has no defined meaning in the header,
// so anything that could break the parser is stripped before it goes in.
function sanitiseTagValue(value) {
  return String(value || "")
    .replace(/[{}]/g, "")
    .replace(/[^\x20-\x7e]/g, " ")
    .trim()
    .slice(0, 200);
}

function asciiBytes(text) {
  const out = new Uint8Array(text.length);
  for (let i = 0; i < text.length; i += 1) {
    out[i] = text.charCodeAt(i) & 0x7f;
  }
  return out;
}

/* ------------------------------------------------------------------ *
 * Sample rates
 * ------------------------------------------------------------------ */

// Multi-carrier: the waveform was generated at OversamplingFactor osf on a
// channel of the stated bandwidth, so the rate is exact and there is nothing
// to ask the user.
function mcSampleRateHz(bandwidthLabel, oversamplingLabel) {
  const bandwidthMHz = parseFloat(String(bandwidthLabel));
  const osf = parseFloat(String(oversamplingLabel)) || 4;
  if (!Number.isFinite(bandwidthMHz)) return null;
  return bandwidthMHz * 1e6 * osf;
}

/*
 * Single-carrier: the files are RRC-shaped symbols at 4 samples per symbol
 * (Oversampling Factor 4 in every *_properties.csv under Signals/Single
 * Carrier). They carry no rate of their own -- playing the same samples faster
 * just scales the whole spectrum.
 *
 * So the sample rate and the occupied bandwidth are one degree of freedom, not
 * two:
 *
 *     symbol rate = sample rate / osf
 *     occupied BW = symbol rate * (1 + rolloff)
 *
 * Setting one fixes the other. Choosing both independently would mean
 * resampling the waveform, which this converter does not do: it would change
 * the samples, and with them the PAPR the library publishes for the file. The
 * UI therefore lets either box be typed into and keeps the other in step.
 */
function scRates({ sampleRateHz, occupiedBandwidthHz, rolloff, oversampling }) {
  const osf = parseFloat(String(oversampling)) || 4;
  const alpha = parseFloat(String(rolloff));
  const shapingFactor = 1 + (Number.isFinite(alpha) ? alpha : 0);

  if (Number.isFinite(sampleRateHz) && sampleRateHz > 0) {
    const symbolRateHz = sampleRateHz / osf;
    return {
      sampleRateHz,
      symbolRateHz,
      occupiedBandwidthHz: symbolRateHz * shapingFactor,
      osf,
      alpha,
    };
  }

  if (Number.isFinite(occupiedBandwidthHz) && occupiedBandwidthHz > 0) {
    const symbolRateHz = occupiedBandwidthHz / shapingFactor;
    return {
      sampleRateHz: symbolRateHz * osf,
      symbolRateHz,
      occupiedBandwidthHz,
      osf,
      alpha,
    };
  }

  return null;
}

function trimZeros(text) {
  return text.indexOf(".") === -1 ? text : text.replace(/\.?0+$/, "");
}

function formatHz(hz) {
  if (!Number.isFinite(hz)) return "unknown";
  if (hz >= 1e9) return `${trimZeros((hz / 1e9).toFixed(4))} GSa/s`;
  if (hz >= 1e6) return `${trimZeros((hz / 1e6).toFixed(4))} MSa/s`;
  if (hz >= 1e3) return `${trimZeros((hz / 1e3).toFixed(4))} kSa/s`;
  return `${hz} Sa/s`;
}

function formatBandwidthHz(hz) {
  if (!Number.isFinite(hz)) return "unknown";
  if (hz >= 1e9) return `${trimZeros((hz / 1e9).toFixed(4))} GHz`;
  if (hz >= 1e6) return `${trimZeros((hz / 1e6).toFixed(4))} MHz`;
  if (hz >= 1e3) return `${trimZeros((hz / 1e3).toFixed(4))} kHz`;
  return `${hz} Hz`;
}

// Instrument file systems are much less forgiving than a repository is, and
// "wifi7_mcs=5_bw=80" contains a character that several of them treat as a
// separator. The raw .bin keeps its catalogue name; the instrument files get a
// safe one.
function instrumentSafeName(fileName) {
  const cleaned = fileName
    .replace(/\.[^./]+$/, "")
    .replace(/=/g, "")
    .replace(/[^A-Za-z0-9_-]+/g, "_")
    .replace(/_+/g, "_")
    .replace(/^_|_$/g, "")
    .slice(0, 60);
  return cleaned || "waveform";
}

const IqFormats = {
  GENERATORS,
  FORMATS,
  BYTES_PER_FLOAT32_SAMPLE,
  INT16_FULL_SCALE,
  readFloat32Iq,
  fitToLength,
  iqStats,
  toKeysightWfm,
  toRohdeSchwarzWv,
  exportNotes,
  mcSampleRateHz,
  scRates,
  formatHz,
  formatBandwidthHz,
  instrumentSafeName,
};

if (typeof window !== "undefined") {
  window.IqFormats = IqFormats;
}
if (typeof module !== "undefined" && module.exports) {
  module.exports = IqFormats;
}
