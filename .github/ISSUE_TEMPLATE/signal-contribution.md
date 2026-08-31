---
name: Signal contribution
about: Offer a waveform for the library
title: "Signal contribution: "
labels: signal-contribution
---

<!--
The contribution page fills this in for you, including the measured statistics
and a machine-readable submission.json:

    https://noyades.github.io/PA-standard-sig/contribute.html

Going through the page rather than writing this out by hand is worth it: it
measures your file with the library's own PAPR estimator, catches a mislabeled
sample format or sample rate before a maintainer sees it, and produces the
bundle to attach below. If you are here without it, fill in what you can.
-->

## The waveform

Attach the `.zip` bundle the contribution page produced. GitHub caps an
attachment at 25 MB; for a larger waveform, attach the metadata alone and link
the file from somewhere durable.

## What it is

- **Signal class:** MC or SC
- **Family:** e.g. WiFi, 5G NR, QAM
- **Standard, MCS, bandwidth:** if it follows a standard
- **Modulation, bandwidth, filter and roll-off, symbol rate:** if it does not
- **Sample rate and sample format:** e.g. 320 MSa/s, interleaved float32 I/Q

## Provenance

- **Generated with:** tool and version
- **Licence:** CC BY 4.0, CC0, or state the terms
- **Right to publish:** confirm the waveform is yours to release

## PA survey cross-reference

If this waveform was used to measure a PA that appears in the Hua Wang PA
survey, give the DOI of the paper and say how certain the match is — the exact
file, reconstructed from stated parameters, or merely representative of the
same configuration.
