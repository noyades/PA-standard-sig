# PA Standard Signal Library

A community-oriented library of standard RF test signals for vector signal generators, intended to support more consistent and meaningful power amplifier (PA) comparisons.

## Purpose

Different test waveforms can produce very different PA behavior, which makes cross-study comparisons difficult. This repository provides curated, reusable signal sets and associated statistics so researchers and engineers can benchmark PAs with common references.

## What This Repository Provides

1. Standard signal sets for PA testing.
2. Per-signal-type PAPR distribution statistics.
3. Practical waveform selections that preserve target statistical behavior while staying usable on typical signal generators.

## Signal Types

### Multi-Carrier (MC)

For multi-carrier signals, this repository includes waveforms selected to match the global mean PAPR at two practical file sizes:

- 4 MB
- 8 MB

MC files are provided in binary format with:

- 32-bit I data per sample
- 32-bit Q data per sample

MC signals are oversampled by 4x. Example:

- A 20 MHz signal is sampled at 80 MHz.

### Single-Carrier QAM (SC)

For single-carrier QAM, waveform duration strongly impacts PAPR. Long SC signals (greater than 1M symbols) show relatively tight PAPR distributions, but those durations may not fit on all signal generators.

To address this, we provide shorter-duration SC waveforms designed to preserve the same statistical behavior as longer-duration signals.

## PAPR Statistics

Rigorous PAPR distribution statistics are collected and provided on a per-signal-type basis. These statistics are intended to support:

- Fairer PA comparisons across labs and test setups
- Better understanding of waveform-dependent PA stress
- Repeatable benchmarking workflows

## Repository Layout

- [Code](Code): Scripts and tooling used to generate/analyze signals.
- [Signals](Signals): Signal files organized by modulation and use case.
- [Figures](Figures): Plots and summary visualizations, including roll-off and WiFi/cellular breakdowns.
- [LICENSE](LICENSE): Repository license.

## Interactive Signal Browser

This repository now includes a static signal browser that lets users filter available waveform assets and jump directly to signal files and related plots.

- Published site: https://rf-engine.github.io/PA-standard-sig/
- Site source: [docs/index.html](docs/index.html)

The browser currently supports:

- Multi-carrier WiFi selections using standard, MCS, bandwidth, and file size
- Single-carrier QAM selections using modulation order and roll-off
- Direct links to downloadable signal files when present
- Inline previews of associated plots when present

As the repository grows, the browser can be expanded to expose additional metadata such as filter type, memory length, and new signal families.

## Current Coverage

The repository currently includes content for:

- Cellular and WiFi signal families
- Multi-carrier and single-carrier waveform categories
- Multiple QAM orders and roll-off settings
- WiFi generations (WiFi 4 through WiFi 7)

## Contributing

Contributions are welcome. This repository will continue to grow as new waveform sets, statistics, and validation workflows are added.

If you would like to contribute, please open an issue or pull request with:

1. A clear description of the signal type and intended use.
2. Generation settings and assumptions.
3. Any accompanying PAPR/statistical characterization.

## Roadmap

Planned ongoing improvements include:

- Expanded signal families and bandwidth profiles
- Additional statistical summaries and metadata
- Improved documentation for repeatable signal generation and validation

Our goal is to keep this library relevant, practical, and useful for the RF PA community.
