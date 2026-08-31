# scripts/build_manifest.py
import os
import json
import re

from signal_analysis import calculate_papr

MANIFEST_FILE = os.path.join("docs", "manifest.json")

# Define aliasing rules for multi-carrier standards
ALIAS_CONFIGS = [
    {
        "source_prefix": "wifi4",
        "alias_standard": "WiFi5",
        "max_mcs": 7,
        "allowed_bw": [20, 40],
        "note": "WiFi 5 at MCS 0–7 (20/40 MHz) shares identical waveforms with WiFi 4."
    },
    {
        "source_prefix": "wifi6",
        "alias_standard": "WiFi7",
        "max_mcs": 9,
        "allowed_bw": [20, 40, 80, 160],
        "note": "WiFi 7 configurations at these MCS/BW rates map directly to corresponding WiFi 6 waveforms."
    }
]


# PAPR is measured by scripts/signal_analysis.py, which is also what
# scripts/ingest_submission.py and the browser-side preview in
# docs/contribute.js implement. Keeping one definition is what makes a
# contributed signal comparable with a curated one.


def format_fig_name(filename):
    name = filename.replace(".png", "").replace(".jpg", "").replace("_", " ")
    if "constellation" in name.lower():
        return "Constellation Heatmap"
    elif "derivative envelop" in name.lower():
        return "Derivative Envelope Histogram"
    elif "derivative phase" in name.lower():
        return "Derivative Phase Histogram"
    elif "envelop" in name.lower():
        return "Envelope Histogram"
    elif "phase" in name.lower():
        return "Phase Histogram"
    return name.title()


def read_sc_oversampling(repo_path, default=4):
    """Oversampling factor of a single-carrier waveform, from its sidecar CSV.

    A single-carrier file is pulse-shaped symbols with no sample rate of its
    own, so the browser has to ask the user for one. Turning that answer into a
    symbol rate and an occupied bandwidth needs the samples-per-symbol the file
    was written at, which lives only in the "<name>_properties.csv" written
    beside it. Every file in the library today says 4, but reading it beats
    assuming it, because a later sweep at a different factor would otherwise be
    published with a bandwidth figure that is quietly wrong.
    """
    sidecar = re.sub(r"\.[^./]+$", "", repo_path) + "_properties.csv"
    if not os.path.exists(sidecar):
        return default
    try:
        with open(sidecar, "r", encoding="utf-8", errors="replace") as handle:
            for line in handle:
                key, _, value = line.partition(",")
                if key.strip().lower() == "oversampling factor":
                    return int(float(value.strip()))
    except (OSError, ValueError):
        pass
    return default


def parse_alpha(alpha_str):
    """Converts folder string like 'alpha005' or 'alpha025' to decimal float string '0.05' or '0.25'."""
    clean = alpha_str.lower().replace("alpha", "").strip()
    if len(clean) == 3 and clean.startswith("0"):
        return f"0.{clean[1:]}"
    elif len(clean) == 2:
        return f"0.{clean}"
    return f"0.{clean}"


# -----------------------------------------------------------------
# WiFi figure indexing
# -----------------------------------------------------------------
# Figures are indexed from the Figures/ tree in their own right rather than
# being guessed at from a signal filename. The previous MC branch built one
# hard-coded constellation path per signal and checked whether it existed;
# that path never matched (Wi-Fi 4 constellations carry a GI=Long field, and
# Wi-Fi 5 figures live under their own directory), so every WiFi figure in the
# repository was silently absent from the published site.
#
# Each pattern below is anchored and named, so a figure dropped into
# Figures/WiFi/<standard>/ is picked up on the next manifest build with no code
# change. .github/workflows/pages.yml runs this script on every push to main,
# so committing a figure is enough to publish it.

FIGURE_ROOT = os.path.join("Figures", "WiFi")
FIGURE_EXTENSIONS = (".png", ".jpg", ".jpeg", ".svg")

STANDARD_BY_PREFIX = {
    "wifi4": "WiFi4",
    "wifi5": "WiFi5",
    "wifi6": "WiFi6",
    "wifi7": "WiFi7",
}

