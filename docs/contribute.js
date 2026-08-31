// Contribution portal for the PA Standard Signal Library.
//
// The page is served as a static file, so everything here runs in the visitor's
// browser: the waveform is read locally, measured locally, and packaged locally.
// Nothing is transmitted until the contributor chooses to open an issue and
// attach the bundle themselves.
//
// The form is generated from contribution-schema.json rather than written out in
// HTML. scripts/ingest_submission.py reads that same file, so a field added to
// the schema appears on this page and is validated on the receiving side without
// either being edited.

const REPOSITORY = {
  owner: "noyades",
  name: "PA-standard-sig",
  branch: "main",
};

const SCHEMA_URL = "./contribution-schema.json";

// Packet segmentation, mirroring IDLE_RUN_SAMPLES and MIN_PACKET_SAMPLES in
// scripts/signal_analysis.py. A run of this many consecutive zero-power samples
// is inter-packet idle or trailing pad rather than signal; a stretch of signal
// shorter than MIN_PACKET_SAMPLES is a fragment, not a packet. Change either
// here and it has to change there, or the browser stops agreeing with the
// catalog.
const IDLE_RUN_SAMPLES = 32;
const MIN_PACKET_SAMPLES = 256;

// Bytes per complex sample, by declared format.
const SAMPLE_BYTES = {
  "float32-iq": 8,
  "float64-iq": 16,
  "int16-iq": 4,
};

// GitHub refuses attachments above 25 MB, and truncates very long issue URLs.
const ATTACHMENT_LIMIT_BYTES = 25 * 1024 * 1024;
const ISSUE_URL_BUDGET = 6000;
const HASH_LIMIT_BYTES = 256 * 1024 * 1024;

// A literal newline, named so the markdown builders below read as prose.
const NL = `
`;

const state = {
  schema: null,
  values: {},
  file: null,
  analysis: null,
  detection: null,
  analysisError: null,
};

const dom = {
  form: document.getElementById("contributionForm"),
  dropzone: document.getElementById("dropzone"),
  dropzoneTitle: document.getElementById("dropzoneTitle"),
  dropzoneHint: document.getElementById("dropzoneHint"),
  fileInput: document.getElementById("fileInput"),
  analysisPanel: document.getElementById("analysisPanel"),
  validationPanel: document.getElementById("validationPanel"),
  bundleBtn: document.getElementById("bundleBtn"),
  issueBtn: document.getElementById("issueBtn"),
  jsonBtn: document.getElementById("jsonBtn"),
};

initialize();

async function initialize() {
  try {
    const res = await fetch(SCHEMA_URL);
    if (!res.ok) throw new Error(`HTTP ${res.status}`);
    state.schema = await res.json();
  } catch (err) {
    // A file:// page cannot fetch its own sibling, which is the usual cause
    // when this page is opened from disk rather than from a server.
    const localHint = window.location.protocol === "file:"
      ? ` This page was opened directly from disk. Serve the docs folder instead, for
         example with <code>python -m http.server</code> from inside it, then open
         <code>http://localhost:8000/contribute.html</code>.`
      : "";
    dom.form.innerHTML = `<p class="field-error">Could not load the contribution schema
      (${escapeHtml(String(err))}). The form cannot be built without it.${localHint}</p>`;
    return;
  }

  renderForm();
  wireFileInput();
  dom.bundleBtn.addEventListener("click", downloadBundle);
  dom.issueBtn.addEventListener("click", openPrefilledIssue);
  dom.jsonBtn.addEventListener("click", copyMetadataJson);
  refreshDerivedState();
}

// ---------------------------------------------------------------------------
// Schema-driven form
// ---------------------------------------------------------------------------

function renderForm() {
  dom.form.innerHTML = state.schema.sections.map(renderSection).join("");

  dom.form.addEventListener("input", onFieldChange);
  dom.form.addEventListener("change", onFieldChange);

  // Seed state with the defaults the browser applied to the selects, so a
  // contributor who never touches a dropdown still gets its visible value.
  eachField((section, field) => {
    const el = fieldElement(section, field);
    if (!el) return;
    if (field.type === "checkbox") {
      state.values[field.id] = el.checked;
    } else if (el.value !== "") {
      state.values[field.id] = el.value;
    }
  });
}

function renderSection(section) {
  const fields = section.fields.map((field) => renderField(section, field)).join("");
  return `
    <fieldset class="form-section" data-section="${escapeAttribute(section.id)}">
      <legend>${escapeHtml(section.title)}</legend>
      ${section.blurb ? `<p class="section-blurb">${escapeHtml(section.blurb)}</p>` : ""}
      ${fields}
    </fieldset>
  `;
}

