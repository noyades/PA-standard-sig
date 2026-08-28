function [maxPow, sumPow, nSamp, maxInPreamble] = papr_burst_accum(tx, paprMeta, nPkts, measureDataFieldOnly)
%PAPR_BURST_ACCUM Peak, sum and count of the power samples a burst PAPR uses.
%   [MAXPOW, SUMPOW, NSAMP, MAXINPREAMBLE] = PAPR_BURST_ACCUM(TX, PAPRMETA,
%   NPKTS, MEASUREDATAFIELDONLY) reduces one waveform to the three numbers a
%   PAPR needs, without ever holding a copy of the selected samples.
%
%   PAPR_BURST_DB is the single-waveform wrapper around this, and
%   PAPR_BURST_STREAM_DB is the chunked one: it calls this per chunk and
%   combines the results, which is what lets a long burst be measured without
%   the whole thing being in memory at once. Both therefore measure PAPR by
%   exactly the same definition, which matters because the generation loops
%   compare against targets produced by GEN_PAPR_TARGETS.
%
%   Field selection follows PAPR_BURST_DB: MEASUREDATAFIELDONLY takes the data
%   field of each packet, otherwise every non-idle sample of the waveform.
%
%   See also PAPR_BURST_DB, PAPR_BURST_STREAM_DB, PAPR_FIELD_META.

maxPow = 0;
sumPow = 0;
nSamp = 0;
maxInPreamble = false;

pow = abs(tx).^2;
if isempty(pow)
    return;
end

if measureDataFieldOnly
    nRows = size(pow, 1);
    burstStride = paprMeta.packetLen + paprMeta.idleLen;
    dataOffset = paprMeta.dataStart - paprMeta.packetStart;

    for p = 1:nPkts
        packetBase = 1 + (p-1) * burstStride;
        s1 = packetBase + dataOffset;
        s2 = s1 + paprMeta.dataLen - 1;
        if s1 > nRows
            break;
        end
        s2 = min(s2, nRows);
        segment = pow(s1:s2, :);
        maxPow = max(maxPow, max(segment(:)));
        sumPow = sumPow + sum(segment(:));
        nSamp = nSamp + numel(segment);
    end

    if nSamp == 0
        % No data field landed inside the waveform; fall back to the whole
        % thing rather than reporting nothing, as papr_burst_db always has.
        maxPow = max(pow(:));
        sumPow = sum(pow(:));
        nSamp = numel(pow);
    end
else
    activePow = papr_active_samples(pow);
    maxPow = max(activePow);
    sumPow = sum(activePow);
    nSamp = numel(activePow);

    [~, maxIdx] = max(pow(:));
    burstStride = paprMeta.packetLen + paprMeta.idleLen;
    dataOffset = paprMeta.dataStart - paprMeta.packetStart;
    offsetInPacket = mod(mod(maxIdx - 1, size(pow,1)), burstStride);
    maxInPreamble = offsetInPacket < dataOffset;
end
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
