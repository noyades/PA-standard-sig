function [papr_db, maxInPreamble] = papr_burst_db(tx, paprMeta, nPkts, measureDataFieldOnly)
%PAPR_BURST_DB Burst PAPR in dB, excluding the inter-packet idle gaps.
%   PAPR_DB = PAPR_BURST_DB(TX, PAPRMETA, NPKTS, MEASUREDATAFIELDONLY)
%
%   Taking mean(abs(TX).^2) over the raw waveform includes the zero-valued
%   idle gaps inserted between packets, which drags the mean down and
%   inflates PAPR by a fixed offset (~0.08 dB for a 5-packet, 250-symbol
%   802.11n burst, and more for shorter packets). Both branches of
%   PAPR_BURST_ACCUM therefore average over active samples only.
%
%   MEASUREDATAFIELDONLY selects the data field of each packet. Measuring the
%   full burst instead lets a deterministic preamble sample win the maximum,
%   which pins PAPR to a near-constant and collapses its PDF to a spike. That
%   happens most readily at 160 MHz, where the legacy preamble fields are an
%   8x duplicated 20 MHz sequence with a very high crest factor.
%
%   MAXINPREAMBLE reports whether the burst maximum fell outside the data
%   field, so callers can warn when the statistic has degenerated.
%
%   TX has to be the whole burst. When it does not fit in memory - a wide
%   channel and a long packet reach hundreds of megabytes per trial, times
%   every parallel worker - use PAPR_BURST_STREAM_DB, which generates and
%   measures the same burst a few packets at a time.
%
%   See also PAPR_BURST_ACCUM, PAPR_BURST_STREAM_DB, PAPR_FIELD_META.

[maxPow, sumPow, nSamp, maxInPreamble] = ...
    papr_burst_accum(tx, paprMeta, nPkts, measureDataFieldOnly);

if nSamp == 0
    papr_db = NaN;
    return;
end
papr_db = 10 * log10(maxPow / (sumPow / nSamp));
end
