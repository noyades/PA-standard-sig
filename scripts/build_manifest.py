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
        
def build_manifest():
    manifest = []
    os.makedirs("docs", exist_ok=True)

    mc_dir = os.path.join("Signals", "Multi Carrier")
    if os.path.exists(mc_dir):
        for root, _, files in os.walk(mc_dir):
            for file in files:
                if file.endswith((".bin", ".csv", ".mat")):
                    repo_path = os.path.join(root, file).replace("\\", "/")
                    
                    # Regex matching for wifi4, wifi6, etc.
                    match = re.search(r"(wifi\d+)_mcs=(\d+)_bw=(\d+)_osf=(\d+)_(4MB|8MB)\.bin$", file, re.I)
                    if match:
                        prefix, mcs, bw, osf, mem = match.groups()
                        prefix_lower = prefix.lower()
                        mcs_int = int(mcs)
                        bw_int = int(bw)
                        mem_label = mem.replace("MB", " MB")
                        
                        std_label = "WiFi4" if prefix_lower == "wifi4" else "WiFi6"
                        
                        plot_path = f"Figures/WiFi/{std_label}/constellation_mcs={mcs}_bw={bw}_osf={osf}_{mem}.png"
                        figures = []
                        if os.path.exists(plot_path):
                            figures.append({"name": "Constellation", "path": plot_path})

                        # 1. Primary Entry
                        manifest.append({
                            "id": f"mc-{prefix_lower}-{mcs}-{bw}-{mem}",
                            "signalClass": "MC",
                            "signalFamily": "WiFi",
                            "standard": std_label,
                            "mcs": mcs,
                            "bandwidth": f"{bw} MHz",
                            "memoryLength": mem_label,
                            "oversampling": f"{osf}x",
                            "data_file": repo_path,
                            "name": f"{std_label} MCS{mcs} {bw}MHz {mem_label}",
                            "figures": figures,
                            "isAlias": False
                        })

                        # 2. Check Aliasing Rules
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
                                    "data_file": repo_path, # Alias pointer
                                    "name": f"{rule['alias_standard']} (via {std_label}) MCS{mcs} {bw}MHz {mem_label}",
                                    "figures": figures,
                                    "isAlias": True,
                                    "aliasNote": rule["note"]
                                })

    with open(MANIFEST_FILE, "w") as f:
        json.dump(manifest, f, indent=2)
    
    print(f"Manifest written to {MANIFEST_FILE} with {len(manifest)} items.")

if __name__ == "__main__":
    build_manifest()