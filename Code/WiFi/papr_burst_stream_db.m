function [papr_db, maxInPreamble] = papr_burst_stream_db(cfg, octets, nPkts, scramblerInit, streamPlan)
%PAPR_BURST_STREAM_DB Burst PAPR in dB, generated and measured in chunks.
%   PAPR_DB = PAPR_BURST_STREAM_DB(CFG, OCTETS, NPKTS, SCRAMBLERINIT,
%   STREAMPLAN) generates an NPKTS-packet burst STREAMPLAN.pktsPerChunk
%   packets at a time and accumulates the peak, sum and count of the measured
%   power samples across the chunks. Only one chunk is in memory at a time,
%   so the peak memory of a trial no longer scales with the burst length.
%
%   The result is the same number PAPR_BURST_DB returns for the whole burst:
%   the maximum and the mean are taken over exactly the same sample set, and
%   the scrambler seed is held constant across chunks the way one multi-packet
%   generator call holds it constant across packets. The payload bits are
%   drawn fresh per chunk instead of being one long vector the generator wraps
%   around, which is the same independent uniform draw either way.
%
%   SCRAMBLERINIT may be empty, in which case one seed is drawn for the whole
%   burst.
%
%   MAXINPREAMBLE reports whether the maximum of the winning chunk fell
%   outside the data field, matching PAPR_BURST_DB. It is always false in
%   data-field-only mode.
%
%   See also PAPR_STREAM_PLAN, PAPR_BURST_ACCUM, PAPR_BURST_DB.

if nargin < 4 || isempty(scramblerInit)
    scramblerInit = randi([1 127]);
end

maxPow = 0;
sumPow = 0;
nSamp = 0;
maxInPreamble = false;
bestMax = -Inf;

sent = 0;
while sent < nPkts
    nThis = min(streamPlan.pktsPerChunk, nPkts - sent);
    bits = randi([0 1], 8*octets*nThis, 1);
    tx = wlanWaveformGenerator(papr_bits_arg(cfg, bits), cfg, ...
        'NumPackets', nThis, ...
        'IdleTime', streamPlan.idleTimeUs*1e-6, ...
        'OversamplingFactor', streamPlan.osf, ...
        'ScramblerInitialization', scramblerInit, ...
        'WindowTransitionTime', 0);

    [chunkMax, chunkSum, chunkN, chunkPre] = papr_burst_accum(tx, ...
        streamPlan.meta, nThis, streamPlan.dataFieldOnly);
    clear tx bits

    if chunkN > 0
        if chunkMax > bestMax
            bestMax = chunkMax;
            maxInPreamble = chunkPre;
        end
        maxPow = max(maxPow, chunkMax);
        sumPow = sumPow + chunkSum;
        nSamp = nSamp + chunkN;
    end
    sent = sent + nThis;
end

if nSamp == 0
    papr_db = NaN;
    return;
end
papr_db = 10 * log10(maxPow / (sumPow / nSamp));
end
