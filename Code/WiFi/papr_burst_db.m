function [papr_db, maxInPreamble] = papr_burst_db(tx, paprMeta, nPkts, measureDataFieldOnly)
%PAPR_BURST_DB Burst PAPR in dB, excluding the inter-packet idle gaps.
%   PAPR_DB = PAPR_BURST_DB(TX, PAPRMETA, NPKTS, MEASUREDATAFIELDONLY)
%
%   Taking mean(abs(TX).^2) over the raw waveform includes the zero-valued
%   idle gaps inserted between packets, which drags the mean down and
%   inflates PAPR by a fixed offset (~0.08 dB for a 5-packet, 250-symbol
%   802.11n burst, and more for shorter packets). Both branches below
%   therefore average over active samples only.
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
%   See also PAPR_FIELD_META.

pow = abs(tx).^2;
maxInPreamble = false;
if isempty(pow)
    papr_db = NaN;
    return;
end

if measureDataFieldOnly
    nRows = size(pow, 1);
    nCols = size(pow, 2);
    burstStride = paprMeta.packetLen + paprMeta.idleLen;
    dataOffset = paprMeta.dataStart - paprMeta.packetStart;
    dataPow = zeros(paprMeta.dataLen * nPkts * nCols, 1);
    writePos = 1;

    for p = 1:nPkts
        packetBase = 1 + (p-1) * burstStride;
        s1 = packetBase + dataOffset;
        s2 = s1 + paprMeta.dataLen - 1;
        if s1 > nRows
            break;
        end
        s2 = min(s2, nRows);
        segment = pow(s1:s2, :);
        segLen = numel(segment);
        dataPow(writePos:writePos+segLen-1) = segment(:);
        writePos = writePos + segLen;
    end

    if writePos > 1
        activePow = dataPow(1:writePos-1);
    else
        activePow = pow(:);
    end
else
    activePow = papr_active_samples(pow);
    [~, maxIdx] = max(pow(:));
    burstStride = paprMeta.packetLen + paprMeta.idleLen;
    dataOffset = paprMeta.dataStart - paprMeta.packetStart;
    offsetInPacket = mod(mod(maxIdx - 1, size(pow,1)), burstStride);
    maxInPreamble = offsetInPacket < dataOffset;
end

papr_db = 10 * log10(max(activePow) / mean(activePow));
end

function activePow = papr_active_samples(pow)
%PAPR_ACTIVE_SAMPLES Drop the idle gaps between packets.
threshold = max(pow(:)) * 1e-5;
active_mask = pow > threshold;
if ~any(active_mask, 'all')
    active_mask = true(size(pow));
end
activePow = pow(active_mask);
end
