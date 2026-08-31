const REPOSITORY = {
  owner: "noyades",
  name: "PA-standard-sig",
  branch: "main",
};

// Fallback hardcoded catalog if manifest.json is unreachable during local testing
const HARDCODED_MC_PATHS = [
  "Signals/Multi Carrier/WiFi/802.11N (WiFi4)/wifi4_mcs=0_bw=20_GI=Long_osf=4_4MB.bin",
  "Signals/Multi Carrier/WiFi/802.11N (WiFi4)/wifi4_mcs=0_bw=20_GI=Long_osf=4_8MB.bin",
  "Signals/Multi Carrier/WiFi/802.11N (WiFi4)/wifi4_mcs=0_bw=40_GI=Long_osf=4_4MB.bin",
  "Signals/Multi Carrier/WiFi/802.11N (WiFi4)/wifi4_mcs=0_bw=40_GI=Long_osf=4_8MB.bin",
  "Signals/Multi Carrier/WiFi/802.11N (WiFi4)/wifi4_mcs=1_bw=20_GI=Long_osf=4_4MB.bin",
  "Signals/Multi Carrier/WiFi/802.11N (WiFi4)/wifi4_mcs=1_bw=20_GI=Long_osf=4_8MB.bin",
  "Signals/Multi Carrier/WiFi/802.11N (WiFi4)/wifi4_mcs=1_bw=40_GI=Long_osf=4_4MB.bin",
  "Signals/Multi Carrier/WiFi/802.11N (WiFi4)/wifi4_mcs=1_bw=40_GI=Long_osf=4_8MB.bin",
  "Signals/Multi Carrier/WiFi/802.11N (WiFi4)/wifi4_mcs=2_bw=20_GI=Long_osf=4_4MB.bin",
  "Signals/Multi Carrier/WiFi/802.11N (WiFi4)/wifi4_mcs=2_bw=20_GI=Long_osf=4_8MB.bin",
  "Signals/Multi Carrier/WiFi/802.11N (WiFi4)/wifi4_mcs=2_bw=40_GI=Long_osf=4_4MB.bin",
  "Signals/Multi Carrier/WiFi/802.11N (WiFi4)/wifi4_mcs=2_bw=40_GI=Long_osf=4_8MB.bin",
  "Signals/Multi Carrier/WiFi/802.11N (WiFi4)/wifi4_mcs=3_bw=20_GI=Long_osf=4_4MB.bin",
  "Signals/Multi Carrier/WiFi/802.11N (WiFi4)/wifi4_mcs=3_bw=20_GI=Long_osf=4_8MB.bin",
  "Signals/Multi Carrier/WiFi/802.11N (WiFi4)/wifi4_mcs=3_bw=40_GI=Long_osf=4_4MB.bin",
  "Signals/Multi Carrier/WiFi/802.11N (WiFi4)/wifi4_mcs=3_bw=40_GI=Long_osf=4_8MB.bin",
  "Signals/Multi Carrier/WiFi/802.11N (WiFi4)/wifi4_mcs=4_bw=20_GI=Long_osf=4_4MB.bin",
  "Signals/Multi Carrier/WiFi/802.11N (WiFi4)/wifi4_mcs=4_bw=20_GI=Long_osf=4_8MB.bin",
  "Signals/Multi Carrier/WiFi/802.11N (WiFi4)/wifi4_mcs=4_bw=40_GI=Long_osf=4_4MB.bin",
  "Signals/Multi Carrier/WiFi/802.11N (WiFi4)/wifi4_mcs=4_bw=40_GI=Long_osf=4_8MB.bin",
  "Signals/Multi Carrier/WiFi/802.11N (WiFi4)/wifi4_mcs=5_bw=20_GI=Long_osf=4_4MB.bin",
  "Signals/Multi Carrier/WiFi/802.11N (WiFi4)/wifi4_mcs=5_bw=20_GI=Long_osf=4_8MB.bin",
  "Signals/Multi Carrier/WiFi/802.11N (WiFi4)/wifi4_mcs=5_bw=40_GI=Long_osf=4_4MB.bin",
  "Signals/Multi Carrier/WiFi/802.11N (WiFi4)/wifi4_mcs=5_bw=40_GI=Long_osf=4_8MB.bin",
  "Signals/Multi Carrier/WiFi/802.11N (WiFi4)/wifi4_mcs=6_bw=20_GI=Long_osf=4_4MB.bin",
  "Signals/Multi Carrier/WiFi/802.11N (WiFi4)/wifi4_mcs=6_bw=20_GI=Long_osf=4_8MB.bin",
  "Signals/Multi Carrier/WiFi/802.11N (WiFi4)/wifi4_mcs=6_bw=40_GI=Long_osf=4_4MB.bin",
  "Signals/Multi Carrier/WiFi/802.11N (WiFi4)/wifi4_mcs=6_bw=40_GI=Long_osf=4_8MB.bin",
  "Signals/Multi Carrier/WiFi/802.11N (WiFi4)/wifi4_mcs=7_bw=20_GI=Long_osf=4_4MB.bin",
  "Signals/Multi Carrier/WiFi/802.11N (WiFi4)/wifi4_mcs=7_bw=20_GI=Long_osf=4_8MB.bin",
  "Signals/Multi Carrier/WiFi/802.11N (WiFi4)/wifi4_mcs=7_bw=40_GI=Long_osf=4_4MB.bin",
  "Signals/Multi Carrier/WiFi/802.11N (WiFi4)/wifi4_mcs=7_bw=40_GI=Long_osf=4_8MB.bin",
];

