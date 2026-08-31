# scripts/signal_analysis.py
"""Waveform reading and PAPR measurement for the PA Standard Signal Library.

This is the library's definition of PAPR, in one place, so that the manifest
builder, the contribution ingest and the browser-side preview in
docs/contribute.js all report the same number for the same file. Two estimators
disagreeing by a few tenths of a dB would quietly make user signals
non-comparable with catalog ones, which is the one thing the library exists to
prevent.

The definitions:

    PAPR              10*log10(peak power / mean power), over the samples that
                      actually carry signal
    mean packet PAPR  the mean of that same ratio computed within each packet
                      separately, for a waveform that has packet structure

Both skip the inter-packet idle time and any trailing pad. This matters more
than it sounds: a multi-carrier file written by the generators in Code/WiFi is
a run of packets separated by a 16 us idle gap and then zero-padded out to an
exact power-of-two memory size, so roughly 6% of a 4 MB WiFi 4 file is exact
zeros. Averaging those zeros into the mean power drags the denominator down and
inflates PAPR -- for wifi4_mcs=1_bw=20 it reported 11.45 dB against the
11.17-11.20 dB that Code/WiFi/papr_targets.csv publishes for the same
configuration from MATLAB. Excluding them reproduces the MATLAB figure to
within 0.02 dB. Code/WiFi/papr_burst_db.m has always excluded them; this is the
Python side catching up.

Idle is found rather than assumed, since the packet layout is not derivable
from a bare I/Q file: a run of at least IDLE_RUN_SAMPLES consecutive exact
zeros is idle, and everything else is signal. A run threshold rather than a
per-sample test means one incidental zero sample inside a packet cannot split
it, and a genuine OFDM waveform does not produce dozens of consecutive exact
float zeros by chance.

One caveat is worth stating plainly. These figures cover the whole packet,
preamble included, because field boundaries are not recoverable from a bare I/Q
file without the standard's numerology. The MATLAB study measures the data
field alone by default, so the two answer slightly different questions. In
practice they agree to within about 0.05 dB, because the data field almost
always carries the peak -- but not always: in
wifi7_mcs=3_bw=80_osf=4_4MB.bin the largest sample sits 36.8 us in, inside the
EHT preamble, giving 14.90 dB here against the 11.90 dB the data-field study
publishes. Dropping that preamble brings this estimator to 11.86 dB. The
full-packet number is the honest one to publish next to a downloadable file --
a PA sees the preamble too -- but it is not interchangeable with a data-field
figure from Code/WiFi/papr_targets.csv.

docs/contribute.js implements the same rules in JavaScript so the browser
preview matches what lands here.
"""

import os

import numpy as np

# A run of at least this many consecutive zero-power samples is inter-packet
# idle or trailing pad rather than signal. The generators write a 16 us gap,
# which is 1273 samples even at the lowest rate the library ships, so this sits
# far below any real gap and far above any plausible run inside a packet.
IDLE_RUN_SAMPLES = 32

# An isolated run of signal shorter than this is a fragment, not a packet. The
# generators leave a few samples of one at the end of some bursts; counting it
# as a packet would drag the per-packet mean down by a whole dB.
MIN_PACKET_SAMPLES = 256

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
    decode to finite numbers, then float64.
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
        if len(data) < 2 or np.isnan(data).any():
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


def power_of(iq):
    """Instantaneous power per complex sample, from an interleaved I/Q array."""
    i_samples = iq[0::2]
    q_samples = iq[1::2]
    n = min(len(i_samples), len(q_samples))
    power = i_samples[:n] ** 2 + q_samples[:n] ** 2
    # A non-finite sample cannot contribute to a peak or a mean. Zeroing it
    # lets it fall into the idle mask instead of poisoning both.
    power[~np.isfinite(power)] = 0.0
    return power


