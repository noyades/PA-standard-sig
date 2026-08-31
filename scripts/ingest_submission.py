# scripts/ingest_submission.py
"""Validate and ingest a signal contributed through docs/contribute.html.

A contributor fills in the form on the contribution page, which measures their
waveform in the browser and packages it with a submission.json describing it.
This is the receiving end: it re-reads the waveform with the library's own
estimator, checks the declared metadata against docs/contribution-schema.json,
compares what the browser reported against what the file actually contains, and
writes a sidecar the manifest builder can pick up.

Nothing here trusts the submission. The browser numbers are treated as a claim
to be checked, not as data to be copied.

Typical use, from the repository root:

    # look at a submission without touching the tree
    python scripts/ingest_submission.py incoming/submission.json \\
        --signal incoming/wifi6_mcs0_80mhz.bin

    # accept it: copy the waveform in and write its sidecar
    python scripts/ingest_submission.py incoming/submission.json \\
        --signal incoming/wifi6_mcs0_80mhz.bin --accept

Exit status is 0 when the submission is clean, 1 when it has errors.
"""

import argparse
import hashlib
import json
import os
import re
import shutil
import sys

import signal_analysis

SCHEMA_FILE = os.path.join("docs", "contribution-schema.json")
CONTRIB_ROOT = os.path.join("Signals", "Contributed")
SIDECAR_SUFFIX = ".contribution.json"

# How far the browser's measurement may sit from ours before it is worth
# reporting. The two implement the same estimator, so anything beyond rounding
# means the file that was measured is not the file that arrived.
PAPR_TOLERANCE_DB = 0.05


class Report:
    """Errors block acceptance; warnings are for a human to weigh."""

    def __init__(self):
        self.errors = []
        self.warnings = []
        self.notes = []

    def error(self, message):
        self.errors.append(message)

    def warn(self, message):
        self.warnings.append(message)

    def note(self, message):
        self.notes.append(message)

    def render(self):
        for note in self.notes:
            print(f"  {note}")
        for warning in self.warnings:
            print(f"  WARNING  {warning}")
        for err in self.errors:
            print(f"  ERROR    {err}")
        print()
        print(f"{len(self.errors)} error(s), {len(self.warnings)} warning(s)")
        return 1 if self.errors else 0


# ---------------------------------------------------------------------------
# Schema handling. The condition language matches docs/contribute.js: a
# condition is {"field": id, "in": [values]}, and absent means "always".
# ---------------------------------------------------------------------------

def load_schema(path=SCHEMA_FILE):
    with open(path, encoding="utf-8") as handle:
        return json.load(handle)


def condition_passes(condition, values):
    if not condition:
        return True
    return values.get(condition["field"]) in condition["in"]


def is_required(field, values):
    required = field.get("required")
    if required is True:
        return True
    if not required:
        return False
    return condition_passes(required, values)


def active_fields(schema, values):
    """The fields that apply, given the branch the contributor took."""
    for section in schema["sections"]:
        if not condition_passes(section.get("showWhen"), values):
            continue
        for field in section["fields"]:
            if condition_passes(field.get("showWhen"), values):
                yield section, field


def validate_metadata(schema, values, report):
    known = {field["id"] for section in schema["sections"] for field in section["fields"]}
    for key in values:
        if key not in known:
            report.warn(f"'{key}' is not a field in the schema and will be carried through unchecked.")

    active = {field["id"] for _section, field in active_fields(schema, values)}
    for key in values:
        if key in known and key not in active:
            report.warn(
                f"'{key}' was submitted but does not apply to this kind of signal, so it was not checked."
            )

    for _section, field in active_fields(schema, values):
        fid = field["id"]
        value = values.get(fid)
        empty = value is None or (isinstance(value, str) and not value.strip()) or value is False

        if is_required(field, values):
            if empty:
                report.error(f"{field['label']} ({fid}) is required but missing.")
                continue
        elif empty:
            continue

        if field.get("pattern") and not re.match(field["pattern"], str(value).strip()):
            report.error(
                f"{field['label']} ({fid}) does not match the expected format: {value!r}"
            )

        if field.get("type") == "number":
            try:
                number = float(value)
            except (TypeError, ValueError):
                report.error(f"{field['label']} ({fid}) is not a number: {value!r}")
                continue
            if "min" in field and number < field["min"]:
                report.error(f"{field['label']} ({fid}) is below the minimum of {field['min']}.")
            if "max" in field and number > field["max"]:
                report.error(f"{field['label']} ({fid}) is above the maximum of {field['max']}.")

        if field.get("type") == "select":
            allowed = {opt["value"] for opt in field["options"]}
            if str(value) not in allowed:
                report.error(
                    f"{field['label']} ({fid}) is {value!r}, which is not one of {sorted(allowed)}."
                )


# ---------------------------------------------------------------------------
# Waveform checks
# ---------------------------------------------------------------------------

def sha256_of(path):
    digest = hashlib.sha256()
    with open(path, "rb") as handle:
        for block in iter(lambda: handle.read(1024 * 1024), b""):
            digest.update(block)
    return digest.hexdigest()