const HARDCODED_SC_CONFIGS = [
  { rolloff: "0.25", modulation: "64-QAM", figureDir: "Figures/rolloff_0p25/QAM_SC/64QAM" },
  { rolloff: "0.25", modulation: "256-QAM", figureDir: "Figures/rolloff_0p25/QAM_SC/256QAM" },
  { rolloff: "0.25", modulation: "1024-QAM", figureDir: "Figures/rolloff_0p25/QAM_SC/1024QAM" },
  { rolloff: "0.25", modulation: "4096-QAM", figureDir: "Figures/rolloff_0p25/QAM_SC/4096QAM" },
  { rolloff: "0.35", modulation: "64-QAM", figureDir: "Figures/rolloff_0p35/QAM_SC/64-QAM" },
  { rolloff: "0.35", modulation: "256-QAM", figureDir: "Figures/rolloff_0p35/QAM_SC/256-QAM" },
  { rolloff: "0.35", modulation: "1024-QAM", figureDir: "Figures/rolloff_0p35/QAM_SC/1024-QAM" },
  { rolloff: "0.35", modulation: "4096-QAM", figureDir: "Figures/rolloff_0p35/QAM_SC/4096-QAM" },
];

const SC_PLOT_SUFFIXES = [
  { key: "constellation", label: "Constellation Heatmap", suffix: "constellation_heatmap.png" },
  { key: "envelope", label: "Envelope Histogram", suffix: "envelop_histogram.png" },
  { key: "phase", label: "Phase Histogram", suffix: "phase_histogram.png" },
  { key: "derivativeEnvelope", label: "Derivative Envelope Histogram", suffix: "Derivative_envelop_histogram.png" },
  { key: "derivativePhase", label: "Derivative Phase Histogram", suffix: "Derivative_phase_histogram.png" },
];

const fieldVisibility = {
  MC: ["standard", "mcs", "bandwidth", "memoryLength"],
  SC: ["modulation", "rolloff", "filterType"],
};

const formElements = {
  signalClass: document.getElementById("signalClass"),
  signalFamily: document.getElementById("signalFamily"),
  standard: document.getElementById("standard"),
  mcs: document.getElementById("mcs"),
  bandwidth: document.getElementById("bandwidth"),
  memoryLength: document.getElementById("memoryLength"),
  modulation: document.getElementById("modulation"),
  rolloff: document.getElementById("rolloff"),
  targetLength: document.getElementById("targetLength"),
};

const exportElements = {
  targetGenerator: document.getElementById("targetGenerator"),
  formatOptions: document.getElementById("formatOptions"),
  mcSampleRate: document.getElementById("mcSampleRate"),
  scSampleRate: document.getElementById("scSampleRate"),
  scBandwidth: document.getElementById("scBandwidth"),
  rateNote: document.getElementById("rateNote"),
};

// A single-carrier file has one degree of freedom shared between its sample
// rate and its occupied bandwidth (see scRates in iq-formats.js). Remembering
// which box the user typed into last means the other one is the derived value,
// so switching to a waveform with a different roll-off recomputes the right
// one instead of quietly changing what the user asked for.
let scRateDriver = "sampleRate";
const DEFAULT_SC_SAMPLE_RATE_MHZ = 100;

const summaryCard = document.getElementById("summaryCard");
const signalCards = document.getElementById("signalCards");
const plotGallery = document.getElementById("plotGallery");
const resultCount = document.getElementById("resultCount");
const resultTitle = document.getElementById("resultTitle");
const emptyState = document.getElementById("emptyState");
const downloadZipBtn = document.getElementById("downloadZipBtn");

let catalog = [];
let activeMatch = null;

initialize();

