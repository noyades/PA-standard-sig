const REPOSITORY = {
  owner: "noyades",
  name: "PA-standard-sig",
  branch: "main",
};

// Fallback hardcoded catalog if manifest.json is unreachable during local testing
const HARDCODED_MC_PATHS = [
  "Signals/Multi Carrier/WiFi/802.11N (WiFi4)/wifi4_mcs=0_bw=20_osf=4_4MB.bin",
  "Signals/Multi Carrier/WiFi/802.11N (WiFi4)/wifi4_mcs=0_bw=20_osf=4_8MB.bin",
  "Signals/Multi Carrier/WiFi/802.11N (WiFi4)/wifi4_mcs=0_bw=40_osf=4_4MB.bin",
  "Signals/Multi Carrier/WiFi/802.11N (WiFi4)/wifi4_mcs=0_bw=40_osf=4_8MB.bin",
  "Signals/Multi Carrier/WiFi/802.11N (WiFi4)/wifi4_mcs=1_bw=20_osf=4_4MB.bin",
  "Signals/Multi Carrier/WiFi/802.11N (WiFi4)/wifi4_mcs=1_bw=20_osf=4_8MB.bin",
  "Signals/Multi Carrier/WiFi/802.11N (WiFi4)/wifi4_mcs=1_bw=40_osf=4_4MB.bin",
  "Signals/Multi Carrier/WiFi/802.11N (WiFi4)/wifi4_mcs=1_bw=40_osf=4_8MB.bin",
  "Signals/Multi Carrier/WiFi/802.11N (WiFi4)/wifi4_mcs=2_bw=20_osf=4_4MB.bin",
  "Signals/Multi Carrier/WiFi/802.11N (WiFi4)/wifi4_mcs=2_bw=20_osf=4_8MB.bin",
  "Signals/Multi Carrier/WiFi/802.11N (WiFi4)/wifi4_mcs=2_bw=40_osf=4_4MB.bin",
  "Signals/Multi Carrier/WiFi/802.11N (WiFi4)/wifi4_mcs=2_bw=40_osf=4_8MB.bin",
  "Signals/Multi Carrier/WiFi/802.11N (WiFi4)/wifi4_mcs=3_bw=20_osf=4_4MB.bin",
  "Signals/Multi Carrier/WiFi/802.11N (WiFi4)/wifi4_mcs=3_bw=20_osf=4_8MB.bin",
  "Signals/Multi Carrier/WiFi/802.11N (WiFi4)/wifi4_mcs=3_bw=40_osf=4_4MB.bin",
  "Signals/Multi Carrier/WiFi/802.11N (WiFi4)/wifi4_mcs=3_bw=40_osf=4_8MB.bin",
  "Signals/Multi Carrier/WiFi/802.11N (WiFi4)/wifi4_mcs=4_bw=20_osf=4_4MB.bin",
  "Signals/Multi Carrier/WiFi/802.11N (WiFi4)/wifi4_mcs=4_bw=20_osf=4_8MB.bin",
  "Signals/Multi Carrier/WiFi/802.11N (WiFi4)/wifi4_mcs=4_bw=40_osf=4_4MB.bin",
  "Signals/Multi Carrier/WiFi/802.11N (WiFi4)/wifi4_mcs=4_bw=40_osf=4_8MB.bin",
  "Signals/Multi Carrier/WiFi/802.11N (WiFi4)/wifi4_mcs=5_bw=20_osf=4_4MB.bin",
  "Signals/Multi Carrier/WiFi/802.11N (WiFi4)/wifi4_mcs=5_bw=20_osf=4_8MB.bin",
  "Signals/Multi Carrier/WiFi/802.11N (WiFi4)/wifi4_mcs=5_bw=40_osf=4_4MB.bin",
  "Signals/Multi Carrier/WiFi/802.11N (WiFi4)/wifi4_mcs=5_bw=40_osf=4_8MB.bin",
  "Signals/Multi Carrier/WiFi/802.11N (WiFi4)/wifi4_mcs=6_bw=20_osf=4_4MB.bin",
  "Signals/Multi Carrier/WiFi/802.11N (WiFi4)/wifi4_mcs=6_bw=20_osf=4_8MB.bin",
  "Signals/Multi Carrier/WiFi/802.11N (WiFi4)/wifi4_mcs=6_bw=40_osf=4_4MB.bin",
  "Signals/Multi Carrier/WiFi/802.11N (WiFi4)/wifi4_mcs=6_bw=40_osf=4_8MB.bin",
  "Signals/Multi Carrier/WiFi/802.11N (WiFi4)/wifi4_mcs=7_bw=20_osf=4_4MB.bin",
  "Signals/Multi Carrier/WiFi/802.11N (WiFi4)/wifi4_mcs=7_bw=20_osf=4_8MB.bin",
  "Signals/Multi Carrier/WiFi/802.11N (WiFi4)/wifi4_mcs=7_bw=40_osf=4_4MB.bin",
  "Signals/Multi Carrier/WiFi/802.11N (WiFi4)/wifi4_mcs=7_bw=40_osf=4_8MB.bin",
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

  onSignalClassChange();
}