function renderField(section, field) {
  const domId = fieldDomId(section, field);
  const help = field.help ? `<span class="field-help">${escapeHtml(field.help)}</span>` : "";
  const unit = field.unit ? `<span class="field-unit">${escapeHtml(field.unit)}</span>` : "";
  const marker = isAlwaysOptional(field) ? "" : `<span class="req" title="Required">*</span>`;

  let control;
  if (field.type === "select") {
    const options = [`<option value="">Choose...</option>`]
      .concat(field.options.map((opt) =>
        `<option value="${escapeAttribute(opt.value)}">${escapeHtml(opt.label)}</option>`))
      .join("");
    control = `<select id="${domId}" name="${escapeAttribute(field.id)}">${options}</select>`;
  } else if (field.type === "textarea") {
    control = `<textarea id="${domId}" name="${escapeAttribute(field.id)}" rows="3"
      placeholder="${escapeAttribute(field.placeholder || "")}"></textarea>`;
  } else if (field.type === "checkbox") {
    control = `<input id="${domId}" name="${escapeAttribute(field.id)}" type="checkbox">`;
  } else {
    const listId = field.suggestions ? `${domId}-list` : "";
    const list = field.suggestions
      ? `<datalist id="${listId}">${field.suggestions
          .map((s) => `<option value="${escapeAttribute(s)}"></option>`).join("")}</datalist>`
      : "";
    const numeric = field.type === "number"
      ? ` step="${escapeAttribute(field.step || "any")}"` +
        (field.min !== undefined ? ` min="${escapeAttribute(field.min)}"` : "") +
        (field.max !== undefined ? ` max="${escapeAttribute(field.max)}"` : "")
      : "";
    control = `<input id="${domId}" name="${escapeAttribute(field.id)}" type="${field.type === "number" ? "number" : "text"}"
      placeholder="${escapeAttribute(field.placeholder || "")}"${numeric}
      ${listId ? `list="${listId}"` : ""}>${list}`;
  }

  const labelClass = field.type === "checkbox" ? "field field-checkbox" : "field";
  return `
    <label class="${labelClass}" data-field-wrap="${escapeAttribute(domId)}">
      <span class="field-label">${escapeHtml(field.label)}${marker}${unit}</span>
      ${control}
      ${help}
      <span class="field-error" data-error-for="${escapeAttribute(domId)}" hidden></span>
    </label>
  `;
}

function onFieldChange(event) {
  const target = event.target;
  if (!target.name) return;

  const field = findField(target.name);
  if (!field) return;

  state.values[field.id] = target.type === "checkbox" ? target.checked : target.value;

  // Two sections can offer the same field (channel bandwidth is asked of both a
  // standards-based and a custom waveform). They share one value, so switching
  // branches does not silently drop what was already typed.
  eachField((section, candidate) => {
    if (candidate.id !== field.id) return;
    const el = fieldElement(section, candidate);
    if (!el || el === target) return;
    if (el.type === "checkbox") el.checked = Boolean(state.values[field.id]);
    else el.value = state.values[field.id] ?? "";
  });

  if (field.id === "sampleFormat" || field.id === "byteOrder") {
    // A corrected format changes every measured number, so re-measure.
    if (state.file) analyzeCurrentFile();
    return;
  }

  refreshDerivedState();
}

function refreshDerivedState() {
  applyVisibility();
  renderValidation();
}

function applyVisibility() {
  eachSection((section) => {
    const el = dom.form.querySelector(`[data-section="${cssEscape(section.id)}"]`);
    if (el) el.hidden = !conditionPasses(section.showWhen);
  });

  eachField((section, field) => {
    const wrap = dom.form.querySelector(`[data-field-wrap="${cssEscape(fieldDomId(section, field))}"]`);
    if (!wrap) return;
    const visible = conditionPasses(section.showWhen) && conditionPasses(field.showWhen);
    wrap.hidden = !visible;
    const marker = wrap.querySelector(".req");
    if (marker) marker.hidden = !isRequired(field);
  });
}

// A condition is {field, in: [...]}. Absent means "always".
function conditionPasses(condition) {
  if (!condition) return true;
  const value = state.values[condition.field];
  return condition.in.includes(value);
}

function isRequired(field) {
  if (field.required === true) return true;
  if (!field.required) return false;
  return conditionPasses(field.required);
}

function isAlwaysOptional(field) {
  return field.required === false || field.required === undefined;
}

// A field only counts if the branch it belongs to is on screen.
function isActive(section, field) {
  return conditionPasses(section.showWhen) && conditionPasses(field.showWhen);
}

function eachSection(fn) {
  state.schema.sections.forEach(fn);
}

function eachField(fn) {
  state.schema.sections.forEach((section) => section.fields.forEach((field) => fn(section, field)));
}

function findField(id) {
  for (const section of state.schema.sections) {
    for (const field of section.fields) {
      if (field.id === id) return field;
    }
  }
  return null;
}

function fieldDomId(section, field) {
  return `f-${section.id}-${field.id}`;
}

function fieldElement(section, field) {
  return document.getElementById(fieldDomId(section, field));
}

// ---------------------------------------------------------------------------
// File intake
// ---------------------------------------------------------------------------

function wireFileInput() {
  dom.dropzone.addEventListener("click", () => dom.fileInput.click());
  dom.dropzone.addEventListener("keydown", (event) => {
    if (event.key === "Enter" || event.key === " ") {
      event.preventDefault();
      dom.fileInput.click();
    }
  });
  dom.fileInput.addEventListener("change", () => {
    if (dom.fileInput.files.length) acceptFile(dom.fileInput.files[0]);
  });

  ["dragenter", "dragover"].forEach((type) => {
    dom.dropzone.addEventListener(type, (event) => {
      event.preventDefault();
      dom.dropzone.classList.add("dropzone-active");
    });
  });
  ["dragleave", "drop"].forEach((type) => {
    dom.dropzone.addEventListener(type, (event) => {
      event.preventDefault();
      dom.dropzone.classList.remove("dropzone-active");
    });
  });
  dom.dropzone.addEventListener("drop", (event) => {
    const file = event.dataTransfer && event.dataTransfer.files[0];
    if (file) acceptFile(file);
  });
}

