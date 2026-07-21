# scripts/build_manifest.py
import os
import json
import re

MANIFEST_FILE = os.path.join("docs", "manifest.json")

def build_manifest():
    manifest = []
    os.makedirs("docs", exist_ok=True)

    # 1. Index Multi-Carrier Signals (.bin files)
    mc_dir = os.path.join("Signals", "Multi Carrier")
    if os.path.exists(mc_dir):
        for root, _, files in os.walk(mc_dir):
            for file in files:
                if file.endswith(".bin"):
                    repo_path = os.path.join(root, file).replace("\\", "/")
                    
                    # Match pattern like: wifi4_mcs=0_bw=20_osf=4_4MB.bin
                    match = re.search(r"wifi4_mcs=(\d+)_bw=(\d+)_osf=(\d+)_(4MB|8MB)\.bin$", file, re.I)
                    if match:
                        mcs, bw, osf, mem = match.groups()
                        mem_label = mem.replace("MB", " MB")
                        
                        # Locate matching constellation plot in Figures/
                        plot_path = f"Figures/WiFi/802.11N (WiFi4)/wifi4_Constellation_mcs={mcs}_bw={bw}_osf={osf}_{mem}.png"
                        figures = []
                        if os.path.exists(plot_path):
                            figures.append({"name": "Constellation", "path": plot_path})

                        manifest.append({
                            "id": f"mc-{mcs}-{bw}-{mem}",
                            "signalClass": "MC",
                            "signalFamily": "WiFi",
                            "standard": "WiFi4",
                            "mcs": mcs,
                            "bandwidth": f"{bw} MHz",
                            "memoryLength": mem_label,
                            "oversampling": f"{osf}x",
                            "data_file": repo_path,
                            "name": f"WiFi4 MCS{mcs} {bw}MHz {mem_label}",
                            "figures": figures
                        })

    # 2. Write manifest into docs/
    with open(MANIFEST_FILE, "w") as f:
        json.dump(manifest, f, indent=2)
    
    print(f"Manifest written to {MANIFEST_FILE} with {len(manifest)} items.")

if __name__ == "__main__":
    build_manifest()