function processManifest(manifestItems) {
  return manifestItems.map((item) => {
    const signalClass = item.signal_class || (item.category && item.category.includes("Multi") ? "MC" : "MC");
    return {
      id: item.id || item.name,
      signalClass: item.signalClass || signalClass,
      signalFamily: item.signalFamily || item.category || "General",
      standard: item.standard || "WiFi4",
      mcs: String(item.mcs ?? "0"),
      bandwidth: item.bandwidth ? (item.bandwidth.includes("MHz") ? item.bandwidth : `${item.bandwidth} MHz`) : "20 MHz",
      memoryLength: item.memoryLength || "4 MB",
      modulation: item.modulation || "64-QAM",
      rolloff: item.rolloff || "0.25",
      filterType: item.filterType || "RRC",
      oversampling: item.oversampling || "4x",
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
    const match = fileName.match(/^wifi4_mcs=(\d+)_bw=(\d+)_osf=(\d+)_(4MB|8MB)\.bin$/i);

    if (!match) return null;

    const [, mcs, bandwidth, osf, memoryLength] = match;
    const sizeLabel = memoryLength.replace("MB", " MB");
    const plotPath = `Figures/WiFi/802.11N (WiFi4)/wifi4_Constellation_mcs=${mcs}_bw=${bandwidth}_osf=${osf}_${memoryLength}.png`;

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

  // 3. Computed PAPR metrics (using highlighted metric chip)
  if (entry.maxPapr && entry.maxPapr !== "N/A") {
    chips.push(`<span class="chip chip-metric">Max PAPR: ${escapeHtml(entry.maxPapr)}</span>`);
  }
  if (entry.meanPapr && entry.meanPapr !== "N/A") {
    chips.push(`<span class="chip chip-metric">Mean PAPR: ${escapeHtml(entry.meanPapr)}</span>`);
  }

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
  `;
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

  signalCards.innerHTML = entry.signalFiles.map((file) => `
    <article class="asset-card">
      <h3>${escapeHtml(file.label)}</h3>
      <p class="card-subtitle">${escapeHtml(file.description)}</p>
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

  const zip = new JSZip();
  const rawLength = formElements.targetLength ? formElements.targetLength.value : "";
  const targetLength = rawLength ? parseInt(rawLength, 10) : null;

  downloadZipBtn.textContent = "Packing ZIP...";
  downloadZipBtn.disabled = true;

  try {
    // 1. Process Signal Files
    for (const file of activeMatch.signalFiles) {
      const url = toRawUrl(file.repoPath);
      const filename = file.repoPath.split('/').pop();

      if (filename.endsWith('.bin')) {
        // Binary IQ payload processing
        const arrayBuf = await fetch(url).then(r => r.arrayBuffer());
        let finalBuf = arrayBuf;

        if (targetLength && targetLength > 0) {
          const bytesPerSample = 8; // 32-bit I + 32-bit Q
          const targetBytes = targetLength * bytesPerSample;
          const uint8 = new Uint8Array(arrayBuf);
          const slicedUint8 = new Uint8Array(targetBytes);

          for (let i = 0; i < targetBytes; i++) {
            slicedUint8[i] = uint8[i % uint8.length];
          }
          finalBuf = slicedUint8.buffer;
        }

        const outName = targetLength 
          ? `${filename.replace(/\.bin$/i, '')}_${targetLength}samples.bin`
          : filename;
        zip.file(outName, finalBuf);
      } else {
        // Text/CSV based payload processing
        const text = await fetch(url).then(r => r.text());
        let finalContent = text;

        if (targetLength && targetLength > 0) {
          const lines = text.trim().split('\n');
          const outputLines = [];
          for (let i = 0; i < targetLength; i++) {
            outputLines.push(lines[i % lines.length]);
          }
          finalContent = outputLines.join('\n');
        }

        const outName = targetLength 
          ? `${filename.replace(/\.[^/.]+$/, '')}_${targetLength}samples.csv`
          : filename;
        zip.file(outName, finalContent);
      }
    }

    // 2. Fetch and add plots
    if (activeMatch.plots && activeMatch.plots.length > 0) {
      const figFolder = zip.folder("figures");
      for (const plot of activeMatch.plots) {
        const plotUrl = toRawUrl(plot.repoPath);
        const figBlob = await fetch(plotUrl).then(r => r.blob());
        const figName = plot.repoPath.split('/').pop();
        figFolder.file(figName, figBlob);
      }
    }

    // 3. Trigger Download
    const blob = await zip.generateAsync({ type: "blob" });
    const a = document.createElement("a");
    a.href = URL.createObjectURL(blob);
    a.download = `${activeMatch.id}_export.zip`;
    a.click();
  } catch (err) {
    console.error("Failed to generate ZIP package:", err);
    alert("An error occurred while generating the bundle. Please check the console.");
  } finally {
    downloadZipBtn.textContent = "Download Bundle (ZIP)";
    downloadZipBtn.disabled = false;
  }
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