STAT_LABELS = {
    "env": "Envelope PDF",
    "denv": "Envelope Derivative PDF",
    "pha": "Phase PDF",
    "dpha": "Phase Derivative PDF",
}

# Order used when a card lists several figures.
KIND_ORDER = [
    "Constellation",
    "PAPR PDF",
    "PAPR CCDF",
    "PAPR PDF sweep",
    "Envelope PDF",
    "Envelope Derivative PDF",
    "Phase PDF",
    "Phase Derivative PDF",
]

# Bandwidth is matched with an optional CBW prefix because the statistics
# figures embed the channel-bandwidth string ("bw=CBW160") while the PAPR
# figures embed the plain number ("bw=160"). The doubled underscore in
# "_pdf__mcs=" is a legacy filename quirk, tolerated by "_+".
FIGURE_PATTERNS = [
    (re.compile(
        r"^(?P<prefix>wifi\d)_Constellation_mcs=(?P<mcs>\d+)_bw=(?P<bw>\d+)"
        r"(?:_GI=(?P<gi>[A-Za-z]+))?_osf=(?P<osf>\d+)_(?P<mem>\d+MB)$", re.I), "Constellation"),
    (re.compile(
        r"^(?P<prefix>wifi\d)_PAPRPDF(?:_(?P<mode>data|full))?"
        r"_mcs=(?P<mcs>\d+)_bw=(?P<bw>\d+)$", re.I), "PAPR PDF"),
    (re.compile(
        r"^(?P<prefix>wifi\d)_PAPRCCDF(?:_(?P<mode>data|full))?"
        r"_mcs=(?P<mcs>\d+)_bw=(?P<bw>\d+)$", re.I), "PAPR CCDF"),
    (re.compile(
        r"^(?P<prefix>wifi\d)_(?P<stat>env|denv|pha|dpha)_pdf_+"
        r"mcs=(?P<mcs>\d+)_bw=(?:CBW)?(?P<bw>\d+)$", re.I), "STAT"),
    (re.compile(
        r"^(?P<prefix>wifi\d)_mcs=mcs=(?P<lo>\d+)(?:-(?P<hi>\d+))?_papr_pdf$", re.I), "PAPR PDF sweep"),
]


def describe_figure(kind, groups):
    """Human-readable label, including which PAPR definition was measured."""
    mode = groups.get("mode")
    if kind == "Constellation":
        return f"Constellation ({groups['mem'].replace('MB', ' MB')})"
    if kind in ("PAPR PDF", "PAPR CCDF"):
        if mode and mode.lower() == "data":
            return f"{kind} (data field)"
        if mode and mode.lower() == "full":
            return f"{kind} (full burst)"
        return kind
    if kind == "PAPR PDF sweep":
        span = groups["lo"] if not groups.get("hi") else f"{groups['lo']}-{groups['hi']}"
        return f"PAPR PDF sweep (MCS {span})"
    return kind


DIR_STANDARD_RE = re.compile(r"\(WiFi(\d)\)", re.I)


def standard_from_path(path):
    """Infer the standard from a directory like '802.11AC (WiFi5)'."""
    match = DIR_STANDARD_RE.search(path.replace("\\", "/"))
    return f"WiFi{match.group(1)}" if match else None


def index_figures():
    """Walk Figures/WiFi and return the figure indexes.

    Returns (by_combo, by_sweep, unmatched) where
      by_combo:  (standard, mcs, bw) -> [figure dicts]
      by_sweep:  (standard, mcs)     -> [figure dicts]   multi-MCS comparisons
      unmatched: repo paths no pattern recognised
    """
    by_combo = {}
    by_sweep = {}
    unmatched = []

    if not os.path.exists(FIGURE_ROOT):
        return by_combo, by_sweep, unmatched

    for root, _, files in os.walk(FIGURE_ROOT):
        for file in sorted(files):
            if not file.lower().endswith(FIGURE_EXTENSIONS) or file.startswith("."):
                continue
            stem = os.path.splitext(file)[0]
            repo_path = os.path.join(root, file).replace("\\", "/")

            for pattern, kind in FIGURE_PATTERNS:
                match = pattern.match(stem)
                if not match:
                    continue
                groups = match.groupdict()
                standard = STANDARD_BY_PREFIX.get(groups["prefix"].lower())
                if standard is None:
                    unmatched.append(repo_path)
                    break

                if kind == "STAT":
                    kind = STAT_LABELS[groups["stat"].lower()]

                entry = {"name": describe_figure(kind, groups), "path": repo_path, "kind": kind}

                if kind == "PAPR PDF sweep":
                    lo = int(groups["lo"])
                    hi = int(groups["hi"]) if groups.get("hi") else lo
                    for mcs in range(lo, hi + 1):
                        by_sweep.setdefault((standard, str(mcs)), []).append(entry)
                else:
                    by_combo.setdefault((standard, groups["mcs"], groups["bw"]), []).append(entry)
                break
            else:
                unmatched.append(repo_path)

    return by_combo, by_sweep, unmatched


