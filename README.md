# PA Standard Signal Library

[![DOI](https://zenodo.org/badge/DOI/10.5281/zenodo.22048739.svg)](https://doi.org/10.5281/zenodo.22048739)


A community-oriented library of standard RF test signals for vector signal generators, intended to support more consistent and meaningful power amplifier (PA) comparisons.

## Purpose

Different test waveforms can produce very different PA behavior, which makes cross-study comparisons difficult. This repository provides curated, reusable signal sets and associated statistics so researchers and engineers can benchmark PAs with common references.

## What This Repository Provides

1. Standard signal sets for PA testing.
2. Per-signal-type PAPR distribution statistics.
3. Practical waveform selections that preserve target statistical behavior while staying usable on typical signal generators.

## Signal Types

### Multi-Carrier (MC)

Multi-Carrier (MC) modulation formats, such as orthogonal frequency division multiplexing (OFDM), are standard at lower frequencies (e.g., sub-6 GHz) for base stations and WiFi systems. In OFDM, the signal is split into multiple tightly packed frequency-domain subcarriers, structured so that the peak of one subcarrier overlaps with the nulls of its adjacent subcarriers.  

Because an OFDM signal acts as a collection of single-carrier signals transmitted in parallel, the subcarriers can constructively or destructively interfere with one another. This interference leads to massive peaks and nulls in the time domain, which intrinsically generates a high peak-to-average power ratio (PAPR). Unlike single-carrier (SC) signals—where PAPR is largely dictated by the modulation type, pulse shaping filter, and sequence length—the PAPR in MC signals is fundamentally driven by the number of subcarriers and the specific modulation applied to each.  

Because the mathematical analysis of these dynamics exceeds the scope of the main magazine article, we provide the detailed statistical breakdown here. To assist with standardized benchmarking of these complex signals, this repository includes comprehensive statistical data for each Modulation and Coding Scheme (MCS) across common standards (e.g., IEEE 802.11N/AC/AX/BE and 5G-NR). For each MCS, we provide:

- Probability Density Functions (PDFs): Illustrating the distribution of the signal envelope and phase to help visualize MC signal dynamics.
- Complementary Cumulative Distribution Functions (CCDFs): Quantifying the precise probability of the signal exceeding specific PAPR thresholds for rigorous PA evaluation.

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

- Published site: https://noyades.github.io/PA-standard-sig/
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

### WiFi 5 (802.11ac) Note

WiFi 5 at MCS 0–7 and 20/40 MHz bandwidths produces signals that are identical to their WiFi 4 (802.11n) counterparts. To avoid redundant files, these combinations are **not** replicated under WiFi 5. Instead, the WiFi 5 entries for those MCS and bandwidth combinations point directly to the corresponding WiFi 4 signal files.

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