async function initialize() {
  try {
    const res = await fetch('./manifest.json');
    if (!res.ok) throw new Error(`HTTP error ${res.status}`);
    const rawManifest = await res.json();
    catalog = processManifest(rawManifest);
  } catch (err) {
    console.warn("Could not load manifest.json, building fallback catalog from static lists:", err);
    catalog = buildFallbackCatalog();
  }

  populateSelect(formElements.signalClass, unique(catalog.map((entry) => entry.signalClass)));
  formElements.signalClass.addEventListener("change", onSignalClassChange);
  formElements.signalFamily.addEventListener("change", refreshResults);
  formElements.standard.addEventListener("change", refreshResults);
  formElements.mcs.addEventListener("change", refreshResults);
  formElements.bandwidth.addEventListener("change", refreshResults);
  formElements.memoryLength.addEventListener("change", refreshResults);
  formElements.modulation.addEventListener("change", refreshResults);
  formElements.rolloff.addEventListener("change", refreshResults);

  if (downloadZipBtn) {
    downloadZipBtn.addEventListener("click", downloadBundle);
  }

  initializeExportControls();
  onSignalClassChange();
}

/* ------------------------------------------------------------------ *
 * Export controls
 * ------------------------------------------------------------------ */

function initializeExportControls() {
  if (!exportElements.targetGenerator || typeof IqFormats === "undefined") return;

  exportElements.targetGenerator.innerHTML = IqFormats.GENERATORS
    .map((gen) => `<option value="${escapeAttribute(gen.id)}">${escapeHtml(gen.label)}</option>`)
    .join("");

  exportElements.formatOptions.innerHTML = Object.values(IqFormats.FORMATS)
    .map((format) => `
      <label>
        <input type="checkbox" name="exportFormat" value="${escapeAttribute(format.id)}">
        <span>${escapeHtml(format.label)}</span>
      </label>
    `).join("");

  exportElements.targetGenerator.addEventListener("change", () => {
    applyGeneratorDefaults();
    refreshRateUi();
  });
  exportElements.formatOptions.addEventListener("change", refreshRateUi);

  // Each box writes the other. Assigning to .value does not fire an input
  // event, so this settles in one pass rather than ping-ponging.
  exportElements.scSampleRate.addEventListener("input", () => {
    scRateDriver = "sampleRate";
    refreshRateUi();
  });
  exportElements.scBandwidth.addEventListener("input", () => {
    scRateDriver = "bandwidth";
    refreshRateUi();
  });

  exportElements.scSampleRate.value = String(DEFAULT_SC_SAMPLE_RATE_MHZ);
  applyGeneratorDefaults();
}

function applyGeneratorDefaults() {
  const generator = selectedGenerator();
  if (!generator) return;
  const defaults = new Set(generator.defaultFormats);
  formatCheckboxes().forEach((box) => {
    box.checked = defaults.has(box.value);
  });
}

function formatCheckboxes() {
  return Array.from(exportElements.formatOptions.querySelectorAll('input[name="exportFormat"]'));
}

function selectedFormats() {
  return formatCheckboxes().filter((box) => box.checked).map((box) => box.value);
}

function selectedGenerator() {
  return IqFormats.GENERATORS.find((gen) => gen.id === exportElements.targetGenerator.value)
    || IqFormats.GENERATORS[0];
}

/*
 * Works out the sample rate the export should be prepared at, and whether it
 * is worth warning about. Returns null when the user has not given enough to
 * go on, which for a single-carrier waveform means an empty rate box.
 */
function resolveRatePlan(entry) {
  if (!entry || typeof IqFormats === "undefined") return null;

  if (entry.signalClass === "MC") {
    const sampleRateHz = IqFormats.mcSampleRateHz(entry.bandwidth, entry.oversampling);
    if (!sampleRateHz) return null;
    return {
      sampleRateHz,
      symbolRateHz: null,
      // For a multi-carrier waveform the channel bandwidth is the occupied
      // bandwidth to within the standard's spectral mask, and it is fixed.
      occupiedBandwidthHz: parseFloat(String(entry.bandwidth)) * 1e6,
    };
  }

  const sampleRateMHz = parseFloat(exportElements.scSampleRate.value);
  const bandwidthMHz = parseFloat(exportElements.scBandwidth.value);
  const driverIsRate = scRateDriver === "sampleRate";

  return IqFormats.scRates({
    sampleRateHz: driverIsRate && sampleRateMHz > 0 ? sampleRateMHz * 1e6 : NaN,
    occupiedBandwidthHz: !driverIsRate && bandwidthMHz > 0 ? bandwidthMHz * 1e6 : NaN,
    rolloff: entry.rolloff,
    oversampling: entry.oversampling,
  });
}

// The generator's clock ceiling is a rough figure for the base model, so this
// only ever advises. Wi-Fi at 320 MHz needs 1.28 GSa/s, which no mid-range
// generator will play, and finding that out before the download is worth a
// line of text.
function rateWarningFor(plan, generator) {
  if (!plan || !generator || !generator.typicalMaxClockHz) return "";
  if (plan.sampleRateHz <= generator.typicalMaxClockHz) return "";
  return `${IqFormats.formatHz(plan.sampleRateHz)} is above the ${IqFormats.formatHz(generator.typicalMaxClockHz)}`
    + ` ARB clock a base ${generator.label} typically offers — check your instrument's options before relying on this file.`;
}

