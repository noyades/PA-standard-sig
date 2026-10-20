# PA Standard Signal Library — To-Do

Planned work for the signal library and the [interactive signal browser](https://noyades.github.io/PA-standard-sig/). Items keep their original numbering so they can be referenced directly; they are grouped by theme rather than by priority.

Notes marked **Current state** were verified against the repository on 2026-08-26 and should be re-checked before acting on them. Items 1, 2 and 3 carry a **Built** note describing what shipped on 2026-08-30 and what is still open. Items 7 and 9 were re-checked on 2026-10-19.

## Summary

| # | Item | Theme | Blocked by |
| --- | --- | --- | --- |
| 1 | User uploads a signal, we analyze its statistics | Portal | — (first pass built) |
| 2 | Users contribute signals to the library, sorted by type/modulation/sample rate | Portal | 8 (first pass built) |
| 3 | Add signals from prior papers, cross-referenced to the Hua Wang PA Survey | Portal | survey data source |
| 6 | Parse-signal app | Portal | 1 |
| 4 | Resample to a user-supplied sig-gen sample rate and desired bandwidth | Instrument workflow | — |
| 5 | Per-instrument upload instructions for R&S and Keysight VSGs | Instrument workflow | — |
| 7 | Not all SC signals are downloadable from the web app | Catalog integrity | — |
| 8 | Custom SC naming convention to mirror the MC convention | Naming | — |
| 9 | Drop `GI` from the MC naming convention, note it in the README | Naming | 8 (rename together) |
| 10 | Speculative OTFS signals | Speculative waveforms | 5G target table complete |
| 11 | Speculative AFDM signals | Speculative waveforms | 10 (shared scaffolding) |

---

## Portal: analysis, contribution, and cross-referencing

### 1. User can add a signal and we analyze its statistics

**Goal.** Let a user hand the portal a waveform file and get back the same statistical characterization the library publishes for its own signals — PAPR mean/max, PAPR CCDF and PDF, envelope and phase distributions, constellation where meaningful.

**Why.** The statistics are the reason the library exists. A user who brings their own waveform should be able to place it on the same axes as the curated ones rather than trusting an unverified number from their own toolchain.

**Notes.**

- Python is the intended implementation language. [scripts/build_manifest.py](scripts/build_manifest.py) already computes max and mean PAPR from interleaved `float32` binaries and from delimited text, so the analysis core partly exists and should be factored out rather than rewritten.
- The MATLAB side already produces the richer statistics (KDE-based PDF and CCDF via [Code/WiFi/papr_density.m](Code/WiFi/papr_density.m)). Decide whether the portal reimplements those in Python or whether the published curves stay MATLAB-generated and only user uploads go through Python. Divergent estimators would make user signals non-comparable to library signals, which defeats the purpose.
- A hosted upload path needs a backend. The site is currently a static GitHub Pages app that links to `raw.githubusercontent.com`, so this is the first item that changes the deployment model. In-browser analysis (WASM/JS) is the alternative that preserves the static hosting.

**Built (2026-08-30).** [docs/contribute.html](docs/contribute.html) reads a dropped waveform in the browser, detects its sample format, and reports sample count, max and mean PAPR, RMS, peak and DC offset. The estimator was factored out of `build_manifest.py` into [scripts/signal_analysis.py](scripts/signal_analysis.py) and reimplemented in [docs/contribute.js](docs/contribute.js) against the same definition, so the browser number equals the catalog number for the same file; this was verified end to end against the Python implementation. Large files are read in frame-aligned chunks, so peak memory does not scale with file length.

**Still open.** Only scalar statistics, no plots. The richer MATLAB curves (KDE PDF and CCDF via [Code/WiFi/papr_density.m](Code/WiFi/papr_density.m), envelope and phase distributions, constellation) are not reimplemented, and the question of whether they should be reimplemented in JavaScript or left MATLAB-generated is still open. Rendering a user waveform against the library reference curves is not done.

**Done when.** A user can submit a waveform plus its declared sample rate and receive PAPR statistics and plots rendered against the library's reference curves.

### 2. Users can contribute signals

**Goal.** Accept user-uploaded signals into the library, cataloged by type, modulation, sample rate, and the other axes the browser filters on.

**Why.** The README already invites contributions by issue and pull request; this makes the path self-service and ensures what arrives is described consistently enough to be filterable.

**Notes.**

- The catalog schema is [docs/manifest.json](docs/manifest.json), built by [scripts/build_manifest.py](scripts/build_manifest.py) from the on-disk directory layout. Today the metadata is *inferred from the file path*, so any contributed signal must either land in a conforming directory or carry a sidecar metadata file. Item 8 is effectively the prerequisite here.
- Required metadata to collect at upload time, at minimum: signal class (SC/MC), family, modulation, symbol or packet length, sample rate, oversampling ratio, pulse-shaping filter and roll-off, sample format, and provenance (who generated it, with what tool).
- Needs a review/acceptance step. Deciding what that is — automated validation only, or human review — is an open question.

**Built (2026-08-30).** The metadata to collect is defined once in [docs/contribution-schema.json](docs/contribution-schema.json); the contribution page generates its form from that file and [scripts/ingest_submission.py](scripts/ingest_submission.py) validates against the same file, so the two cannot drift. Collected: signal class, family, whether a standard applies and if so standard/MCS/bandwidth/guard interval, otherwise modulation/bandwidth/symbol rate/filter and roll-off, plus sample rate, sample format, oversampling, normalization, provenance (contributor, tool, generation notes) and licence with an explicit rights confirmation.

The sidecar question is settled: an accepted signal is filed under `Signals/Contributed/<id>/` with a `<id>.contribution.json` next to it, and `build_manifest.py` reads those back into the catalog rather than inferring anything from the path. A sidecar whose waveform is missing is skipped rather than published as a dead link.

Submission travels by hand, because the site is static and has no upload endpoint: the page emits a zip of the waveform plus `submission.json` and opens a prefilled issue to attach it to. The submit step is isolated in `buildSubmission`/`openPrefilledIssue`, so a hosted endpoint can replace it without touching the form or the analysis.

**Still open.** The review step is a human running `ingest_submission.py`; there is no automation and no queue. GitHub caps an attachment at 25 MB, so a larger waveform needs an out-of-band link. Contributed entries reuse the existing MC/SC facets, so a contributed signal that does not fit those facets is selectable only if its fields happen to line up -- that is item 7 and item 8 work.

**Done when.** A contributed signal appears in the browser with the same filter facets as a curated one, and its provenance is recorded.

### 3. Signals from prior papers, cross-referenced to the Hua Wang PA Survey

**Goal.** Let users add signals used in previously published work, and where possible link the entry to the corresponding PA in the Hua Wang PA survey.

**Why.** Ties the waveform to the measured PA result it was used with, which is the missing link when comparing published PA numbers across labs.

**Open questions.**

- What is the authoritative, citable, machine-readable form of the survey data, and does its license permit redistribution or only linking?
- What is the join key — a DOI, a survey row ID, a paper reference? Whatever it is has to survive survey updates.
- Many papers do not state their test waveform precisely enough to reconstruct. Decide how to represent a partial or best-effort match so the cross-reference is not read as stronger evidence than it is.

**Built (2026-08-30).** The contribution form asks whether the PA the waveform was measured with appears in the survey, and when it does collects the survey edition or access date, the row identifier, the paper DOI (validated as a bare DOI, since a DOI outlives any row numbering), title, authors, venue and year, PA technology and centre frequency. It also requires a match confidence -- exact, reconstructed, or representative -- so a cross-reference cannot silently read as stronger evidence than it is. The ingest stores this as a `paSurvey` block on the catalog entry and [docs/app.js](docs/app.js) renders it in the summary card as a DOI link with its confidence shown.

**Still open.** All three open questions below stand: nothing here consumes the survey itself. There is no authoritative machine-readable copy in the repository, no check that a claimed row exists, and no automated join -- only a recorded, human-supplied reference.

**Done when.** A catalog entry can carry one or more survey/paper references, and the browser surfaces them as links.

### 6. Parse-signal app

**Goal.** A tool that inspects an arbitrary signal file and reports what it actually contains — sample format, endianness, I/Q interleaving, length, implied sample rate, and a first guess at modulation and filtering.

**Why.** Every other portal feature assumes the user can describe their file correctly. In practice binary I/Q files arrive with no header and the parameters are guesswork. This is the front end for items 1 and 2.

**Notes.**

- Library convention for MC is interleaved 32-bit float I, 32-bit float Q, 8 bytes per complex sample. `build_manifest.py` already probes `float32` and falls back to `float64`, which is the seed of the format-detection logic.
- Detection is heuristic and can be wrong. Report a confidence and let the user override every inferred field rather than silently committing to a guess.

**Done when.** Dropping an unlabeled binary yields a correct parse for the library's own files and a sensible, overridable guess for outside files.

---

## Instrument workflow

### 4. Resample to a given sig-gen sample rate and desired bandwidth

**Goal.** The user supplies their signal generator's sample rate and the bandwidth they want; we deliver a resampled waveform that fits.

**Why.** Single-carrier signals in this library are sequences of symbols with a fixed length; they have no inherent bandwidth. All are generated and then RRC-filtered at 4x oversampling. Bandwidth only becomes meaningful once a sample rate is chosen, so "what bandwidth is this SC signal?" is a question the library currently cannot answer for the user — it can only be answered *with* their instrument's sample rate in hand.

**Notes.**

- The occupied bandwidth of an RRC-shaped SC signal is `symbol_rate * (1 + alpha)`, and `symbol_rate = sample_rate / OSR`. So the user's desired bandwidth and their instrument's sample rate together determine the required resampling ratio. The library ships roll-offs 0.05 / 0.15 / 0.25 / 0.35 / 0.45.
- MC signals do have an inherent bandwidth and are already fixed at 4x oversampling, so for those this is a straight rate conversion rather than a bandwidth choice.
- Resampling changes PAPR. Whatever the tool emits should be re-characterized and the new statistics reported, not inherited from the source file.
- Watch for instruments that only accept specific sample rates or integer-related clock ratios; the achievable rate may not be the requested one.

**Done when.** Given a sample rate and target bandwidth, the tool emits a correctly resampled file plus its recomputed statistics, or explains why that combination is not reachable.

### 5. Per-instrument upload instructions for R&S and Keysight VSGs

**Goal.** Document how to get a downloaded binary onto the instrument, for each of several specific VSG models across the Rohde & Schwarz and Keysight families — not one generic procedure.

**Why.** The file format is the easy part; the per-model loading procedure is where users actually get stuck.

**Notes.**

- Cover at least: required file format and container per family, how the instrument wants the sample rate and any scaling/level metadata communicated, transfer mechanism (USB, LAN/SCPI, shared folder), and the marker/trigger and looping setup for continuous playback.
- The library's native format is raw interleaved `float32` I/Q with no header, which is generally *not* what these instruments ingest directly. Say plainly what conversion each family needs.
- Model coverage should be an explicit list agreed up front, so "several models" does not silently become one.

**Done when.** A user with one of the listed instruments can go from a downloaded file to a playing waveform without leaving the documentation.

---

## Catalog integrity and naming

### 7. Not all signals are downloadable from the web app

**Goal.** Verify that every catalog entry resolves to a real, downloadable file, and fix those that do not.

**Current state.** Two of the three problems found on 2026-08-26 are fixed; one is open, and the CI check is not started. Re-checked 2026-10-19:

1. **Open: most SC entries are unreachable through the UI, not missing.** All 625 SC entries in `docs/manifest.json` point at files that exist on disk *and* are committed to git, so the download links themselves are sound. The problem is the filter set: [docs/app.js:63](docs/app.js#L63) defines the SC facets as `["modulation", "rolloff", "filterType"]` only. There is no selector for symbol length (100 / 1k / 10k / 100k / 1M) or for the `PAPR_average` vs `PAPR_max` variant, even though the manifest carries `symbols`. That is 25 addressable combinations covering 625 entries, so the great majority cannot be selected.
2. **Fixed: the 16 WiFi 5 160 MHz entries that pointed at missing files.** The `wifi5_..._7.617188e+00MB.bin` files were regenerated through [Code/WiFi/papr_fit_airtime.m](Code/WiFi/papr_fit_airtime.m) at real 4 and 8 MB sizes (`wifi5_mcs=N_bw=160_osf=2_4MB.bin`) and the malformed ones are gone.
3. **Fixed: WiFi 6 and WiFi 7 signals not committed.** All 96 WiFi 6 and 140 WiFi 7 files are tracked.

A fourth failure of the same kind was found and fixed on 2026-10-19: [scripts/build_manifest.py](scripts/build_manifest.py) silently skipped any `.bin` its filename patterns did not recognise. That dropped the 28 WiFi 7 320 MHz files (fractional `osf=1.875`) and every 5G NR file. Both are now parsed, but the builder still skips an unrecognised filename without saying so.

**Notes.** Add a CI step to [.github/workflows/pages.yml](.github/workflows/pages.yml) that fails when a manifest `data_file` is missing from disk or absent from the committed tree, and that warns, or fails, when a `.bin` under `Signals/` matches no pattern in `build_manifest.py`. The first converts "a user reports a broken download" into a failing build; the second would have caught the 320 MHz and 5G omissions above.

**Done when.** Every manifest entry is reachable through the UI and resolves to a committed file, and a check exists to keep it that way.

### 8. Custom naming convention for SC files

**Goal.** Give SC files a structured filename mirroring the MC convention:

```
SC_<Modulation>_<Filter>_<Length>[_<Extension>]
```

where `Extension` captures anything exotic. Our own signals will not need it, but a contributed signal that differs in oversampling ratio, filter type, or any other parameter needs somewhere to record that difference rather than being silently mislabeled.

**Why.** SC metadata currently lives in the directory path, not the filename. A file taken out of its directory — which is exactly what happens when a user downloads one — loses everything except its modulation and PAPR variant.

**Current state.** SC files are laid out as `Signals/Single Carrier/<length> symbols/<order>QAM/alpha<NNN>/<order>-QAM_PAPR_{average,max}.bin`, e.g. `Signals/Single Carrier/1M symbols/4096QAM/alpha045/4096-QAM_PAPR_average.bin`. Roll-off and length appear only in the path; the filename carries modulation and the average/max variant. Each directory also holds `_constellation.png`, `_properties.csv`, `_properties.mat`, and a `summary.txt`.

**Open questions.**

- The `PAPR_average` / `PAPR_max` distinction is real and currently only in the filename. Where does it go in the new scheme — is it part of `Extension`, or a field of its own?
- Roll-off is not in the proposed pattern. Is it meant to be folded into `Filter` (e.g. `RRC045`), or does it need its own field?

**Notes.** Renaming is a breaking change: it invalidates `docs/manifest.json`, the derived `id` values, any `raw.githubusercontent.com` link a user has already saved, and any path referenced by the archived Zenodo release. Plan the rename together with item 9 so the catalog churns once rather than twice, and consider whether old paths need redirects or a compatibility table.

**Done when.** SC filenames are self-describing, `build_manifest.py` reads metadata from the filename rather than inferring it from the directory, and the browser exposes the fields as filters.

### 9. Drop `GI` from the MC naming convention

**Goal.** Remove the `GI=Long` field from WiFi 4 filenames, which is the only family that carries it, and record the guard-interval convention in the README instead.

**Current state.** Re-checked 2026-10-19. The original goal also dropped `osf`, on the grounds that every MC signal used 4x. That is no longer true, and `osf` must stay:

- MC signals are now exported at 2x (generated and PAPR-matched at 4x, then resampled), capped at a 600 MS/s ARB clock, so `osf` varies: 318 WiFi files at `osf=2`, 28 WiFi 7 320 MHz files at `osf=1.875`, and 400 MHz 5G NR at `osf=1.2207`. The README already says the factor is in the file name.
- For 5G NR, `osf` alone does not give the sample rate, because the rate is Nfft × SCS × osf rather than bandwidth × osf. The 5G names therefore also carry `fs=`, e.g. `5g_dl_mcs=20_bw=100_scs=30_osf=2_fs=245.76MSps_4MB.bin`.

Committed WiFi filenames follow two patterns:

- `wifi4_mcs=N_bw=N_GI=Long_osf=N_NMB.bin`, WiFi 4 only
- `wifiN_mcs=N_bw=N_osf=N_NMB.bin`, WiFi 5/6/7

Dropping `GI` yields a uniform `wifiN_mcs=N_bw=N_osf=N_NMB.bin`.

**Notes.**

- The guard-interval convention should be stated in the README next to the oversampling note. "GI=Long" is meaningful for HT/VHT (0.8 µs), whereas HE/EHT use a numeric guard interval. The README wording should not imply a single shared setting where there is not one.
- Same breaking-change caveat as item 8: filenames are embedded in `docs/manifest.json`, in saved raw URLs, and in the Zenodo-archived release. Do this rename in the same pass as item 8.
- The generators that construct these names live in the `fname`/`filename` assignments in [Code/WiFi](Code/WiFi); the parser that consumes them is [scripts/build_manifest.py](scripts/build_manifest.py). Both change together.
- With `GI` the only field removed, the gain is small. Consider whether it is worth a breaking rename on its own, or whether it should only happen if item 8 goes ahead.

**Done when.** MC filenames carry only the fields that vary, the generators and manifest builder agree on the new pattern, and the README documents the fixed conventions.

---

## Speculative waveforms

Candidate 6G waveforms with no published standard. They are worth characterizing because their PAPR behaves differently from OFDM, but every parameter is our choice rather than a specification's, so results are only meaningful if those choices are stated and kept few. Both items share the conventions below.

- Keep them out of the standard families: own folder (`Code/OTFS/`, `Code/AFDM/`), own `pa_<waveform>_*.m` scripts, and a sidecar field marking the signal as non-standard so the browser never presents it alongside a 3GPP or IEEE waveform without that label.
- Reuse NR numerology (e.g. 100 MHz / 30 kHz and 400 MHz / 120 kHz) so every result lines up directly against the 5G CP-OFDM and DFT-s-OFDM rows in [Code/5G/papr_5g_targets.csv](Code/5G/papr_5g_targets.csv).
- No toolbox generates either waveform, so each needs a custom generator. Everything downstream should be reused unchanged: the PAPR definition and accumulation ([Code/WiFi/papr_burst_db.m](Code/WiFi/papr_burst_db.m)), the memory-budget/airtime policy ([Code/5G/papr_5g_fit_airtime.m](Code/5G/papr_5g_fit_airtime.m)), loop filtering, export rate and the memory-capped parallel trials ([Code/5G/papr_5g_trials.m](Code/5G/papr_5g_trials.m)).

### 10. Speculative OTFS signals

**Goal.** Generate and characterize Orthogonal Time Frequency Space (OTFS) waveforms on a small, explicit parameter grid, with PAPR targets and generator-ready files in the same form as the 5G set.

**Why.** OTFS spreads each delay-Doppler symbol across the whole time-frequency frame. With a rectangular pulse, each time-domain sample is a combination of roughly N Doppler-axis symbols rather than all M subcarriers, so the PAPR bound scales with N (typically 8–64) instead of with the subcarrier count. That should place OTFS between CP-OFDM and DFT-s-OFDM, and where exactly is something this library can measure.

**Notes.**

- Generation is an ISFFT (2-D FFT) onto an OFDM modulator, or an inverse Zak transform for the DD-domain form. Pick one and state it; the two differ in pulse and prefix structure, which matters for PAPR.
- Pilot design likely dominates: the common embedded-pilot scheme puts a single high-power DD-domain impulse inside a zero guard region, which is a deterministic peak. Measure with and without it, and in both `data` and `full` modes, as the 5G scripts do.
- Proposed sweep: N ∈ {8, 16, 32}; QPSK / 16QAM / 64QAM; pilot off or embedded at 2–3 power levels; one cyclic prefix per frame vs one per symbol.

**Open questions.**

- Pulse shape: rectangular only, or also a smoother window? Each added pulse multiplies the grid.
- Is there a published reference parameter set (e.g. from a 6G study item or a widely cited paper) to anchor at least one configuration to?

**Done when.** A target table and a set of exported files exist for the agreed grid, each labeled non-standard, with PDF/CCDF figures directly comparable to the 5G results.

### 11. Speculative AFDM signals

**Goal.** Same as item 10 for Affine Frequency Division Multiplexing (AFDM), the chirp-based multicarrier candidate proposed for high-mobility 6G links.

**Why.** AFDM is the main alternative to OTFS for doubly dispersive channels and, unlike OTFS, keeps a one-dimensional transform structure close to OFDM. Measuring both on the same numerology answers whether the choice between them has a PA cost.

**Notes.**

- Generation is an inverse discrete affine Fourier transform (IDAFT): an IDFT sandwiched between two chirp multiplications with parameters c1 and c2, followed by a chirp-periodic prefix (CPP) rather than a plain cyclic prefix. All three need stating per file.
- Expected to sit near CP-OFDM in PAPR, since each sample still combines all N subcarriers; the chirps change phase, not magnitude. Confirm rather than assume, and check whether particular c1/c2 choices move it.
- AFDM pilots use the same embedded-pilot-with-guard idea as OTFS, so the pilot-power sweep from item 10 should carry over directly.
- Build after item 10 so the scaffolding (sidecar labeling, sweep script shape, target table) is written once.

**Open questions.**

- Which c1 rule to use: the one derived from the maximum Doppler of a design channel, or a fixed value? The former ties the waveform to an assumed channel.
- Does c2 get swept, or fixed (e.g. at 0, or an irrational value as some papers suggest)?

**Done when.** As item 10, with AFDM and OTFS results plotted on shared axes with the 5G CP-OFDM and DFT-s-OFDM baselines.
