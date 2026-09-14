function streamPlan = papr_5g_stream_plan(cfg, info, measureDataFieldOnly, chunkSamples)
%PAPR_5G_STREAM_PLAN How to split a 5G NR burst into memory-sized chunks.
%   STREAMPLAN = PAPR_5G_STREAM_PLAN(CFG, INFO, MEASUREDATAFIELDONLY), with
%   CFG and INFO from PAPR_5G_CONFIG, is the NR counterpart of
%   PAPR_STREAM_PLAN. It packages the sample map, the measurement mode and
%   a generator handle so PAPR_BURST_STREAM_DB can produce a burst of N
%   units a few units at a time, exactly as it streams N-packet WLAN
%   bursts. Build it once per configuration, outside the trial loop, and
%   broadcast it to the workers.
%
%   STREAMPLAN = PAPR_5G_STREAM_PLAN(..., CHUNKSAMPLES) sets the per-chunk
%   sample budget. The default is PAPR_TRIAL_SAMPLES, or 4e6 samples when
%   unset, the same figure PAPR_STREAM_PLAN uses and for the same reason:
%   every parallel worker holds one chunk plus its power array at once. A
%   400 MHz FR2 subframe at 4x oversampling is 1.97e6 samples, so the
%   budget is two subframes there and tens of subframes at FR1 rates. At
%   least one unit is always generated per chunk.
%
%   STREAMPLAN has fields:
%     meta          - PAPR_5G_META struct (unitLen, dataRanges, ...)
%     dataFieldOnly - measurement mode, as passed to PAPR_BURST_ACCUM
%     pktsPerChunk  - units per nrWaveformGenerator call
%     generate      - @(nUnits, unitOffset, seed) handle producing one chunk
%     osf, idleTimeUs, samplesPerPacket
%                   - kept for callers that read the WLAN plan fields;
%                     idleTimeUs is 0 because NR gaps come from the slot
%                     pattern, and samplesPerPacket is the unit length.
%
%   See also PAPR_5G_META, PAPR_5G_GENERATE, PAPR_BURST_STREAM_DB,
%   PAPR_STREAM_PLAN.

if nargin < 4 || isempty(chunkSamples)
    chunkSamples = env_num('PAPR_TRIAL_SAMPLES', 4e6);
end

meta = papr_5g_meta(cfg, info);

streamPlan = struct( ...
    'meta',             meta, ...
    'dataFieldOnly',    logical(measureDataFieldOnly), ...
    'pktsPerChunk',     max(1, floor(chunkSamples / meta.unitLen)), ...
    'generate',         @(nUnits, unitOffset, seed) papr_5g_generate(cfg, meta, nUnits, unitOffset, seed), ...
    'osf',              info.osf, ...
    'idleTimeUs',       0, ...
    'samplesPerPacket', meta.unitLen);
end