async function acceptFile(file) {
  state.file = file;
  state.analysis = null;
  state.analysisError = null;

  // Only the labels are rewritten: the file input is a child of the dropzone,
  // and replacing the dropzone's markup would tear it out of the document,
  // leaving "click to choose a different file" unable to do anything.
  dom.dropzoneTitle.textContent = file.name;
  dom.dropzoneHint.textContent = `${formatBytes(file.size)} — click to choose a different file`;

  state.detection = await detectFormat(file);
  if (state.detection.format) {
    state.values.sampleFormat = state.detection.format;
    if (state.detection.format !== "csv-iq" && !state.values.byteOrder) {
      state.values.byteOrder = "little";
    }
    syncControlsFromState();
  }

  await analyzeCurrentFile();
}

function syncControlsFromState() {
  eachField((section, field) => {
    const el = fieldElement(section, field);
    if (!el) return;
    const value = state.values[field.id];
    if (value === undefined) return;
    if (el.type === "checkbox") el.checked = Boolean(value);
    else el.value = value;
  });
}

async function analyzeCurrentFile() {
  if (!state.file) return;
  const format = state.values.sampleFormat || (state.detection && state.detection.format);
  if (!format) {
    state.analysisError = "Choose a sample format before the file can be measured.";
    renderAnalysis();
    refreshDerivedState();
    return;
  }

  renderAnalysisBusy();
  try {
    state.analysis = format === "csv-iq"
      ? await analyzeText(state.file)
      : await analyzeBinary(state.file, format, (state.values.byteOrder || "little") === "little");
    state.analysis.sha256 = await hashFile(state.file);
    state.analysisError = null;
  } catch (err) {
    state.analysis = null;
    state.analysisError = String(err && err.message ? err.message : err);
  }

  renderAnalysis();
  refreshDerivedState();
}

// Reads the head of the file and decides how the samples are stored. The rule
// mirrors scripts/signal_analysis.py: float32 unless it decodes to values that
// cannot be a waveform, then float64.
async function detectFormat(file) {
  if (/[.](csv|txt)$/i.test(file.name)) {
    return { format: "csv-iq", confidence: "high", reason: "Text file extension." };
  }

  const probeBytes = Math.min(file.size, 1024 * 1024);
  const head = await file.slice(0, probeBytes - (probeBytes % 16)).arrayBuffer();
  if (head.byteLength < 16) {
    return { format: null, confidence: "none", reason: "File is too short to identify." };
  }

  const f32 = plausibility(new Float32Array(head));
  const f64 = plausibility(new Float64Array(head));

  if (f32.plausible && file.size % SAMPLE_BYTES["float32-iq"] === 0) {
    return {
      format: "float32-iq",
      confidence: f64.plausible ? "medium" : "high",
      reason: f64.plausible
        ? "Decodes as float32 (the library convention); float64 is also possible, so check the sample count."
        : "Decodes cleanly as interleaved float32, the library convention.",
    };
  }
  if (f64.plausible && file.size % SAMPLE_BYTES["float64-iq"] === 0) {
    return { format: "float64-iq", confidence: "medium", reason: "Does not decode as float32, but does as float64." };
  }
  if (file.size % SAMPLE_BYTES["int16-iq"] === 0) {
    return { format: "int16-iq", confidence: "low", reason: "Not floating point; int16 is the remaining fixed-point guess." };
  }
  return { format: null, confidence: "none", reason: "Could not identify the sample format. Set it by hand." };
}

function plausibility(view) {
  let finite = 0;
  let peak = 0;
  const n = Math.min(view.length, 65536);
  if (n === 0) return { plausible: false, peak: 0 };
  for (let i = 0; i < n; i += 1) {
    const v = view[i];
    if (Number.isFinite(v)) {
      finite += 1;
      const a = Math.abs(v);
      if (a > peak) peak = a;
    }
  }
  // Real waveform samples are all finite and sit in a sane numeric range.
  // Misreading float64 bytes as float32 reliably produces both denormals and
  // enormous magnitudes, which is what this rejects.
  const allFinite = finite === n;
  return { plausible: allFinite && peak > 1e-12 && peak < 1e9, peak };
}

// ---------------------------------------------------------------------------
// Measurement
//
// The PAPR definition here is the library's own, from scripts/signal_analysis.py:
//
//   PAPR              10*log10(peak power / mean power) over the samples that
//                     carry signal
//   mean packet PAPR  the same ratio computed inside each packet and averaged,
//                     for a waveform that has more than one packet
//
// Both exclude inter-packet idle and any trailing pad, found as runs of at
// least IDLE_RUN_SAMPLES consecutive zeros. Averaging those zeros into the mean
// power inflates PAPR by a few tenths of a dB, which is enough to disagree with
// the curves the library publishes -- and matching those curves is the whole
// point of showing a number here. Keep this in step with signal_analysis.py.
// ---------------------------------------------------------------------------