function refreshRateUi() {
  if (!exportElements.targetGenerator || typeof IqFormats === "undefined") return;

  const isSingleCarrier = formElements.signalClass.value === "SC";
  document.querySelectorAll("[data-rate]").forEach((field) => {
    field.hidden = field.dataset.rate !== (isSingleCarrier ? "sc" : "mc");
  });

  const plan = resolveRatePlan(activeMatch);

  if (!isSingleCarrier) {
    exportElements.mcSampleRate.value = plan
      ? `${IqFormats.formatHz(plan.sampleRateHz)} (bandwidth × oversampling)`
      : "—";
  } else if (plan) {
    // Only the derived box is rewritten, so the number the user typed keeps
    // whatever precision they typed it with.
    if (scRateDriver === "sampleRate") {
      exportElements.scBandwidth.value = round6(plan.occupiedBandwidthHz / 1e6);
    } else {
      exportElements.scSampleRate.value = round6(plan.sampleRateHz / 1e6);
    }
  }

  const note = exportElements.rateNote;
  if (!note) return;

  if (!plan) {
    // The derived box is cleared too, so a stale bandwidth cannot sit next to
    // an empty rate box looking like it still means something.
    if (isSingleCarrier) {
      if (scRateDriver === "sampleRate") exportElements.scBandwidth.value = "";
      else exportElements.scSampleRate.value = "";
    }
    note.className = "field-note rate-note";
    note.textContent = isSingleCarrier
      ? "Enter a sample rate or an occupied bandwidth to enable the instrument formats."
      : "This selection is a set of figures rather than one waveform, so it has no sample rate and no instrument format.";
    return;
  }

  const warning = rateWarningFor(plan, selectedGenerator());
  if (warning) {
    note.className = "field-note rate-note rate-warning";
    note.textContent = warning;
    return;
  }

  note.className = "field-note rate-note";
  note.textContent = isSingleCarrier
    ? `${IqFormats.formatHz(plan.symbolRateHz)} symbol rate at ${activeMatch.oversampling} oversampling,`
      + ` occupying ${IqFormats.formatBandwidthHz(plan.occupiedBandwidthHz)} at roll-off ${activeMatch.rolloff}.`
      + " The two boxes are linked — nothing is resampled."
    : `Fixed by the waveform: ${activeMatch.bandwidth} channel at ${activeMatch.oversampling} oversampling.`;
}

function round6(value) {
  return String(Math.round(value * 1e6) / 1e6);
}

function processManifest(manifestItems) {
  return manifestItems.map((item) => {
    const signalClass = item.signal_class || (item.category && item.category.includes("Multi") ? "MC" : "SC");
    return {
      id: item.id || item.name,
      name: item.name || item.id || "Signal",
      signalClass: item.signalClass || signalClass,
      signalFamily: item.signalFamily || item.category || "General",
      standard: item.standard || "WiFi4",
      mcs: String(item.mcs ?? "0"),
      bandwidth: item.bandwidth ? (item.bandwidth.includes("MHz") ? item.bandwidth : `${item.bandwidth} MHz`) : "20 MHz",
      memoryLength: item.memoryLength || "4 MB",
      modulation: item.modulation || "64-QAM",
      rolloff: item.rolloff || "0.25",
      symbols: item.symbols,
      filterType: item.filterType || "RRC",
      oversampling: item.oversampling || "4x",
      // `papr` is the waveform's peak-to-average ratio with idle and pad
      // excluded; `meanPacketPapr` averages the per-packet values and is only
      // present when the file holds more than one packet. The older maxPapr /
      // meanPapr keys are read as a fallback so a stale manifest still renders.
      papr: item.papr || item.maxPapr || item.max_papr || "N/A",
      meanPacketPapr: item.meanPacketPapr || item.meanPapr || item.mean_papr || "N/A",
      isAlias: Boolean(item.isAlias),
      aliasNote: item.aliasNote || "",
      contributor: item.contributor || "RF Engine PA Signal Library",
      // Present only on signals that came in through docs/contribute.html.
      isContributed: Boolean(item.isContributed),
      sampleRate: item.sampleRate || "",
      licence: item.licence || "",
      provenance: item.provenance || null,
      paSurvey: item.paSurvey || null,
      signalFiles: item.data_file ? [{
        label: `${item.name || 'Signal'} Data File`,
        repoPath: item.data_file,
        description: item.description || "Waveform raw dataset."
      }] : [],
      plots: (item.figures || []).map(fig => ({
        label: fig.name,
        repoPath: fig.path,
        description: fig.name
      }))
    };
  });
}