def figures_for(by_combo, by_sweep, standard, mcs, bw):
    """Figures for one (standard, MCS, bandwidth), ordered for display."""
    combined = list(by_combo.get((standard, str(mcs), str(bw)), []))
    combined += by_sweep.get((standard, str(mcs)), [])
    order = {kind: i for i, kind in enumerate(KIND_ORDER)}
    combined.sort(key=lambda f: (order.get(f["kind"], len(KIND_ORDER)), f["name"]))
    return [{"name": f["name"], "path": f["path"]} for f in combined]


CONTRIB_ROOT = os.path.join("Signals", "Contributed")
SIDECAR_SUFFIX = ".contribution.json"


def index_contributed(root=CONTRIB_ROOT):
    """Catalog entries for signals accepted through the contribution portal.

    Contributed metadata cannot be inferred from a file path the way the
    curated tree's is, so scripts/ingest_submission.py writes a sidecar next
    to the waveform and this reads it back. A sidecar whose waveform is
    missing is skipped rather than published as a dead download link.
    """
    entries = []
    if not os.path.isdir(root):
        return entries

    for dirpath, _dirnames, filenames in os.walk(root):
        for filename in sorted(filenames):
            if not filename.endswith(SIDECAR_SUFFIX):
                continue
            sidecar = os.path.join(dirpath, filename)
            try:
                with open(sidecar, encoding="utf-8") as handle:
                    entry = json.load(handle)["entry"]
            except (OSError, ValueError, KeyError) as exc:
                print(f"Skipping malformed sidecar {sidecar}: {exc}")
                continue

            data_file = entry.get("data_file", "")
            if not data_file or not os.path.isfile(data_file):
                print(f"Skipping {sidecar}: data file {data_file!r} is not present.")
                continue
            entries.append(entry)

    return entries