async function analyzeBinary(file, format, littleEndian) {
  const bytesPerSample = SAMPLE_BYTES[format];
  const totalSamples = Math.floor(file.size / bytesPerSample);
  if (totalSamples < 2) throw new Error("Fewer than two complex samples in the file.");

  // Any whole number of samples per read will do: the accumulator carries the
  // current packet across chunk boundaries, so a packet may straddle reads.
  const chunkBytes = Math.max(bytesPerSample,
    Math.floor((8 * 1024 * 1024) / bytesPerSample) * bytesPerSample);
  const usableBytes = totalSamples * bytesPerSample;

  const acc = newAccumulator();
  for (let offset = 0; offset < usableBytes; offset += chunkBytes) {
    const end = Math.min(offset + chunkBytes, usableBytes);
    const buffer = await file.slice(offset, end).arrayBuffer();
    const { iq, count } = decodeChunk(buffer, format, littleEndian);
    accumulate(acc, iq, count);
  }

  return finishAnalysis(acc, {
    totalSamples,
    format,
    trailingBytes: file.size - usableBytes,
  });
}

function decodeChunk(buffer, format, littleEndian) {
  // Typed arrays read in platform order, which is little-endian everywhere this
  // page realistically runs; big-endian input goes the slow way through DataView.
  if (format === "float32-iq") {
    if (littleEndian) return { iq: new Float32Array(buffer), count: buffer.byteLength / 8 };
    return { iq: readBigEndian(buffer, 4, (dv, o) => dv.getFloat32(o, false)), count: buffer.byteLength / 8 };
  }
  if (format === "float64-iq") {
    if (littleEndian) return { iq: new Float64Array(buffer), count: buffer.byteLength / 16 };
    return { iq: readBigEndian(buffer, 8, (dv, o) => dv.getFloat64(o, false)), count: buffer.byteLength / 16 };
  }
  // int16 is scaled to full-scale 1.0 so the reported amplitudes are comparable
  // with the float formats. PAPR itself is a ratio and is unaffected.
  const raw = littleEndian
    ? new Int16Array(buffer)
    : readBigEndian(buffer, 2, (dv, o) => dv.getInt16(o, false));
  const scaled = new Float32Array(raw.length);
  for (let i = 0; i < raw.length; i += 1) scaled[i] = raw[i] / 32768;
  return { iq: scaled, count: buffer.byteLength / 4 };
}

function readBigEndian(buffer, width, read) {
  const dv = new DataView(buffer);
  const out = new Float64Array(Math.floor(buffer.byteLength / width));
  for (let i = 0; i < out.length; i += 1) out[i] = read(dv, i * width);
  return out;
}

async function analyzeText(file) {
  const text = await file.text();
  const lines = text.split(/\r?\n/);
  const iq = [];
  let malformed = 0;
  for (const line of lines) {
    const trimmed = line.trim();
    if (!trimmed || trimmed.startsWith("#") || trimmed.startsWith("%")) continue;
    const parts = trimmed.split(/[,;\t ]+/);
    const i = Number(parts[0]);
    const q = Number(parts[1]);
    if (!Number.isFinite(i) || !Number.isFinite(q)) {
      malformed += 1;
      continue;
    }
    iq.push(i, q);
  }
  const count = iq.length / 2;
  if (count < 2) throw new Error("Fewer than two I,Q pairs could be parsed from the text.");

  const acc = newAccumulator();
  accumulate(acc, Float64Array.from(iq), count);
  return finishAnalysis(acc, { totalSamples: count, format: "csv-iq", malformedLines: malformed });
}

function newAccumulator() {
  return {
    // Accepted packets, and the running totals across them.
    peak: 0,
    sum: 0,
    count: 0,
    sumI: 0,
    sumQ: 0,
    packetPaprSum: 0,
    packets: 0,

    // The packet currently being walked.
    curPeak: 0,
    curSum: 0,
    curCount: 0,
    curSumI: 0,
    curSumQ: 0,

    // Zeros seen since the last signal sample. They are only idle once the run
    // reaches IDLE_RUN_SAMPLES; a shorter run belongs to the packet around it.
    pendingZeros: 0,

    // Fallback totals, used when the waveform turns out to have no packet
    // structure at all -- a continuous single-carrier stream, for instance.
    nzPeak: 0,
    nzSum: 0,
    nzCount: 0,
    nzSumI: 0,
    nzSumQ: 0,

    nonFinite: 0,
    samplesSeen: 0,
  };
}

function closePacket(acc) {
  if (acc.curCount >= MIN_PACKET_SAMPLES && acc.curSum > 0) {
    if (acc.curPeak > acc.peak) acc.peak = acc.curPeak;
    acc.sum += acc.curSum;
    acc.count += acc.curCount;
    acc.sumI += acc.curSumI;
    acc.sumQ += acc.curSumQ;
    acc.packetPaprSum += 10 * Math.log10(acc.curPeak / (acc.curSum / acc.curCount));
    acc.packets += 1;
  }
  acc.curPeak = 0;
  acc.curSum = 0;
  acc.curCount = 0;
  acc.curSumI = 0;
  acc.curSumQ = 0;
}