function buildFallbackCatalog() {
  const mcEntries = HARDCODED_MC_PATHS.map((path) => {
    const fileName = path.split("/").at(-1);
  const match = fileName.match(/^wifi4_mcs=(\d+)_bw=(\d+)_GI=(\w+)_osf=(\d+)_(4MB|8MB)\.bin$/i);

    if (!match) return null;

    const [, mcs, bandwidth, GI, osf, memoryLength] = match;
    const sizeLabel = memoryLength.replace("MB", " MB");
    const plotPath = `Figures/WiFi/802.11N (WiFi4)/wifi4_Constellation_mcs=${mcs}_bw=${bandwidth}_GI=${GI}_osf=${osf}_${memoryLength}.png`;

    return {
      id: `mc-${mcs}-${bandwidth}-${memoryLength}`,
      signalClass: "MC",
      signalFamily: "WiFi",
      standard: "WiFi4",
      mcs,
      bandwidth: `${bandwidth} MHz`,
      memoryLength: sizeLabel,
      oversampling: `${osf}x`,
      signalFiles: [
        {
          label: `${sizeLabel} Binary Signal`,
          repoPath: path,
          description: `32-bit I and 32-bit Q samples, oversampled ${osf}x.`,
        },
      ],
      plots: [
        {
          label: "Constellation",
          repoPath: plotPath,
          description: fileName.replace(".bin", ""),
        },
      ],
    };
  }).filter(Boolean);

  const scEntries = HARDCODED_SC_CONFIGS.map((config) => {
    const qamLabel = config.modulation.replace("-QAM", "");
    const prefix = `QAM${qamLabel}`;

    return {
      id: `sc-${config.rolloff}-${qamLabel}`,
      signalClass: "SC",
      signalFamily: "QAM",
      modulation: config.modulation,
      rolloff: config.rolloff,
      filterType: "RRC",
      signalFiles: [],
      plots: SC_PLOT_SUFFIXES.map((plot) => ({
        label: plot.label,
        repoPath: `${config.figureDir}/${prefix}_${plot.suffix}`,
        description: `${config.modulation} with roll-off ${config.rolloff}`,
      })),
    };
  });

  return [...mcEntries, ...scEntries];
}

function onSignalClassChange() {
  const selectedClass = formElements.signalClass.value;
  const families = unique(
    catalog
      .filter((entry) => entry.signalClass === selectedClass)
      .map((entry) => entry.signalFamily),
  );

  populateSelect(formElements.signalFamily, families);
  populateDependentSelectors(selectedClass);
  setFieldVisibility(selectedClass);
  refreshResults();
}

function populateDependentSelectors(signalClass) {
  const family = formElements.signalFamily.value;
  const classEntries = catalog.filter(
    (entry) => entry.signalClass === signalClass && entry.signalFamily === family,
  );

  if (signalClass === "MC") {
    populateSelect(formElements.standard, unique(classEntries.map((entry) => entry.standard)));
    populateSelect(formElements.mcs, unique(classEntries.map((entry) => entry.mcs)));
    populateSelect(formElements.bandwidth, unique(classEntries.map((entry) => entry.bandwidth)));
    populateSelect(formElements.memoryLength, unique(classEntries.map((entry) => entry.memoryLength)));
    return;
  }

  populateSelect(formElements.modulation, unique(classEntries.map((entry) => entry.modulation)));
  populateSelect(formElements.rolloff, unique(classEntries.map((entry) => entry.rolloff)));
}

function setFieldVisibility(signalClass) {
  const visibleFields = new Set(fieldVisibility[signalClass]);

  document.querySelectorAll("[data-field]").forEach((field) => {
    field.hidden = !visibleFields.has(field.dataset.field);
  });
}

function refreshResults() {
  const signalClass = formElements.signalClass.value;
  const signalFamily = formElements.signalFamily.value;
  populateDependentSelectors(signalClass);

  const matches = catalog.filter((entry) => {
    if (entry.signalClass !== signalClass || entry.signalFamily !== signalFamily) {
      return false;
    }

    if (signalClass === "MC") {
      return (
        entry.standard === formElements.standard.value &&
        entry.mcs === formElements.mcs.value &&
        entry.bandwidth === formElements.bandwidth.value &&
        entry.memoryLength === formElements.memoryLength.value
      );
    }

    return (
      entry.modulation === formElements.modulation.value &&
      entry.rolloff === formElements.rolloff.value
    );
  });

  renderResults(matches, signalClass);
}

