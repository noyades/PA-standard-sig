# scripts/signal_analysis.py
"""Waveform reading and PAPR measurement for the PA Standard Signal Library.

This is the library's definition of PAPR, in one place. It was lifted out of
build_manifest.py so that the manifest builder, the contribution ingest script
and any future analysis tool all report the same number for the same file --
two estimators disagreeing by a few tenths of a dB would quietly make user
signals non-comparable with catalog ones, which is the one thing the library
exists to prevent.

The definitions:

    max PAPR   10*log10(peak power / mean power), over every sample in the file
    mean PAPR  the mean, over consecutive FRAME_SIZE-sample frames, of
               10*log10(frame peak power / frame mean power)

Only whole frames contribute to the mean; a trailing partial frame is counted
in the max but not in the frame average. docs/contribute.js implements the same
two definitions in JavaScript so the browser preview matches what lands here.
"""

import os

import numpy as np

# Complex samples per frame in the mean-PAPR estimate. Mirrored by FRAME_SIZE in
# docs/contribute.js; change one and the other has to move with it.
FRAME_SIZE = 1000

# Bytes per complex sample, by format id. The ids are the ones
# docs/contribution-schema.json offers for the sampleFormat field.
SAMPLE_FORMATS = {
    "float32-iq": (np.float32, 8),
    "float64-iq": (np.float64, 16),
    "int16-iq": (np.int16, 4),
}

TEXT_SUFFIXES = (".csv", ".txt")


class SignalReadError(Exception):
    """Raised when a file cannot be read as an I/Q waveform."""


def read_iq(file_path, sample_format=None, byte_order="little"):
    """Return interleaved I/Q samples as a 1-D float array.

    SAMPLE_FORMAT is one of the ids in SAMPLE_FORMATS, or None to detect it.
    Detection follows the historical rule: float32 unless the bytes do not
    decode to finite numbers, then float64. That rule is what produced every
    PAPR figure currently in the catalog, so it is kept rather than improved.
    """
    if file_path.lower().endswith(TEXT_SUFFIXES) or sample_format == "csv-iq":
        raw = np.loadtxt(file_path, delimiter=",")
        if raw.ndim != 2 or raw.shape[1] < 2:
            raise SignalReadError(
                f"{file_path}: expected two columns of I,Q, found shape {raw.shape}"
            )
        return np.column_stack((raw[:, 0], raw[:, 1])).ravel()

    if sample_format is None:
        data = np.fromfile(file_path, dtype=np.float32)
        if len(data) < 2 or not np.isfinite(data).all():
            data = np.fromfile(file_path, dtype=np.float64)
        if len(data) < 2:
            raise SignalReadError(f"{file_path}: fewer than two samples")
        return data

    if sample_format not in SAMPLE_FORMATS:
        raise SignalReadError(f"unknown sample format {sample_format!r}")

    dtype, bytes_per_sample = SAMPLE_FORMATS[sample_format]
    dtype = np.dtype(dtype).newbyteorder("<" if byte_order == "little" else ">")
    size = os.path.getsize(file_path)
    if size % bytes_per_sample:
        raise SignalReadError(
            f"{file_path}: {size} bytes is not a whole number of "
            f"{bytes_per_sample}-byte {sample_format} samples"
        )
    data = np.fromfile(file_path, dtype=dtype).astype(np.float64)
    if sample_format == "int16-iq":
        # Scale to full-scale 1.0 so amplitudes are comparable across formats.
        # PAPR is a ratio, so it is unaffected either way.
        data = data / 32768.0
    if len(data) < 2:
        raise SignalReadError(f"{file_path}: fewer than two samples")
    return data


def papr_from_iq(iq, frame_size=FRAME_SIZE):
    """Max and mean PAPR in dB from an interleaved I/Q array."""
    i_samples = iq[0::2]
    q_samples = iq[1::2]
    n = min(len(i_samples), len(q_samples))
    power = i_samples[:n] ** 2 + q_samples[:n] ** 2

    finite = np.isfinite(power)
    if not finite.all():
        power = power[finite]
    if len(power) < 2:
        raise SignalReadError("fewer than two usable samples")

    mean_power = float(np.mean(power))
    if mean_power <= 0 or not np.isfinite(mean_power):
        raise SignalReadError("mean power is zero or not finite")

    max_power = float(np.max(power))
    max_papr_db = 10 * np.log10(max_power / mean_power)

    num_frames = len(power) // frame_size
    if num_frames > 0:
        frames = power[: num_frames * frame_size].reshape(num_frames, frame_size)
        frame_means = np.mean(frames, axis=1)
        frame_peaks = np.max(frames, axis=1)
        valid = frame_means > 0
        if np.any(valid):
            mean_papr_db = float(
                np.mean(10 * np.log10(frame_peaks[valid] / frame_means[valid]))
            )
        else:
            mean_papr_db = max_papr_db
    else:
        mean_papr_db = max_papr_db

    return round(float(max_papr_db), 2), round(float(mean_papr_db), 2)


def describe(file_path, sample_format=None, byte_order="little"):
    """Full statistics for one file, in the shape docs/contribute.js reports.

    Returned so an ingest can be compared field by field against what the
    contributor's browser measured.
    """
    iq = read_iq(file_path, sample_format, byte_order)
    max_papr_db, mean_papr_db = papr_from_iq(iq)

    i_samples = iq[0::2]
    q_samples = iq[1::2]
    n = min(len(i_samples), len(q_samples))
    i_samples, q_samples = i_samples[:n], q_samples[:n]
    power = i_samples ** 2 + q_samples ** 2

    return {
        "sampleCount": int(n),
        "maxPaprDb": max_papr_db,
        "meanPaprDb": mean_papr_db,
        "rms": round(float(np.sqrt(np.mean(power))), 4),
        "peakAmplitude": round(float(np.sqrt(np.max(power))), 4),
        "dcOffsetI": round(float(np.mean(i_samples)), 4),
        "dcOffsetQ": round(float(np.mean(q_samples)), 4),
        "framesUsed": int(n // FRAME_SIZE),
        "estimator": f"max/mean over the file; mean PAPR over {FRAME_SIZE}-sample frames",
    }


def calculate_papr(file_path, frame_size=FRAME_SIZE):
    """Max and mean PAPR in dB, or (None, None) if the file cannot be read.

    The tolerant entry point build_manifest.py uses: it walks the whole
    repository and must not stop on one unreadable file.
    """
    try:
        iq = read_iq(file_path)
        return papr_from_iq(iq, frame_size)
    except Exception as exc:  # noqa: BLE001 - one bad file must not stop a build
        print(f"Error calculating PAPR for {file_path}: {exc}")
        return None, None
