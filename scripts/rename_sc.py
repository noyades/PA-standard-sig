# scripts/rename_sc.py
"""One-off migration of single-carrier filenames to the self-describing form.

Old: Signals/Single Carrier/1M symbols/4096QAM/alpha045/4096-QAM_PAPR_average.bin
New: Signals/Single Carrier/1M symbols/4096QAM/alpha045/sc_4096qam_rrc_alpha=0.45_sym=1M_osf=4_papr=avg.bin

The directory tree is kept; only file names change. Every metadata field that
used to live in the path is now also in the name, so a downloaded file keeps
its description. Sidecars (_properties.csv, _properties.mat, _constellation.png)
follow their waveform's stem. summary.txt is per directory and stays as it is.

Renames go through `git mv` so history follows the files. An old->new table is
written to Signals/Single Carrier/sc_rename_map.csv so saved raw links and the
Zenodo-archived paths can still be resolved.

Usage: python scripts/rename_sc.py [--apply]   (dry run without --apply)
"""
import csv
import os
import re
import subprocess
import sys

SC_ROOT = os.path.join("Signals", "Single Carrier")
MAP_FILE = os.path.join(SC_ROOT, "sc_rename_map.csv")

DIR_RE = re.compile(r"(?P<sym>\d+[kM]?) symbols/(?P<order>\d+)QAM/alpha(?P<alpha>\d+)$", re.I)
OLD_RE = re.compile(
    r"^(?P<order>\d+)-QAM_PAPR_(?P<variant>average|max)"
    r"(?P<suffix>_properties\.csv|_properties\.mat|_constellation\.png|\.bin)$", re.I)
VARIANT = {"average": "avg", "max": "max"}


def read_osf(properties_csv):
    with open(properties_csv, encoding="utf-8", errors="replace") as handle:
        for line in handle:
            key, _, value = line.partition(",")
            if key.strip().lower() == "oversampling factor":
                return int(float(value.strip()))
    raise ValueError(f"no oversampling factor in {properties_csv}")


def plan():
    moves = []
    for root, _, files in os.walk(SC_ROOT):
        norm_root = root.replace("\\", "/")
        dir_match = DIR_RE.search(norm_root)
        for file in sorted(files):
            match = OLD_RE.match(file)
            if not match:
                continue
            if not dir_match:
                raise ValueError(f"{norm_root}/{file}: directory does not match the SC layout")
            if match["order"] != dir_match["order"]:
                raise ValueError(f"{norm_root}/{file}: modulation disagrees with its directory")
            stem_old = f"{match['order']}-QAM_PAPR_{match['variant']}"
            osf = read_osf(os.path.join(root, stem_old + "_properties.csv"))
            alpha = f"0.{dir_match['alpha'].lstrip('0').rjust(2, '0')}"
            stem_new = (f"sc_{match['order']}qam_rrc_alpha={alpha}_sym={dir_match['sym']}"
                        f"_osf={osf}_papr={VARIANT[match['variant'].lower()]}")
            moves.append((f"{norm_root}/{file}", f"{norm_root}/{stem_new}{match['suffix']}"))
    return moves


def main():
    apply = "--apply" in sys.argv
    moves = plan()
    targets = [new for _, new in moves]
    if len(set(targets)) != len(targets):
        raise SystemExit("Two files would be renamed to the same name; aborting.")
    for old, new in moves[:8]:
        print(f"{old}\n  -> {os.path.basename(new)}")
    print(f"... {len(moves)} renames planned.")
    if not apply:
        print("Dry run; pass --apply to rename.")
        return

    for old, new in moves:
        subprocess.run(["git", "mv", old, new], check=True)
    with open(MAP_FILE, "w", newline="", encoding="utf-8") as handle:
        writer = csv.writer(handle)
        writer.writerow(["old_path", "new_path"])
        writer.writerows(moves)
    print(f"Renamed {len(moves)} files; mapping written to {MAP_FILE}.")


if __name__ == "__main__":
    main()
