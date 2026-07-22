# scripts/build_manifest.py
import os
import json
import re

MANIFEST_FILE = os.path.join("docs", "manifest.json")

# Define aliasing rules to avoid redundant physical files
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
    """
    Reads 32-bit float I/Q binary file and returns (max_papr_db, mean_papr_db).
    """
    try:
        # Read interleaved 32-bit floats (I, Q, I, Q, ...)
        data = np.fromfile(file_path, dtype=np.float32)
        if len(data) < 2:
            return None, None
        
        i_samples = data[0::2]
        q_samples = data[1::2]
        
        # Instantaneous power
        power = i_samples**2 + q_samples**2
        
        mean_power = np.mean(power)
        if mean_power == 0:
            return None, None
            
        # Overall Peak-to-Average Power Ratio
        max_power = np.max(power)
        max_papr_db = 10 * np.log10(max_power / mean_power)
        
        # Mean PAPR across frame blocks
        num_frames = len(power) // frame_size
        if num_frames > 0:
            frames = power[:num_frames * frame_size].reshape(num_frames, frame_size)
            frame_means = np.mean(frames, axis=1)
            frame_peaks = np.max(frames, axis=1)
            # Avoid divide by zero
            valid_mask = frame_means > 0
            if np.any(valid_mask):
                frame_paprs = 10 * np.log10(frame_peaks[valid_mask] / frame_means[valid_mask])
                mean_papr_db = np.mean(frame_paprs)
            else:
                mean_papr_db = max_papr_db
        else:
            mean_papr_db = max_papr_db

        return round(float(max_papr_db), 2), round(float(mean_papr_db), 2)
    except Exception as e:
        print(f"Error calculating PAPR for {file_path}: {e}")
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
        
def build_manifest():
    manifest = []
    os.makedirs("docs", exist_ok=True)

    # -------------------------------------------------------------
    # 1. Multi-Carrier (MC) Signals & Aliasing Rules
    # -------------------------------------------------------------
    mc_dir = os.path.join("Signals", "Multi Carrier")
    if os.path.exists(mc_dir):
        for root, _, files in os.walk(mc_dir):
            for file in files:
                if file.endswith((".bin", ".csv")):
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
                            "maxPapr": f"{max_papr} dB" if max_papr is not None else "N/A",
                            "meanPapr": f"{mean_papr} dB" if mean_papr is not None else "N/A",
                            "data_file": repo_path,
                            "name": f"{std_label} MCS{mcs} {bw}MHz {mem_label}",
                            "figures": figures,
                            "isAlias": False
                        })

                        # Process Aliasing Rules (WiFi 5 & WiFi 7)
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
                                    "maxPapr": f"{max_papr} dB" if max_papr is not None else "N/A",
                                    "meanPapr": f"{mean_papr} dB" if mean_papr is not None else "N/A",
                                    "data_file": repo_path,
                                    "name": f"{rule['alias_standard']} (via {std_label}) MCS{mcs} {bw}MHz {mem_label}",
                                    "figures": figures,
                                    "isAlias": True,
                                    "aliasNote": rule["note"]
                                })

    # -------------------------------------------------------------
    # 2. Single-Carrier (SC) Signals & Figures Scanning
    # -------------------------------------------------------------
    fig_dir = "Figures"
    if os.path.exists(fig_dir):
        for root, _, files in os.walk(fig_dir):
            image_files = [f for f in files if f.endswith((".png", ".jpg", ".jpeg", ".svg"))]
            if image_files:
                norm_root = root.replace("\\", "/")
                
                rolloff_match = re.search(r"rolloff_(\d+)p(\d+)", norm_root, re.I)
                qam_match = re.search(r"(\d+)QAM|(\d+)-QAM", norm_root, re.I)

                if rolloff_match and qam_match:
                    rolloff_str = f"{rolloff_match.group(1)}.{rolloff_match.group(2)}"
                    qam_val = qam_match.group(1) or qam_match.group(2)
                    mod_label = f"{qam_val}-QAM"

                    figures = []
                    for img in sorted(image_files):
                        fig_path = os.path.join(norm_root, img).replace("\\", "/")
                        figures.append({
                            "name": format_fig_name(img),
                            "path": fig_path
                        })

                    # Match SC signal data file in Signals/Single Carrier/
                    data_file = None
                    max_papr_str = "N/A"
                    mean_papr_str = "N/A"
                    
                    sc_data_dir = os.path.join("Signals", "Single Carrier")
                    if os.path.exists(sc_data_dir):
                        for sc_root, _, sc_files in os.walk(sc_data_dir):
                            for sc_file in sc_files:
                                if qam_val in sc_file and (f"rolloff_{rolloff_match.group(1)}p{rolloff_match.group(2)}" in sc_file or f"0p{rolloff_match.group(2)}" in sc_file or f"0.{rolloff_match.group(2)}" in sc_file):
                                    data_file = os.path.join(sc_root, sc_file).replace("\\", "/")
                                    max_papr, mean_papr = calculate_papr(data_file)
                                    if max_papr is not None:
                                        max_papr_str = f"{max_papr} dB"
                                        mean_papr_str = f"{mean_papr} dB"
                                    break

                    manifest.append({
                        "id": f"sc-{rolloff_str}-{qam_val}",
                        "signalClass": "SC",
                        "signalFamily": "QAM",
                        "modulation": mod_label,
                        "rolloff": rolloff_str,
                        "filterType": "RRC",
                        "maxPapr": max_papr_str,
                        "meanPapr": mean_papr_str,
                        "data_file": data_file,
                        "name": f"{mod_label} (Roll-off {rolloff_str})",
                        "figures": figures
                    })

    # Save manifest output
    with open(MANIFEST_FILE, "w") as f:
        json.dump(manifest, f, indent=2)

    print(f"Manifest generated successfully at {MANIFEST_FILE} with {len(manifest)} items.")

if __name__ == "__main__":
    build_manifest()