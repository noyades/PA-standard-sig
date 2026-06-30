const REPOSITORY = {
  owner: "rf-engine",
  name: "PA-standard-sig",
  branch: "main",
};

const MC_SIGNAL_PATHS = [
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

const SC_FIGURE_CONFIGS = [
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
};

const summaryCard = document.getElementById("summaryCard");
const signalCards = document.getElementById("signalCards");
const plotGallery = document.getElementById("plotGallery");
const resultCount = document.getElementById("resultCount");
const resultTitle = document.getElementById("resultTitle");
const emptyState = document.getElementById("emptyState");

const catalog = buildCatalog();

initialize();

function initialize() {
  populateSelect(formElements.signalClass, unique(catalog.map((entry) => entry.signalClass)));
  formElements.signalClass.addEventListener("change", onSignalClassChange);
  formElements.signalFamily.addEventListener("change", refreshResults);
  formElements.standard.addEventListener("change", refreshResults);
  formElements.mcs.addEventListener("change", refreshResults);
  formElements.bandwidth.addEventListener("change", refreshResults);
  formElements.memoryLength.addEventListener("change", refreshResults);
  formElements.modulation.addEventListener("change", refreshResults);
  formElements.rolloff.addEventListener("change", refreshResults);
  onSignalClassChange();
}

function buildCatalog() {
  const mcEntries = MC_SIGNAL_PATHS.map((path) => {
    const fileName = path.split("/").at(-1);
    const match = fileName.match(/^wifi4_mcs=(\d+)_bw=(\d+)_osf=(\d+)_(4MB|8MB)\.bin$/i);

    if (!match) {
      return null;
    }

    const [, mcs, bandwidth, osf, memoryLength] = match;
    const sizeLabel = memoryLength.replace("MB", " MB");
    const plotBase = fileName.replace(".bin", ".png");
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
          description: `${plotBase.replace(".png", "")}`,
        },
      ],
    };
  }).filter(Boolean);

  const scEntries = SC_FIGURE_CONFIGS.map((config) => {
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
    return;
  }

  const [entry] = matches;
  renderSummary(entry);
  renderSignalCards(entry);
  renderPlots(entry);
}

function renderSummary(entry) {
  const chips = [];

  chips.push(chip(entry.signalClass));
  chips.push(chip(entry.signalFamily));

  if (entry.standard) {
    chips.push(chip(entry.standard));
  }

  if (entry.mcs) {
    chips.push(chip(`MCS ${entry.mcs}`));
  }

  if (entry.bandwidth) {
    chips.push(chip(entry.bandwidth));
  }

  if (entry.memoryLength) {
    chips.push(chip(entry.memoryLength));
  }

  if (entry.modulation) {
    chips.push(chip(entry.modulation));
  }

  if (entry.rolloff) {
    chips.push(chip(`Roll-off ${entry.rolloff}`));
  }

  if (entry.filterType) {
    chips.push(chip(entry.filterType));
  }

  if (entry.oversampling) {
    chips.push(chip(`Oversampling ${entry.oversampling}`));
  }

  summaryCard.innerHTML = `
    <h3>${entry.signalClass === "MC" ? "Selected multi-carrier profile" : "Selected single-carrier profile"}</h3>
    <div class="summary-meta">${chips.join("")}</div>
  `;
}

function renderSignalCards(entry) {
  if (entry.signalFiles.length === 0) {
    signalCards.innerHTML = `
      <article class="asset-card">
        <h3>No signal file published yet</h3>
        <p class="card-subtitle">Plots are available for this selection, but a downloadable SC waveform file is not currently present in the repository.</p>
      </article>
    `;
    return;
  }

  signalCards.innerHTML = entry.signalFiles.map((file) => `
    <article class="asset-card">
      <h3>${escapeHtml(file.label)}</h3>
      <p class="card-subtitle">${escapeHtml(file.description)}</p>
      <a class="action-button" href="${toRawUrl(file.repoPath)}" target="_blank" rel="noreferrer">Download Signal</a>
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