function accumulate(acc, iq, count) {
  for (let s = 0; s < count; s += 1) {
    const i = iq[2 * s];
    const q = iq[2 * s + 1];
    acc.samplesSeen += 1;

    // A sample that is not a number cannot contribute to a peak or a mean.
    // Treating it as zero lets it fall into the idle mask instead.
    const finite = Number.isFinite(i) && Number.isFinite(q);
    if (!finite) acc.nonFinite += 1;
    const power = finite ? i * i + q * q : 0;

    if (power === 0) {
      acc.pendingZeros += 1;
      continue;
    }

    if (acc.pendingZeros >= IDLE_RUN_SAMPLES) {
      closePacket(acc);           // that run of zeros was idle: packet boundary
    } else {
      acc.curCount += acc.pendingZeros;   // interior zeros stay inside the packet
    }
    acc.pendingZeros = 0;

    acc.curCount += 1;
    acc.curSum += power;
    acc.curSumI += i;
    acc.curSumQ += q;
    if (power > acc.curPeak) acc.curPeak = power;

    if (power > acc.nzPeak) acc.nzPeak = power;
    acc.nzSum += power;
    acc.nzCount += 1;
    acc.nzSumI += i;
    acc.nzSumQ += q;
  }
}

function finishAnalysis(acc, meta) {
  closePacket(acc);   // the trailing zero pad is discarded with it

  // With no packet long enough to keep, fall back to every non-zero sample.
  const usingPackets = acc.packets > 0;
  const peak = usingPackets ? acc.peak : acc.nzPeak;
  const sum = usingPackets ? acc.sum : acc.nzSum;
  const n = usingPackets ? acc.count : acc.nzCount;
  const sumI = usingPackets ? acc.sumI : acc.nzSumI;
  const sumQ = usingPackets ? acc.sumQ : acc.nzSumQ;

  if (n < 2) throw new Error("No signal samples: the file appears to be all zeros.");
  const meanPower = sum / n;
  if (!(meanPower > 0)) throw new Error("Mean power is zero: the file appears to be all zeros.");

  return Object.assign({
    sampleCount: acc.samplesSeen,
    activeSamples: n,
    idleSamples: acc.samplesSeen - n,
    packets: acc.packets,
    nonFiniteSamples: acc.nonFinite,
    paprDb: round2(10 * Math.log10(peak / meanPower)),
    // One packet is one measurement, not a distribution; averaging it with
    // itself would dress a single number up as a mean.
    meanPacketPaprDb: acc.packets >= 2 ? round2(acc.packetPaprSum / acc.packets) : null,
    rms: round4(Math.sqrt(meanPower)),
    peakAmplitude: round4(Math.sqrt(peak)),
    dcOffsetI: round4(sumI / n),
    dcOffsetQ: round4(sumQ / n),
    estimator: "peak/mean over signal samples; idle and pad excluded",
  }, meta);
}

async function hashFile(file) {
  // SubtleCrypto has no streaming digest, so this needs the whole file in memory.
  // Past a few hundred megabytes that is not worth doing in a browser tab.
  if (file.size > HASH_LIMIT_BYTES || !window.isSecureContext || !window.crypto || !crypto.subtle) {
    return null;
  }
  try {
    const digest = await crypto.subtle.digest("SHA-256", await file.arrayBuffer());
    return Array.from(new Uint8Array(digest)).map((b) => b.toString(16).padStart(2, "0")).join("");
  } catch (err) {
    console.warn("Could not hash the file:", err);
    return null;
  }
}

// ---------------------------------------------------------------------------
// Rendering: measurement panel and validation
// ---------------------------------------------------------------------------

function renderAnalysisBusy() {
  dom.analysisPanel.hidden = false;
  dom.analysisPanel.innerHTML = `<p class="analysis-busy">Measuring ${escapeHtml(state.file.name)}...</p>`;
}

function renderAnalysis() {
  dom.analysisPanel.hidden = false;

  if (state.analysisError) {
    dom.analysisPanel.innerHTML = `
      <h3>Measurement failed</h3>
      <p class="field-error">${escapeHtml(state.analysisError)}</p>`;
    return;
  }
  if (!state.analysis) {
    dom.analysisPanel.innerHTML = "";
    dom.analysisPanel.hidden = true;
    return;
  }

  const a = state.analysis;
  const detection = state.detection && state.detection.reason
    ? `<p class="detection-note">Format: <strong>${escapeHtml(a.format)}</strong>
       (${escapeHtml(state.detection.confidence)} confidence). ${escapeHtml(state.detection.reason)}</p>`
    : "";

  const rows = [
    ["Complex samples", a.sampleCount.toLocaleString()],
    ["PAPR", `${a.paprDb.toFixed(2)} dB`],
    ["RMS amplitude", a.rms.toFixed(4)],
    ["Peak amplitude", a.peakAmplitude.toFixed(4)],
    ["DC offset (I, Q)", `${a.dcOffsetI.toFixed(4)}, ${a.dcOffsetQ.toFixed(4)}`],
  ];
  if (a.meanPacketPaprDb !== null && a.meanPacketPaprDb !== undefined) {
    rows.push(["Mean packet PAPR", `${a.meanPacketPaprDb.toFixed(2)} dB`]);
  }
  if (a.packets) rows.push(["Packets", String(a.packets)]);
  if (a.idleSamples) rows.push(["Idle / pad", `${a.idleSamples.toLocaleString()} samples`]);
  const rate = numberValue("sampleRateMHz");
  // Duration counts the whole file, idle included: that is how long it plays.
  if (rate) rows.push(["Duration", formatDuration(a.sampleCount / (rate * 1e6))]);

  dom.analysisPanel.innerHTML = `
    <h3>Measured locally</h3>
    ${detection}
    <dl class="analysis-grid">
      ${rows.map(([k, v]) => `<div><dt>${escapeHtml(k)}</dt><dd>${escapeHtml(v)}</dd></div>`).join("")}
    </dl>
    <p class="analysis-note">
      Computed with the library's own estimator, so these are directly comparable with
      the published catalog numbers. They are recomputed on submission rather than taken on trust.
    </p>
  `;
}