function renderResults(matches, signalClass) {
  signalCards.innerHTML = "";
  plotGallery.innerHTML = "";

  resultTitle.textContent = signalClass === "MC" ? "Matching multi-carrier assets" : "Matching single-carrier assets";
  resultCount.textContent = `${matches.length} match${matches.length === 1 ? "" : "es"}`;
  emptyState.hidden = matches.length > 0;
  summaryCard.hidden = matches.length === 0;

  if (matches.length === 0) {
    activeMatch = null;
    if (downloadZipBtn) downloadZipBtn.style.display = "none";
    refreshRateUi();
    return;
  }

  const [entry] = matches;
  activeMatch = entry;

  if (downloadZipBtn) {
    downloadZipBtn.style.display = "inline-block";
  }

  renderSummary(entry);
  renderSignalCards(entry);
  renderPlots(entry);
  refreshRateUi();
}

function renderSummary(entry) {
  const chips = [];

  // 1. Core classification
  chips.push(chip(entry.signalClass));
  chips.push(chip(entry.signalFamily));

  // 2. Class-specific filtering
  if (entry.signalClass === "MC") {
    if (entry.standard) chips.push(chip(entry.standard));
    if (entry.mcs !== undefined && entry.mcs !== null) chips.push(chip(`MCS ${entry.mcs}`));
    if (entry.bandwidth) chips.push(chip(entry.bandwidth));
    if (entry.memoryLength) chips.push(chip(entry.memoryLength));
    if (entry.oversampling) chips.push(chip(`Oversampling ${entry.oversampling}`));
  } else if (entry.signalClass === "SC") {
    if (entry.modulation) chips.push(chip(entry.modulation));
    if (entry.symbols) chips.push(chip(entry.symbols));
    if (entry.rolloff) chips.push(chip(`Roll-off ${entry.rolloff}`));
    if (entry.filterType) chips.push(chip(entry.filterType));
  }

  // 3. Measured PAPR. Only shown when it was actually computed from the file.
  if (entry.papr && entry.papr !== "N/A") {
    chips.push(`<span class="chip chip-metric">PAPR: ${escapeHtml(entry.papr)}</span>`);
  }
  if (entry.meanPacketPapr && entry.meanPacketPapr !== "N/A") {
    chips.push(`<span class="chip chip-metric">Mean packet PAPR: ${escapeHtml(entry.meanPacketPapr)}</span>`);
  }

  if (entry.isContributed) {
    chips.push(`<span class="chip chip-metric">Contributed</span>`);
  }
  if (entry.sampleRate) chips.push(chip(entry.sampleRate));

  // 4. Educational alias note banner
  let noteBanner = "";
  if (entry.isAlias && entry.aliasNote) {
    noteBanner = `
      <div style="margin-top: 12px; font-size: 0.85rem; color: #5a524e; font-style: italic; border-top: 1px dashed #dcd5c9; padding-top: 8px;">
        ℹ️ <strong>Note:</strong> ${escapeHtml(entry.aliasNote)}
      </div>
    `;
  }

  summaryCard.innerHTML = `
    <h3 style="color: #5c1d2e; font-weight: 700;">${entry.signalClass === "MC" ? "Selected multi-carrier profile" : "Selected single-carrier profile"}</h3>
    <div class="summary-meta">${chips.join("")}</div>
    ${noteBanner}
    ${renderProvenance(entry)}
    ${renderSurveyLink(entry)}
  `;
}

// A contributed waveform is only as trustworthy as its provenance, so who made
// it and under what licence is shown next to its statistics rather than buried
// in the manifest.
function renderProvenance(entry) {
  if (!entry.isContributed) return "";
  const p = entry.provenance || {};
  const bits = [
    entry.contributor ? `Contributed by ${entry.contributor}` : null,
    p.affiliation || null,
    p.generatorTool ? `generated with ${p.generatorTool}` : null,
    entry.licence ? `licensed ${entry.licence}` : null,
  ].filter(Boolean);
  if (!bits.length) return "";
  return `<p class="provenance-note">${escapeHtml(bits.join(" — "))}</p>`;
}

// The cross-reference carries its own confidence: most papers do not describe
// their test waveform precisely enough to reproduce, and saying so is the
// difference between a citation and an overclaim.
function renderSurveyLink(entry) {
  const s = entry.paSurvey;
  if (!s) return "";
  const label = [s.title, s.authors, s.venueYear].filter(Boolean).join(", ");
  const link = s.doi
    ? `<a class="action-link" href="https://doi.org/${encodeURIComponent(s.doi)}" target="_blank" rel="noreferrer">${escapeHtml(s.doi)}</a>`
    : "";
  const confidence = s.matchConfidence
    ? `<span class="chip">${escapeHtml(s.matchConfidence)} match</span>`
    : "";
  const heading = s.inSurvey === true
    ? "Cross-referenced to the Hua Wang PA survey"
    : "Possible PA survey cross-reference (unconfirmed)";
  return `
    <div class="survey-note">
      <h4>${heading}</h4>
      <p>${escapeHtml(label || "Reference details not supplied.")} ${link}</p>
      <div class="summary-meta">${confidence}</div>
      ${s.notes ? `<p class="survey-caveat">${escapeHtml(s.notes)}</p>` : ""}
    </div>`;
}

