# scripts/build_manifest.py
import os
import json
import re
import numpy as np

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

def calculate_papr(file_path, frame_size=1000):
    """Calculates Max and Mean PAPR (in dB) for 32-bit float I/Q binary or text signals."""
    try:
        if file_path.endswith('.bin'):
            data = np.fromfile(file_path, dtype=np.float32)
            if len(data) < 2:
                return None, None
            i_samples = data[0::2]
            q_samples = data[1::2]
            power = i_samples**2 + q_samples**2
        else:
            raw_data = np.loadtxt(file_path, delimiter=',')
            if raw_data.ndim == 2 and raw_data.shape[1] >= 2:
                power = raw_data[:, 0]**2 + raw_data[:, 1]**2
            else:
                return None, None

        mean_power = np.mean(power)
        if mean_power == 0:
            return None, None

        max_power = np.max(power)
        max_papr_db = 10 * np.log10(max_power / mean_power)

        num_frames = len(power) // frame_size
        if num_frames > 0:
            frames = power[:num_frames * frame_size].reshape(num_frames, frame_size)
            frame_means = np.mean(frames, axis=1)
            frame_peaks = np.max(frames, axis=1)
            valid_mask = frame_means > 0
            if np.any(valid_mask):
                mean_papr_db = np.mean(10 * np.log10(frame_peaks[valid_mask] / frame_means[valid_mask]))
            else:
                mean_papr_db = max_papr_db
        else:
            mean_papr_db = max_papr_db

        return round(float(max_papr_db), 2), round(float(mean_papr_db), 2)
    except Exception as e:
        return None, None

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

def parse_alpha(alpha_str):
    """Converts folder string like 'alpha005' or 'alpha025' to decimal float string '0.05' or '0.25'."""
    clean = alpha_str.lower().replace("alpha", "").strip()
    if len(clean) == 3 and clean.startswith("0"):
        return f"0.{clean[1:]}"
    elif len(clean) == 2:
        return f"0.{clean}"
    return f"0.{clean}"

def build_manifest():
    manifest = []
    os.makedirs("docs", exist_ok=True)

    # -------------------------------------------------------------
    # 1. Multi-Carrier (MC) Scanning
    # -------------------------------------------------------------
    mc_dir = os.path.join("Signals", "Multi Carrier")
    if not os.path.exists(mc_dir):
        mc_dir = os.path.join("Signals", "Multi Carrier/WiFi")

    if os.path.exists(mc_dir):
        for root, _, files in os.walk(mc_dir):
            for file in files:
                if file.endswith((".bin", ".csv")) and not file.startswith("."):
                    repo_path = os.path.join(root, file).replace("\\", "/")
                    match = re.search(r"(wifi\d+)_mcs=(\d+)_bw=(\d+)_osf=(\d+)_(4MB|8MB)\.bin$", file, re.I)
                    if match:
                        prefix, mcs, bw, osf, mem = match.groups()
                        prefix_lower = prefix.lower()
                        mcs_int = int(mcs)
                        bw_int = int(bw)
                        mem_label = mem.replace("MB", " MB")
                        std_label = "WiFi4" if prefix_lower == "wifi4" else "WiFi6"

                        max_papr, mean_papr = calculate_papr(repo_path)
                        max_papr_str = f"{max_papr} dB" if max_papr is not None else "N/A"
                        mean_papr_str = f"{mean_papr} dB" if mean_papr is not None else "N/A"

                        plot_path = f"Figures/WiFi/802.11N (WiFi4)/wifi4_Constellation_mcs={mcs}_bw={bw}_osf={osf}_{mem}.png"
                        figures = []
                        if os.path.exists(plot_path):
                            figures.append({"name": "Constellation", "path": plot_path})

                        # Primary Entry
                        manifest.append({
                            "id": f"mc-{prefix_lower}-{mcs}-{bw}-{mem}",
                            "signalClass": "MC",
                            "signalFamily": "WiFi",
                            "standard": std_label,
                            "mcs": mcs,
                            "bandwidth": f"{bw} MHz",
                            "memoryLength": mem_label,
                            "oversampling": f"{osf}x",
                            "maxPapr": max_papr_str,
                            "meanPapr": mean_papr_str,
                            "data_file": repo_path,
                            "name": f"{std_label} MCS{mcs} {bw}MHz {mem_label}",
                            "figures": figures,
                            "isAlias": False
                        })

                        # Aliased Entries (WiFi 5 / WiFi 7)
                        for rule in ALIAS_CONFIGS:
                            if prefix_lower == rule["source_prefix"] and mcs_int <= rule["max_mcs"] and bw_int in rule["allowed_bw"]:
                                manifest.append({
                                    "id": f"mc-{rule['alias_standard'].lower()}-alias-{mcs}-{bw}-{mem}",
                                    "signalClass": "MC",
                                    "signalFamily": "WiFi",
                                    "standard": rule["alias_standard"],
                                    "mcs": mcs,
                                    "bandwidth": f"{bw} MHz",
                                    "memoryLength": mem_label,
                                    "oversampling": f"{osf}x",
                                    "maxPapr": max_papr_str,
                                    "meanPapr": mean_papr_str,
                                    "data_file": repo_path,
                                    "name": f"{rule['alias_standard']} (via {std_label}) MCS{mcs} {bw}MHz {mem_label}",
                                    "figures": figures,
                                    "isAlias": True,
                                    "aliasNote": rule["note"]
                                })

    # -------------------------------------------------------------
    # 2. Single-Carrier (SC) Scanning matching hierarchy:
    #    Signals/Single Carrier/<symbols>/<QAM>/<alpha>/<filename>
    # -------------------------------------------------------------
    sc_dir = os.path.join("Signals", "Single Carrier")
    if os.path.exists(sc_dir):
        for root, _, files in os.walk(sc_dir):
            for file in files:
                if file.endswith((".bin", ".csv", ".txt")) and not file.startswith("."):
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
                    max_papr, mean_papr = calculate_papr(repo_path)
                    max_papr_str = f"{max_papr} dB" if max_papr is not None else "N/A"
                    mean_papr_str = f"{mean_papr} dB" if mean_papr is not None else "N/A"

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
                        "maxPapr": max_papr_str,
                        "meanPapr": mean_papr_str,
                        "data_file": repo_path,
                        "name": f"{mod_label} {sym_label} (Roll-off {rolloff_str})",
                        "figures": figures
                    })

    with open(MANIFEST_FILE, "w") as f:
        json.dump(manifest, f, indent=2)

    print(f"Manifest generated successfully at {MANIFEST_FILE} with {len(manifest)} total items.")

if __name__ == "__main__":
    build_manifest()