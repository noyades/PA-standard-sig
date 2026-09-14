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
%   PAPRMETA describes one repeating unit of the burst - a WLAN packet plus
%   its idle gap, or a 5G NR subframe block - through either of two forms:
%
%     WLAN form (PAPR_FIELD_META): packetStart, packetLen, dataStart,
%       dataLen, idleLen. The unit is packetLen + idleLen samples and the
%       data field is one contiguous range inside it.
%
%     Range form (PAPR_5G_META): unitLen and dataRanges, an Nx2 matrix of
%       0-based [first last] sample offsets from the start of the unit.
%       NR data is not one contiguous run: DM-RS-only symbols sit inside
%       the allocation and unscheduled slots break it up, so the field
%       selection needs a list rather than a start and a length.
%
%   Both forms go through the same loop, so HT/VHT/HE/EHT and NR figures are
%   measured by one definition. MAXINPREAMBLE keeps its historical name; it
%   reports that the burst maximum fell OUTSIDE the data ranges, which for
%   NR means SSB, PDCCH, DM-RS or SRS rather than a preamble.
%
%   See also PAPR_BURST_DB, PAPR_BURST_STREAM_DB, PAPR_FIELD_META, PAPR_5G_META.

maxPow = 0;
sumPow = 0;
nSamp = 0;
maxInPreamble = false;

pow = abs(tx).^2;
if isempty(pow)
    return;
end

[unitLen, dataRanges] = papr_meta_ranges(paprMeta);

if measureDataFieldOnly
    nRows = size(pow, 1);
    for p = 1:nPkts
        unitBase = 1 + (p-1) * unitLen;
        if unitBase > nRows
            break;
        end
        for r = 1:size(dataRanges, 1)
            s1 = unitBase + dataRanges(r, 1);
            s2 = unitBase + dataRanges(r, 2);
            if s1 > nRows
                break;
            end
            s2 = min(s2, nRows);
            segment = pow(s1:s2, :);
            maxPow = max(maxPow, max(segment(:)));
            sumPow = sumPow + sum(segment(:));
            nSamp = nSamp + numel(segment);
        end
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
    offsetInUnit = mod(mod(maxIdx - 1, size(pow,1)), unitLen);
    maxInPreamble = ~any(offsetInUnit >= dataRanges(:,1) & offsetInUnit <= dataRanges(:,2));
end
end

function [unitLen, dataRanges] = papr_meta_ranges(paprMeta)
%PAPR_META_RANGES Unit length and 0-based data ranges from either meta form.
if isfield(paprMeta, 'dataRanges')
    unitLen = paprMeta.unitLen;
    dataRanges = double(paprMeta.dataRanges);
    if isempty(dataRanges)
        dataRanges = zeros(0, 2);
    end
else
    unitLen = paprMeta.packetLen + paprMeta.idleLen;
    dataOffset = paprMeta.dataStart - paprMeta.packetStart;
    dataRanges = [dataOffset, dataOffset + paprMeta.dataLen - 1];
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