function renderSignalCards(entry) {
  if (entry.signalFiles.length === 0) {
    signalCards.innerHTML = `
      <article class="asset-card">
        <h3>No signal file published yet</h3>
        <p class="card-subtitle">Plots are available for this selection, but a downloadable waveform file is not currently present in the repository.</p>
      </article>
    `;
    return;
  }

  // This link is the archive file itself. Anything a signal generator can load
  // is built by the bundle export, which needs the sample rate and format
  // choices from the form.
  signalCards.innerHTML = entry.signalFiles.map((file) => `
    <article class="asset-card">
      <h3>${escapeHtml(file.label)}</h3>
      <p class="card-subtitle">${escapeHtml(file.description)}</p>
      <p class="card-subtitle">Archive format: interleaved 32-bit float I/Q, little-endian, no header. For a Keysight or Rohde &amp; Schwarz waveform, use Download Bundle.</p>
      <a class="action-button" href="${toRawUrl(file.repoPath)}" target="_blank" rel="noreferrer">Download Raw Signal</a>
    </article>
  `).join("");
}

function renderPlots(entry) {
  plotGallery.innerHTML = entry.plots.map((plot) => `
    <article class="plot-card">
      <img src="${toRawUrl(plot.repoPath)}" alt="${escapeHtml(plot.label)}">
      <div class="plot-card-body">
        <h3>${escapeHtml(plot.label)}</h3>
        <p>${escapeHtml(plot.description)}</p>
        <a class="action-link" href="${toBlobUrl(plot.repoPath)}" target="_blank" rel="noreferrer">Open Plot</a>
      </div>
    </article>
  `).join("");
}

// BibTeX Generator inside app.js
function generateBibtex(entry) {
  return `@misc{pa_standard_sig_${entry.id},
  title        = {${entry.name} Standard PA Test Signal},
  author       = {${entry.contributor || 'RF Engine PA Signal Library'}},
  year         = {2026},
  publisher    = {GitHub},
  journal      = {PA Standard Signal Repository},
  howpublished = {\\url{https:/noyades.github.io/PA-standard-sig/}}
}`;
}

async function downloadBundle() {
  if (!activeMatch) return;
  if (typeof JSZip === "undefined") {
    alert("JSZip library is not loaded. Please ensure JSZip is included in index.html.");
    return;
  }

  const formats = selectedFormats();
  if (formats.length === 0) {
    alert("Choose at least one file format to download.");
    return;
  }

  const generator = selectedGenerator();
  const ratePlan = resolveRatePlan(activeMatch);
  const needsRate = formats.some((id) => id !== "raw");

  // The instrument formats cannot be written without a sample rate: the .wv
  // header carries one, and the Keysight SCPI sidecar is useless without one.
  // Refusing here beats shipping a file with a made-up clock in it.
  if (needsRate && !ratePlan) {
    alert(activeMatch.signalClass === "SC"
      ? "Enter a sample rate or an occupied bandwidth before exporting an instrument format."
      : "This selection has no single sample rate, so only the raw format can be exported.");
    return;
  }

  const zip = new JSZip();
  const rawLength = formElements.targetLength ? formElements.targetLength.value : "";
  const targetLength = rawLength ? parseInt(rawLength, 10) : null;
  const skipped = [];

  downloadZipBtn.textContent = "Packing ZIP...";
  downloadZipBtn.disabled = true;

  try {
    for (const file of activeMatch.signalFiles) {
      const url = toRawUrl(file.repoPath);
      const filename = file.repoPath.split("/").pop();

      if (/\.bin$/i.test(filename)) {
        addWaveformToZip(zip, {
          arrayBuffer: await fetch(url).then((r) => r.arrayBuffer()),
          filename,
          formats,
          generator,
          ratePlan,
          targetLength,
        });
      } else {
        // Not an I/Q binary. Converting a CSV or a text sidecar into an ARB
        // waveform would be inventing samples, so it goes in as-is and the
        // README says why the instrument files are missing for it.
        zip.file(filename, await fetch(url).then((r) => r.text()));
        if (needsRate) skipped.push(filename);
      }
    }

    if (activeMatch.plots && activeMatch.plots.length > 0) {
      const figFolder = zip.folder("figures");
      for (const plot of activeMatch.plots) {
        const figBlob = await fetch(toRawUrl(plot.repoPath)).then((r) => r.blob());
        figFolder.file(plot.repoPath.split("/").pop(), figBlob);
      }
    }

    if (skipped.length) {
      zip.file("README_not-converted.txt", [
        "These files were included unchanged:",
        "",
        ...skipped.map((name) => `  ${name}`),
        "",
        "They are not interleaved float32 I/Q, so there is nothing to convert into",
        "a signal generator waveform. Only .bin files in this library hold samples.",
      ].join("\n"));
    }

    const blob = await zip.generateAsync({ type: "blob" });
    const link = document.createElement("a");
    const objectUrl = URL.createObjectURL(blob);
    link.href = objectUrl;
    link.download = `${activeMatch.id}_export.zip`;
    link.click();
    // Revoking synchronously can cancel a download that has not started yet;
    // a bundle can be tens of megabytes, so the URL is released on the next
    // turn of the event loop instead.
    setTimeout(() => URL.revokeObjectURL(objectUrl), 0);
  } catch (err) {
    console.error("Failed to generate ZIP package:", err);
    alert("An error occurred while generating the bundle. Please check the console.");
  } finally {
    downloadZipBtn.textContent = "Download Bundle (ZIP)";
    downloadZipBtn.disabled = false;
  }
}