def verify_signal(submission, signal_path, report):
    """Re-measure the waveform and hold the submission's claims up against it."""
    values = submission.get("metadata", {})
    claimed = submission.get("analysis") or {}
    declared_file = submission.get("file") or {}

    size = os.path.getsize(signal_path)
    if declared_file.get("sizeBytes") not in (None, size):
        report.warn(
            f"The submission describes a {declared_file['sizeBytes']}-byte file, "
            f"but this one is {size} bytes."
        )

    digest = sha256_of(signal_path)
    if declared_file.get("sha256") and declared_file["sha256"] != digest:
        report.error(
            "SHA-256 does not match the submission: this is not the file that was measured "
            f"(submitted {declared_file['sha256'][:16]}..., got {digest[:16]}...)."
        )

    try:
        measured = signal_analysis.describe(
            signal_path,
            sample_format=values.get("sampleFormat"),
            byte_order=values.get("byteOrder", "little"),
        )
    except Exception as exc:  # noqa: BLE001 - report rather than traceback
        report.error(f"Could not read the waveform: {exc}")
        return None, digest

    measured["sha256"] = digest
    measured["sizeBytes"] = size

    for key, label in (("paprDb", "PAPR"), ("meanPacketPaprDb", "mean packet PAPR")):
        if claimed.get(key) is None or measured.get(key) is None:
            continue
        delta = abs(float(claimed[key]) - measured[key])
        if delta > PAPR_TOLERANCE_DB:
            report.warn(
                f"The browser reported a {label} of {claimed[key]} dB; this file measures "
                f"{measured[key]} dB ({delta:.2f} dB apart)."
            )

    if claimed.get("sampleCount") not in (None, measured["sampleCount"]):
        report.warn(
            f"The browser counted {claimed['sampleCount']} complex samples, "
            f"this file holds {measured['sampleCount']}."
        )

    rate_mhz = values.get("sampleRateMHz")
    if rate_mhz:
        duration_s = measured["sampleCount"] / (float(rate_mhz) * 1e6)
        report.note(f"Duration at the declared {rate_mhz} MSa/s: {duration_s * 1e3:.3f} ms")

    bandwidth = values.get("bandwidthMHz")
    if rate_mhz and bandwidth and float(bandwidth) > float(rate_mhz):
        report.error(
            f"A {bandwidth} MHz occupied bandwidth cannot be carried at {rate_mhz} MSa/s."
        )

    report.note(
        f"Measured: PAPR {measured['paprDb']} dB"
        + (f", mean packet PAPR {measured['meanPacketPaprDb']} dB"
           if measured.get("meanPacketPaprDb") is not None else "")
        + f", {measured['packets']} packet(s), {measured['activeSamples']} signal samples "
        f"of {measured['sampleCount']}, RMS {measured['rms']}"
    )
    return measured, digest


# ---------------------------------------------------------------------------
# Catalog entry
# ---------------------------------------------------------------------------

def slugify(text):
    return re.sub(r"[^a-z0-9]+", "-", str(text).lower()).strip("-")


def entry_id(values):
    parts = ["contrib", values.get("signalClass", "sig"), values.get("signalFamily", "")]
    if values.get("isStandard") == "yes":
        parts += [values.get("standard", ""), f"mcs{values.get('mcs', '')}", f"bw{values.get('bandwidthMHz', '')}"]
    else:
        parts += [values.get("modulation", ""), f"bw{values.get('bandwidthMHz', '')}"]
    return slugify("-".join(str(p) for p in parts if p not in (None, "")))