function renderValidation() {
  const { errors, warnings } = validate();

  eachField((section, field) => {
    const slot = dom.form.querySelector(`[data-error-for="${cssEscape(fieldDomId(section, field))}"]`);
    if (!slot) return;
    const problem = errors.find((e) => e.field === field.id);
    slot.hidden = !problem;
    slot.textContent = problem ? problem.message : "";
  });

  const blocks = [];
  if (errors.length) {
    blocks.push(`
      <div class="validation-block validation-error">
        <h3>${errors.length} item${errors.length === 1 ? "" : "s"} still needed</h3>
        <ul>${errors.map((e) => `<li>${escapeHtml(e.message)}</li>`).join("")}</ul>
      </div>`);
  }
  if (warnings.length) {
    blocks.push(`
      <div class="validation-block validation-warning">
        <h3>Worth a second look</h3>
        <ul>${warnings.map((w) => `<li>${escapeHtml(w)}</li>`).join("")}</ul>
      </div>`);
  }
  if (!errors.length) {
    blocks.unshift(`
      <div class="validation-block validation-ok">
        <h3>Ready to submit</h3>
        <p>Download the bundle, then open the issue and attach it.</p>
      </div>`);
  }

  dom.validationPanel.innerHTML = blocks.join("");

  const ready = errors.length === 0;
  dom.bundleBtn.disabled = !ready;
  dom.issueBtn.disabled = !ready;
  dom.jsonBtn.disabled = !ready;
}

function validate() {
  const errors = [];
  const warnings = [];

  if (!state.file) {
    errors.push({ field: null, message: "Choose a waveform file." });
  } else if (state.analysisError) {
    errors.push({ field: null, message: `The file could not be measured: ${state.analysisError}` });
  } else if (!state.analysis) {
    errors.push({ field: null, message: "Waiting for the file to be measured." });
  }

  eachField((section, field) => {
    if (!isActive(section, field)) return;
    const value = state.values[field.id];
    const empty = field.type === "checkbox" ? !value : value === undefined || String(value).trim() === "";
    if (empty) {
      // An optional field that was left blank is fine; a required one is not.
      // Anything filled in is checked either way, which is what
      // scripts/ingest_submission.py does on the receiving side.
      if (isRequired(field)) {
        errors.push({
          field: field.id,
          message: field.type === "checkbox" ? field.label : `${field.label} is required.`,
        });
      }
      return;
    }
    if (field.pattern && !new RegExp(field.pattern).test(String(value).trim())) {
      errors.push({ field: field.id, message: field.patternHelp || `${field.label} is not in the expected format.` });
    }
    if (field.type === "number") {
      const num = Number(value);
      if (!Number.isFinite(num)) {
        errors.push({ field: field.id, message: `${field.label} must be a number.` });
      } else if (field.min !== undefined && num < field.min) {
        errors.push({ field: field.id, message: `${field.label} must be at least ${field.min}.` });
      } else if (field.max !== undefined && num > field.max) {
        errors.push({ field: field.id, message: `${field.label} must be at most ${field.max}.` });
      }
    }
  });

  collectCrossChecks(errors, warnings);
  return { errors, warnings };
}