/*
 * Reads one archived waveform and writes out every format that was asked for,
 * plus the README explaining what was done to it.
 *
 * The file is parsed to samples once and the length change applied once, so
 * the .bin, the .wfm and the .wv in a bundle are the same waveform rather than
 * three independently derived ones.
 */
function addWaveformToZip(zip, options) {
  const { arrayBuffer, filename, formats, generator, ratePlan, targetLength } = options;

  const source = IqFormats.readFloat32Iq(arrayBuffer);
  const iq = IqFormats.fitToLength(source, targetLength);
  const stats = IqFormats.iqStats(iq);

  const stem = filename.replace(/\.bin$/i, "");
  const baseName = targetLength ? `${stem}_${targetLength}samples` : stem;
  const safeName = IqFormats.instrumentSafeName(baseName);
  const clockHz = ratePlan ? ratePlan.sampleRateHz : null;

  if (formats.includes("raw")) {
    // Byte-for-byte the archived file unless the length was changed, in which
    // case it is the same float32 layout at the new length.
    zip.file(`${baseName}.bin`, iq === source ? arrayBuffer : iq.buffer.slice(0, iq.length * 4));
  }

  if (formats.includes("keysight") && clockHz) {
    zip.file(`${safeName}.wfm`, IqFormats.toKeysightWfm(iq, stats));
  }

  if (formats.includes("rs") && clockHz) {
    zip.file(`${safeName}.wv`, IqFormats.toRohdeSchwarzWv(iq, stats, {
      clockHz,
      comment: `${activeMatch.name || activeMatch.id} - PA Standard Signal Library`,
    }));
  }

  zip.file(`${baseName}_README.txt`, IqFormats.exportNotes({
    entryName: activeMatch.name || activeMatch.id,
    sourceFileName: `${baseName}.bin`,
    safeName,
    formats,
    stats,
    clockHz,
    symbolRateHz: ratePlan ? ratePlan.symbolRateHz : null,
    occupiedBandwidthHz: ratePlan ? ratePlan.occupiedBandwidthHz : null,
    signalClass: activeMatch.signalClass,
    rolloff: activeMatch.rolloff,
    oversampling: activeMatch.oversampling,
    generatorLabel: generator.label,
    catalogPapr: activeMatch.papr,
    catalogMeanPacketPapr: activeMatch.meanPacketPapr,
    targetLength,
    rateWarning: rateWarningFor(ratePlan, generator),
  }));
}

function populateSelect(select, values) {
  const currentValue = select.value;

  select.innerHTML = values.map((value) => `<option value="${escapeAttribute(value)}">${escapeHtml(value)}</option>`).join("");

  if (values.includes(currentValue)) {
    select.value = currentValue;
  }
}

function unique(values) {
  return [...new Set(values)].sort((left, right) => left.localeCompare(right, undefined, { numeric: true }));
}

function chip(value) {
  return `<span class="chip">${escapeHtml(value)}</span>`;
}

function toRawUrl(repoPath) {
  return `https://raw.githubusercontent.com/${REPOSITORY.owner}/${REPOSITORY.name}/${REPOSITORY.branch}/${encodePath(repoPath)}`;
}

function toBlobUrl(repoPath) {
  return `https://github.com/${REPOSITORY.owner}/${REPOSITORY.name}/blob/${REPOSITORY.branch}/${encodePath(repoPath)}`;
}

function encodePath(path) {
  return path.split("/").map((part) => encodeURIComponent(part)).join("/");
}

function escapeHtml(value) {
  return value
    .replaceAll("&", "&amp;")
    .replaceAll("<", "&lt;")
    .replaceAll(">", "&gt;")
    .replaceAll('"', "&quot;")
    .replaceAll("'", "&#39;");
}

function escapeAttribute(value) {
  return escapeHtml(value);
}