def build_entry(submission, measured, data_file):
    """A manifest-shaped record, using the field names docs/app.js filters on.

    Contributed signals have to slot into the same facets as curated ones or
    they cannot be selected in the browser, so the mapping is deliberate rather
    than a straight copy of the submission.
    """
    values = submission.get("metadata", {})
    is_standard = values.get("isStandard") == "yes"
    bandwidth = values.get("bandwidthMHz")

    entry = {
        "id": entry_id(values),
        "signalClass": values.get("signalClass"),
        "signalFamily": values.get("signalFamily"),
        "standard": values.get("standard") if is_standard else "Custom",
        "mcs": str(values.get("mcs")) if is_standard and values.get("mcs") is not None else "n/a",
        "bandwidth": f"{bandwidth} MHz" if bandwidth is not None else "n/a",
        "modulation": values.get("modulation", "n/a"),
        "rolloff": str(values.get("rolloff")) if values.get("rolloff") is not None else "n/a",
        "filterType": values.get("filterType", "n/a"),
        "sampleRate": f"{values.get('sampleRateMHz')} MSa/s" if values.get("sampleRateMHz") else "n/a",
        "oversampling": f"{values.get('oversampling')}x" if values.get("oversampling") else "n/a",
        "memoryLength": f"{measured['sizeBytes'] / (1024 * 1024):.1f} MB",
        "papr": f"{measured['paprDb']} dB",
        "meanPacketPapr": (
            f"{measured['meanPacketPaprDb']} dB"
            if measured.get("meanPacketPaprDb") is not None else "N/A"
        ),
        "data_file": data_file.replace(os.sep, "/"),
        "name": submission_name(values),
        "contributor": values.get("contributorName", "Community contribution"),
        "licence": values.get("licence"),
        "provenance": {
            "generatorTool": values.get("generatorTool"),
            "generationNotes": values.get("generationNotes"),
            "affiliation": values.get("contributorAffiliation"),
            "contact": values.get("contributorContact"),
            "submittedAt": submission.get("submittedAt"),
            "sha256": measured["sha256"],
        },
        "figures": [],
        "isAlias": False,
        "isContributed": True,
    }

    if values.get("inPaSurvey") == "yes":
        # Recorded with its confidence attached: most papers do not describe
        # their test waveform precisely enough for an exact match, and a
        # cross-reference that hides that reads as stronger evidence than it is.
        entry["paSurvey"] = {
            "inSurvey": True,
            "edition": values.get("surveyEdition"),
            "entryId": values.get("surveyEntryId"),
            "doi": values.get("paperDoi"),
            "title": values.get("paperTitle"),
            "authors": values.get("paperAuthors"),
            "venueYear": values.get("paperVenueYear"),
            "technology": values.get("paTechnology"),
            "frequencyGHz": values.get("paFrequencyGHz"),
            "matchConfidence": values.get("surveyMatchConfidence"),
            "notes": values.get("surveyNotes"),
        }
    elif values.get("inPaSurvey") == "unsure" and values.get("paperDoi"):
        entry["paSurvey"] = {
            "inSurvey": None,
            "doi": values.get("paperDoi"),
            "title": values.get("paperTitle"),
            "notes": values.get("surveyNotes"),
        }

    return entry


def submission_name(values):
    if values.get("isStandard") == "yes":
        bits = [values.get("standard"), f"MCS{values.get('mcs')}", f"{values.get('bandwidthMHz')}MHz"]
    else:
        bits = [values.get("modulation"), f"{values.get('bandwidthMHz')}MHz", values.get("filterType")]
    return " ".join(str(b) for b in bits if b not in (None, "", "None"))


# ---------------------------------------------------------------------------
# Entry point
# ---------------------------------------------------------------------------

def main(argv=None):
    parser = argparse.ArgumentParser(description=__doc__, formatter_class=argparse.RawDescriptionHelpFormatter)
    parser.add_argument("submission", help="submission.json from the contribution bundle")
    parser.add_argument("--signal", help="the waveform file the submission describes")
    parser.add_argument("--schema", default=SCHEMA_FILE, help=f"field schema (default {SCHEMA_FILE})")
    parser.add_argument(
        "--accept",
        action="store_true",
        help=f"copy the waveform into {CONTRIB_ROOT} and write its sidecar",
    )
    parser.add_argument("--into", default=CONTRIB_ROOT, help="destination root when accepting")
    args = parser.parse_args(argv)

    with open(args.submission, encoding="utf-8") as handle:
        submission = json.load(handle)

    schema = load_schema(args.schema)
    values = submission.get("metadata", {})
    report = Report()

    if submission.get("schemaVersion") != schema.get("version"):
        report.warn(
            f"Submitted against schema version {submission.get('schemaVersion')}, "
            f"but this checkout carries version {schema.get('version')}."
        )

    print(f"Submission: {submission_name(values) or args.submission}")
    print(f"Contributor: {values.get('contributorName', 'unknown')}  Licence: {values.get('licence', 'unstated')}")
    print()

    validate_metadata(schema, values, report)

    measured = None
    if args.signal:
        measured = verify_signal(submission, args.signal, report)[0]
    else:
        report.warn("No --signal given, so only the metadata was checked.")

    status = report.render()

    if not args.accept:
        if measured:
            print()
            print("Dry run. Re-run with --accept to file this signal.")
        return status

    if status:
        print()
        print("Not accepted: fix the errors above first.")
        return status
    if not measured:
        print()
        print("Not accepted: --accept needs --signal so the waveform can be measured and filed.")
        return 1

    dest_dir = os.path.join(args.into, entry_id(values))
    os.makedirs(dest_dir, exist_ok=True)
    dest_signal = os.path.join(dest_dir, os.path.basename(args.signal))
    shutil.copy2(args.signal, dest_signal)

    entry = build_entry(submission, measured, dest_signal)
    sidecar = os.path.join(dest_dir, entry["id"] + SIDECAR_SUFFIX)
    with open(sidecar, "w", encoding="utf-8") as handle:
        json.dump({"entry": entry, "submission": submission, "measured": measured}, handle, indent=2)
        handle.write("\n")

    print()
    print(f"Filed waveform:  {dest_signal}")
    print(f"Wrote sidecar:   {sidecar}")
    print("Run scripts/build_manifest.py to publish it to the browser.")
    return 0


if __name__ == "__main__":
    sys.exit(main())