// Checks that compare what the contributor declared against what the file
// actually contains. These are where a mislabeled file gets caught.
function collectCrossChecks(errors, warnings) {
  const a = state.analysis;
  if (!a || !state.file) return;

  const format = state.values.sampleFormat;
  const bytesPerSample = SAMPLE_BYTES[format];
  if (bytesPerSample && state.file.size % bytesPerSample !== 0) {
    errors.push({
      field: "sampleFormat",
      message: `The file is ${state.file.size} bytes, which is not a whole number of ` +
        `${bytesPerSample}-byte samples. The declared format is probably wrong.`,
    });
  }
  if (a.trailingBytes) {
    warnings.push(`${a.trailingBytes} trailing byte(s) were ignored; the file does not end on a sample boundary.`);
  }
  if (a.nonFiniteSamples) {
    warnings.push(`${a.nonFiniteSamples} sample(s) were not finite and were skipped.`);
  }
  if (a.malformedLines) {
    warnings.push(`${a.malformedLines} text line(s) could not be parsed as an I,Q pair and were skipped.`);
  }
  if (a.packets === 0) {
    warnings.push(
      "No packet structure was found, so PAPR covers every non-zero sample. That is " +
      "expected for a continuous single-carrier waveform.");
  }

  const sampleRate = numberValue("sampleRateMHz");
  const bandwidth = numberValue("bandwidthMHz");
  if (sampleRate && bandwidth && bandwidth > sampleRate) {
    errors.push({
      field: "bandwidthMHz",
      message: `An occupied bandwidth of ${bandwidth} MHz cannot be carried at ${sampleRate} MSa/s.`,
    });
  }

  const osr = numberValue("oversampling");
  if (osr && sampleRate && bandwidth) {
    const implied = sampleRate / bandwidth;
    if (implied < osr / 2 || implied > osr * 2) {
      warnings.push(
        `Sample rate over bandwidth is ${implied.toFixed(2)}, which sits far from the declared ` +
        `oversampling ratio of ${osr}. One of the three is likely mistyped.`);
    }
  }

  const symbolRate = numberValue("symbolRateMHz");
  if (symbolRate && sampleRate) {
    const implied = sampleRate / symbolRate;
    if (Math.abs(implied - Math.round(implied)) > 0.01) {
      warnings.push(`Sample rate divided by symbol rate is ${implied.toFixed(3)}, not an integer oversampling ratio.`);
    }
  }

  const symbols = numberValue("symbolCount");
  if (symbols && osr) {
    const expected = symbols * osr;
    const ratio = a.sampleCount / expected;
    if (ratio < 0.95 || ratio > 1.05) {
      warnings.push(
        `${symbols} symbols at ${osr}x oversampling implies about ${expected.toLocaleString()} samples, ` +
        `but the file holds ${a.sampleCount.toLocaleString()}.`);
    }
  }

  const normalization = state.values.normalization;
  if (normalization === "peak" && Math.abs(a.peakAmplitude - 1) > 0.02) {
    warnings.push(`Declared peak-normalized, but the peak amplitude measures ${a.peakAmplitude.toFixed(4)}.`);
  }
  if (normalization === "rms" && Math.abs(a.rms - 1) > 0.02) {
    warnings.push(`Declared RMS-normalized, but the RMS measures ${a.rms.toFixed(4)}.`);
  }

  const dc = Math.hypot(a.dcOffsetI, a.dcOffsetQ);
  if (dc > 0.01 * a.rms && dc > 1e-6) {
    warnings.push(`The waveform carries a DC offset of ${dc.toFixed(4)}, ${(100 * dc / a.rms).toFixed(1)}% of RMS.`);
  }

  if (a.paprDb > 20) {
    warnings.push(`A PAPR of ${a.paprDb.toFixed(2)} dB is unusually high; check for an impulse or a stray sample.`);
  }

  if (state.file.size > ATTACHMENT_LIMIT_BYTES) {
    warnings.push(
      `The waveform is ${formatBytes(state.file.size)}, above GitHub's 25 MB attachment limit. ` +
      `Attach the metadata alone and link the waveform from a file host in the issue.`);
  }
}

// ---------------------------------------------------------------------------
// Submission
// ---------------------------------------------------------------------------

// Everything that leaves this page goes through one of these. Adding a hosted
// endpoint later means adding an adapter here and a button in contribute.html;
// nothing above this line has to change.
function buildSubmission() {
  const metadata = {};
  eachField((section, field) => {
    if (!isActive(section, field)) return;
    const value = state.values[field.id];
    if (value === undefined || value === "" || value === false) return;
    metadata[field.id] = field.type === "number" ? Number(value) : value;
  });

  return {
    schemaVersion: state.schema.version,
    submittedAt: new Date().toISOString(),
    metadata,
    file: state.file
      ? {
          name: state.file.name,
          sizeBytes: state.file.size,
          sha256: state.analysis ? state.analysis.sha256 : null,
        }
      : null,
    analysis: state.analysis,
    generatedBy: "docs/contribute.html",
  };
}

function submissionJson() {
  return JSON.stringify(buildSubmission(), null, 2);
}

async function downloadBundle() {
  if (typeof JSZip === "undefined") {
    alert("JSZip did not load, so the bundle cannot be built. Use 'Copy metadata JSON' instead.");
    return;
  }

  dom.bundleBtn.disabled = true;
  dom.bundleBtn.textContent = "Packing...";
  try {
    const zip = new JSZip();
    zip.file("submission.json", submissionJson());
    zip.file("README.txt", bundleReadme());
    if (state.file && state.file.size <= ATTACHMENT_LIMIT_BYTES) {
      // Stored, not deflated: I/Q noise does not compress, and deflating tens of
      // megabytes of it in a browser tab costs seconds for nothing.
      zip.file(state.file.name, state.file, { compression: "STORE" });
    }
    const blob = await zip.generateAsync({ type: "blob" });
    triggerDownload(blob, `${submissionSlug()}.zip`);
  } catch (err) {
    console.error(err);
    alert(`Could not build the bundle: ${err}`);
  } finally {
    dom.bundleBtn.textContent = "Download submission bundle (.zip)";
    dom.bundleBtn.disabled = false;
  }
}

function bundleReadme() {
  const included = state.file && state.file.size <= ATTACHMENT_LIMIT_BYTES;
  return [
    "PA Standard Signal Library - contribution bundle",
    "",
    `Created: ${new Date().toISOString()}`,
    "",
    "Contents:",
    "  submission.json  Declared metadata plus the statistics measured in the browser.",
    included
      ? `  ${state.file.name}  The waveform itself.`
      : "  (the waveform was too large to include; link it in the issue instead)",
    "",
    "To submit: attach this archive to a Signal Contribution issue at",
    `  https://github.com/${REPOSITORY.owner}/${REPOSITORY.name}/issues`,
    "",
    "A maintainer validates it with:",
    "  python scripts/ingest_submission.py submission.json --signal <waveform file>",
  ].join(NL);
}