def find_packets(power):
    """Ranges of POWER that carry signal, as a list of (start, stop) pairs.

    Idle is a run of at least IDLE_RUN_SAMPLES zeros; a signal run shorter than
    MIN_PACKET_SAMPLES is discarded as a fragment. Everything else is a packet,
    in file order.
    """
    if len(power) == 0:
        return []

    zero = power == 0
    # Boundaries between zero and non-zero stretches.
    changes = np.flatnonzero(np.diff(zero.view(np.int8) if zero.dtype == np.bool_ else zero))
    bounds = np.concatenate(([0], changes + 1, [len(zero)]))

    # Short zero runs stay inside whatever packet they fell in, so the mask is
    # built from long zero runs alone.
    idle = np.zeros(len(power), dtype=bool)
    for start, stop in zip(bounds[:-1], bounds[1:]):
        if zero[start] and (stop - start) >= IDLE_RUN_SAMPLES:
            idle[start:stop] = True

    packets = []
    active_changes = np.flatnonzero(np.diff(idle.view(np.int8)))
    active_bounds = np.concatenate(([0], active_changes + 1, [len(idle)]))
    for start, stop in zip(active_bounds[:-1], active_bounds[1:]):
        if not idle[start] and (stop - start) >= MIN_PACKET_SAMPLES:
            packets.append((int(start), int(stop)))
    return packets


def papr_statistics(iq):
    """PAPR of a waveform and, where it has packet structure, per packet.

    Returns a dict with paprDb, meanPacketPaprDb (None when fewer than two
    packets are present), and the packet and sample counts behind them.
    """
    power = power_of(iq)
    if len(power) < 2:
        raise SignalReadError("fewer than two usable samples")

    packets = find_packets(power)
    if packets:
        active = np.concatenate([power[a:b] for a, b in packets])
    else:
        # No packet structure at all: a continuous single-carrier stream, or a
        # file too short to segment. Measure it whole.
        active = power[power > 0]

    if len(active) < 2:
        raise SignalReadError("no signal samples: the file appears to be all zeros")

    mean_power = float(np.mean(active))
    if mean_power <= 0 or not np.isfinite(mean_power):
        raise SignalReadError("mean power is zero or not finite")

    papr_db = 10 * np.log10(float(np.max(active)) / mean_power)

    mean_packet_papr_db = None
    if len(packets) >= 2:
        per_packet = []
        for a, b in packets:
            segment = power[a:b]
            segment_mean = float(np.mean(segment))
            if segment_mean > 0:
                per_packet.append(10 * np.log10(float(np.max(segment)) / segment_mean))
        if per_packet:
            mean_packet_papr_db = round(float(np.mean(per_packet)), 2)

    return {
        "paprDb": round(float(papr_db), 2),
        "meanPacketPaprDb": mean_packet_papr_db,
        "packets": len(packets),
        "activeSamples": int(len(active)),
        "idleSamples": int(len(power) - len(active)),
        "sampleCount": int(len(power)),
    }


def describe(file_path, sample_format=None, byte_order="little"):
    """Full statistics for one file, in the shape docs/contribute.js reports.

    Returned so an ingest can be compared field by field against what the
    contributor's browser measured.
    """
    iq = read_iq(file_path, sample_format, byte_order)
    stats = papr_statistics(iq)
    power = power_of(iq)

    i_samples = iq[0::2]
    q_samples = iq[1::2]
    n = min(len(i_samples), len(q_samples))
    i_samples, q_samples = i_samples[:n], q_samples[:n]

    packets = find_packets(power)
    if packets:
        mask = np.zeros(n, dtype=bool)
        for a, b in packets:
            mask[a:b] = True
    else:
        mask = power > 0

    active_power = power[mask]
    stats.update({
        "rms": round(float(np.sqrt(np.mean(active_power))), 4),
        "peakAmplitude": round(float(np.sqrt(np.max(active_power))), 4),
        "dcOffsetI": round(float(np.mean(i_samples[mask])), 4),
        "dcOffsetQ": round(float(np.mean(q_samples[mask])), 4),
        "estimator": "peak/mean over signal samples; idle and pad excluded",
    })
    return stats


def calculate_papr(file_path):
    """PAPR and mean packet PAPR in dB, or (None, None) if unreadable.

    The tolerant entry point build_manifest.py uses: it walks the whole
    repository and must not stop on one unreadable file.
    """
    try:
        stats = papr_statistics(read_iq(file_path))
        return stats["paprDb"], stats["meanPacketPaprDb"]
    except Exception as exc:  # noqa: BLE001 - one bad file must not stop a build
        print(f"Error calculating PAPR for {file_path}: {exc}")
        return None, None