def build_manifest():
    manifest = []
    os.makedirs("docs", exist_ok=True)

    by_combo, by_sweep, unmatched = index_figures()
    total_figs = sum(len(v) for v in by_combo.values()) + sum(len(v) for v in by_sweep.values())
    print(f"Indexed {total_figs} WiFi figure references across "
          f"{len(by_combo)} MCS/BW combinations.")
    # Anything the patterns did not recognise is still published, grouped by the
    # standard its directory names, rather than being dropped. A figure whose
    # filename drifts from the convention then shows up somewhere obvious
    # instead of disappearing without trace.
    unclassified = {}
    for path in unmatched:
        standard = standard_from_path(os.path.dirname(path))
        if standard is None:
            print(f"WARNING: cannot infer a standard for {path}; it will not be published. "
                  f"Place it under Figures/WiFi/<...(WiFiN)>/ to have it picked up.")
            continue
        unclassified.setdefault(standard, []).append(
            {"name": os.path.splitext(os.path.basename(path))[0], "path": path})

    if unmatched:
        print(f"NOTE: {len(unmatched)} figure(s) matched no naming pattern; "
              f"{sum(len(v) for v in unclassified.values())} published under "
              f"'Other figures' entries:")
        for path in unmatched[:20]:
            print(f"  - {path}")
        if len(unmatched) > 20:
            print(f"  ... and {len(unmatched) - 20} more")

    claimed_combos = set()   # (standard, mcs, bw) already covered by an entry
    real_keys = set()        # (standard, mcs, bw, mem) backed by a real signal
    alias_pending = []

    # -------------------------------------------------------------
    # 1. Multi-Carrier (MC) Scanning
    # -------------------------------------------------------------
    mc_dir = os.path.join("Signals", "Multi Carrier")
    if not os.path.exists(mc_dir):
        mc_dir = os.path.join("Signals", "Multi Carrier/WiFi")

    if os.path.exists(mc_dir):
        for root, _, files in os.walk(mc_dir):
            for file in sorted(files):
                if not file.endswith((".bin", ".csv")) or file.startswith("."):
                    continue
                repo_path = os.path.join(root, file).replace("\\", "/")
                # GI is optional: Wi-Fi 4 filenames carry it, later ones do not.
                match = re.search(
                    r"(wifi\d+)_mcs=(\d+)_bw=(\d+)(?:_GI=[A-Za-z]+)?_osf=(\d+)_(\d+MB)\.bin$",
                    file, re.I)
                if not match:
                    continue

                prefix, mcs, bw, osf, mem = match.groups()
                prefix_lower = prefix.lower()
                mcs_int, bw_int = int(mcs), int(bw)
                mem_label = mem.replace("MB", " MB")

                # Was "WiFi4 if wifi4 else WiFi6", which labelled every Wi-Fi 5
                # signal as Wi-Fi 6 and had no mapping for Wi-Fi 7 at all.
                std_label = STANDARD_BY_PREFIX.get(prefix_lower)
                if std_label is None:
                    print(f"WARNING: unknown standard prefix '{prefix}' in {repo_path}; skipping.")
                    continue

                papr, mean_packet_papr = calculate_papr(repo_path)
                papr_str = f"{papr} dB" if papr is not None else "N/A"
                mean_packet_papr_str = (
                    f"{mean_packet_papr} dB" if mean_packet_papr is not None else "N/A"
                )

                figures = figures_for(by_combo, by_sweep, std_label, mcs, bw)
                claimed_combos.add((std_label, mcs, bw))
                real_keys.add((std_label, mcs, bw, mem))

                manifest.append({
                    "id": f"mc-{prefix_lower}-{mcs}-{bw}-{mem}",
                    "signalClass": "MC",
                    "signalFamily": "WiFi",
                    "standard": std_label,
                    "mcs": mcs,
                    "bandwidth": f"{bw} MHz",
                    "memoryLength": mem_label,
                    "oversampling": f"{osf}x",
                    "papr": papr_str,
                    "meanPacketPapr": mean_packet_papr_str,
                    "data_file": repo_path,
                    "name": f"{std_label} MCS{mcs} {bw}MHz {mem_label}",
                    "figures": figures,
                    "isAlias": False
                })

                for rule in ALIAS_CONFIGS:
                    if (prefix_lower == rule["source_prefix"]
                            and mcs_int <= rule["max_mcs"]
                            and bw_int in rule["allowed_bw"]):
                        alias_pending.append((rule, std_label, mcs, bw, mem, mem_label,
                                              osf, papr_str, mean_packet_papr_str, repo_path))

    # Aliases are emitted only where no measured signal already covers that
    # combination, so real data always wins over a shared-waveform alias.
    for (rule, std_label, mcs, bw, mem, mem_label, osf,
         papr_str, mean_packet_papr_str, repo_path) in alias_pending:
        alias_std = rule["alias_standard"]
        if (alias_std, mcs, bw, mem) in real_keys:
            print(f"Skipping {alias_std} alias for MCS{mcs} {bw}MHz {mem_label}: "
                  f"a measured {alias_std} signal exists.")
            continue
        figures = figures_for(by_combo, by_sweep, alias_std, mcs, bw)
        if not figures:
            figures = figures_for(by_combo, by_sweep, std_label, mcs, bw)
        claimed_combos.add((alias_std, mcs, bw))
        manifest.append({
            "id": f"mc-{alias_std.lower()}-alias-{mcs}-{bw}-{mem}",
            "signalClass": "MC",
            "signalFamily": "WiFi",
            "standard": alias_std,
            "mcs": mcs,
            "bandwidth": f"{bw} MHz",
            "memoryLength": mem_label,
            "oversampling": f"{osf}x",
            "papr": papr_str,
            "meanPacketPapr": mean_packet_papr_str,
            "data_file": repo_path,
            "name": f"{alias_std} (via {std_label}) MCS{mcs} {bw}MHz {mem_label}",
            "figures": figures,
            "isAlias": True,
            "aliasNote": rule["note"]
        })

    # -------------------------------------------------------------
    # 1b. Figure-only combinations
    # -------------------------------------------------------------
    # A PAPR PDF/CCDF has no waveform file behind it, so without this the
    # analysis figures would never reach the site at all. app.js already
    # renders "No signal file published yet" when signalFiles is empty.
    figure_only = 0
    for (standard, mcs, bw) in sorted(by_combo.keys()):
        if (standard, mcs, bw) in claimed_combos:
            continue
        figures = figures_for(by_combo, by_sweep, standard, mcs, bw)
        if not figures:
            continue
        figure_only += 1
        manifest.append({
            "id": f"mc-{standard.lower()}-figs-{mcs}-{bw}",
            "signalClass": "MC",
            "signalFamily": "WiFi",
            "standard": standard,
            "mcs": mcs,
            "bandwidth": f"{bw} MHz",
            "memoryLength": "Figures only",
            "oversampling": "4x",
            "papr": "N/A",
            "meanPacketPapr": "N/A",
            "name": f"{standard} MCS{mcs} {bw}MHz (analysis figures)",
            "figures": figures,
            "isAlias": False
        })
    print(f"Added {figure_only} figure-only MC entries (no waveform published yet).")

    # A multi-MCS sweep plot is attached to each MCS it covers, but if none of
    # those MCS values has any other figure there is nothing to attach it to.
    # Give those their own bandwidth-agnostic entry so the plot is still
    # reachable.
    covered_mcs = {(standard, mcs) for (standard, mcs, _) in claimed_combos}
    sweep_only = 0
    for (standard, mcs) in sorted(by_sweep.keys()):
        if (standard, mcs) in covered_mcs:
            continue
        sweep_only += 1
        manifest.append({
            "id": f"mc-{standard.lower()}-sweep-{mcs}",
            "signalClass": "MC",
            "signalFamily": "WiFi",
            "standard": standard,
            "mcs": mcs,
            "bandwidth": "All MHz",
            "memoryLength": "Figures only",
            "oversampling": "4x",
            "papr": "N/A",
            "meanPacketPapr": "N/A",
            "name": f"{standard} MCS{mcs} (PAPR sweep figures)",
            "figures": [{"name": f["name"], "path": f["path"]}
                        for f in by_sweep[(standard, mcs)]],
            "isAlias": False
        })
    print(f"Added {sweep_only} sweep-only MC entries.")

    for standard, figures in sorted(unclassified.items()):
        manifest.append({
            "id": f"mc-{standard.lower()}-other",
            "signalClass": "MC",
            "signalFamily": "WiFi",
            "standard": standard,
            "mcs": "n/a",
            "bandwidth": "All MHz",
            "memoryLength": "Figures only",
            "oversampling": "4x",
            "papr": "N/A",
            "meanPacketPapr": "N/A",
            "name": f"{standard} other figures",
            "figures": sorted(figures, key=lambda f: f["name"]),
            "isAlias": False
        })
    if unclassified:
        print(f"Added {len(unclassified)} 'other figures' entries for unrecognised filenames.")

    # -------------------------------------------------------------
    # 2. Single-Carrier (SC) Scanning matching hierarchy:
    #    Signals/Single Carrier/<symbols>/<QAM>/<alpha>/<filename>
    # -------------------------------------------------------------
    sc_dir = os.path.join("Signals", "Single Carrier")
    if os.path.exists(sc_dir):
        for root, _, files in os.walk(sc_dir):
            for file in files:
                if file.endswith((".bin", ".csv", ".txt")) and not file.startswith("."):
                    # Every waveform directory ships a "<name>_properties.csv"
                    # and a "summary.txt" describing the sweep that produced it.
                    # They match the extension filter but hold no samples, and
                    # cataloguing them created 375 entries that render as
                    # signals with no PAPR and cannot be converted into a
                    # generator waveform. The extensions stay eligible so a
                    # genuine CSV waveform can still be added later.
                    if file.endswith("_properties.csv") or file == "summary.txt":
                        continue
                    repo_path = os.path.join(root, file).replace("\\", "/")
                    norm_root = root.replace("\\", "/")

                    # 1. Symbol Count (e.g., "100 symbols", "100k symbols")
                    sym_match = re.search(r"(\d+[kM]?)\s*symbols", norm_root, re.I)
                    sym_label = sym_match.group(1) + " symbols" if sym_match else "100k symbols"

                    # 2. QAM Order (e.g., "1024QAM", "16QAM", "64QAM")
                    qam_match = re.search(r"(\d+)QAM|(\d+)-QAM", norm_root + "/" + file, re.I)
                    if qam_match:
                        qam_val = qam_match.group(1) or qam_match.group(2)
                        mod_label = f"{qam_val}-QAM"
                    else:
                        mod_label = "64-QAM"
                        qam_val = "64"

                    # 3. Roll-off Factor (e.g., "alpha005" -> "0.05", "alpha025" -> "0.25")
                    alpha_match = re.search(r"alpha(\d+)", norm_root, re.I)
                    if alpha_match:
                        rolloff_str = parse_alpha(alpha_match.group(0))
                    else:
                        # Fallback regex if named differently
                        fallback_match = re.search(r"rolloff_(\d+)p(\d+)|0p(\d+)|0\.(\d+)", file, re.I)
                        if fallback_match:
                            r_groups = [g for g in fallback_match.groups() if g is not None]
                            rolloff_str = f"{r_groups[0]}.{r_groups[1]}" if len(r_groups) == 2 else f"0.{r_groups[0]}"
                        else:
                            rolloff_str = "0.25"

                    # 4. PAPR Calculation
                    papr, mean_packet_papr = calculate_papr(repo_path)
                    papr_str = f"{papr} dB" if papr is not None else "N/A"
                    mean_packet_papr_str = (
                        f"{mean_packet_papr} dB" if mean_packet_papr is not None else "N/A"
                    )

                    # 5. Link Figures from Figures/ directory matching roll-off
                    figures = []
                    formatted_alpha_dir = f"rolloff_{rolloff_str.replace('.', 'p')}"
                    fig_search_dir = os.path.join("Figures", formatted_alpha_dir)
                    if os.path.exists(fig_search_dir):
                        for fig_root, _, fig_files in os.walk(fig_search_dir):
                            if qam_val in fig_root or mod_label in fig_root:
                                for f_img in sorted(fig_files):
                                    if f_img.endswith((".png", ".jpg", ".svg")):
                                        figures.append({
                                            "name": format_fig_name(f_img),
                                            "path": os.path.join(fig_root, f_img).replace("\\", "/")
                                        })

                    manifest.append({
                        "id": f"sc-{sym_label.replace(' ', '')}-{qam_val}-a{rolloff_str.replace('.', '')}-{file}",
                        "signalClass": "SC",
                        "signalFamily": "QAM",
                        "modulation": mod_label,
                        "rolloff": rolloff_str,
                        "symbols": sym_label,
                        "filterType": "RRC",
                        "oversampling": f"{read_sc_oversampling(repo_path)}x",
                        "papr": papr_str,
                        "meanPacketPapr": mean_packet_papr_str,
                        "data_file": repo_path,
                        "name": f"{mod_label} {sym_label} (Roll-off {rolloff_str})",
                        "figures": figures
                    })

    contributed = index_contributed()
    if contributed:
        print(f"Adding {len(contributed)} contributed signal(s) from {CONTRIB_ROOT}.")
        manifest.extend(contributed)

    with open(MANIFEST_FILE, "w") as f:
        json.dump(manifest, f, indent=2)

    print(f"Manifest generated successfully at {MANIFEST_FILE} with {len(manifest)} total items.")


if __name__ == "__main__":
    build_manifest()