function openPrefilledIssue() {
  const submission = buildSubmission();
  const body = issueBody(submission);
  const title = `Signal contribution: ${submissionTitle(submission)}`;
  const url = new URL(`https://github.com/${REPOSITORY.owner}/${REPOSITORY.name}/issues/new`);
  url.searchParams.set("title", title);
  url.searchParams.set("labels", "signal-contribution");
  url.searchParams.set("body", body);
  window.open(url.toString(), "_blank", "noopener");
}

function issueBody(submission) {
  const m = submission.metadata;
  const a = submission.analysis || {};
  const rows = [];

  eachField((section, field) => {
    if (!isActive(section, field)) return;
    const value = m[field.id];
    if (value === undefined) return;
    rows.push(`| ${field.label}${field.unit ? ` (${field.unit})` : ""} | ${String(value).replace(/[|]/g, "/")} |`);
  });

  const json = JSON.stringify(submission, null, 2);
  const head = [
    "Submitted from the contribution page. The waveform is attached as a zip bundle.",
    "",
    "### Declared",
    "",
    "| Field | Value |",
    "| --- | --- |",
    ...rows,
    "",
    "### Measured in the browser",
    "",
    "| Statistic | Value |",
    "| --- | --- |",
    `| Complex samples | ${a.sampleCount ?? "n/a"} |`,
    `| PAPR | ${a.paprDb ?? "n/a"} dB |`,
    `| Mean packet PAPR | ${a.meanPacketPaprDb ?? "n/a"} dB |`,
    `| Packets | ${a.packets ?? "n/a"} |`,
    `| RMS amplitude | ${a.rms ?? "n/a"} |`,
    `| SHA-256 | ${(submission.file && submission.file.sha256) || "not computed"} |`,
    "",
    "These are recomputed on ingest; they are here so a mismatch is visible immediately.",
    "",
  ].join(NL);

  // GitHub silently truncates very long URLs, and a truncated JSON block is
  // worse than none: the bundle carries the authoritative copy either way.
  const withJson = `${head}<details><summary>submission.json</summary>${NL}${NL}\`\`\`json${NL}${json}${NL}\`\`\`${NL}</details>${NL}`;
  return withJson.length <= ISSUE_URL_BUDGET
    ? withJson
    : `${head}_The metadata JSON was too long to prefill here; it is in submission.json inside the attached bundle._${NL}`;
}

async function copyMetadataJson() {
  const text = submissionJson();
  try {
    await navigator.clipboard.writeText(text);
    flashButton(dom.jsonBtn, "Copied");
  } catch (err) {
    console.warn("Clipboard unavailable, falling back to a download:", err);
    triggerDownload(new Blob([text], { type: "application/json" }), "submission.json");
  }
}

function submissionTitle(submission) {
  const m = submission.metadata;
  const parts = [m.signalClass, m.signalFamily];
  if (m.isStandard === "yes") {
    parts.push(m.standard, m.mcs !== undefined ? `MCS ${m.mcs}` : null, m.bandwidthMHz ? `${m.bandwidthMHz} MHz` : null);
  } else {
    parts.push(m.modulation, m.bandwidthMHz ? `${m.bandwidthMHz} MHz` : null);
  }
  return parts.filter(Boolean).join(" ");
}

function submissionSlug() {
  const raw = submissionTitle(buildSubmission()) || "signal-contribution";
  return raw.toLowerCase().replace(/[^a-z0-9]+/g, "-").replace(/^-|-$/g, "").slice(0, 60) || "signal-contribution";
}

// ---------------------------------------------------------------------------
// Small helpers
// ---------------------------------------------------------------------------

function numberValue(id) {
  const raw = state.values[id];
  if (raw === undefined || raw === "") return null;
  const num = Number(raw);
  return Number.isFinite(num) ? num : null;
}

function triggerDownload(blob, filename) {
  const url = URL.createObjectURL(blob);
  const a = document.createElement("a");
  a.href = url;
  a.download = filename;
  a.click();
  setTimeout(() => URL.revokeObjectURL(url), 10000);
}

function flashButton(button, message) {
  const original = button.textContent;
  button.textContent = message;
  setTimeout(() => { button.textContent = original; }, 1600);
}

function round2(value) {
  return Math.round(value * 100) / 100;
}

function round4(value) {
  return Math.round(value * 10000) / 10000;
}

function formatBytes(bytes) {
  if (bytes < 1024) return `${bytes} B`;
  if (bytes < 1024 * 1024) return `${(bytes / 1024).toFixed(1)} KB`;
  return `${(bytes / (1024 * 1024)).toFixed(2)} MB`;
}

function formatDuration(seconds) {
  if (seconds >= 1) return `${seconds.toFixed(3)} s`;
  if (seconds >= 1e-3) return `${(seconds * 1e3).toFixed(3)} ms`;
  return `${(seconds * 1e6).toFixed(2)} us`;
}

function cssEscape(value) {
  return window.CSS && CSS.escape ? CSS.escape(value) : value;
}

function escapeHtml(value) {
  return String(value)
    .replaceAll("&", "&amp;")
    .replaceAll("<", "&lt;")
    .replaceAll(">", "&gt;")
    .replaceAll('"', "&quot;")
    .replaceAll("'", "&#39;");
}

function escapeAttribute(value) {
  return escapeHtml(value);
}
