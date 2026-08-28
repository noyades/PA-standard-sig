function streamPlan = papr_stream_plan(cfg, osf, idleTimeUs, measureDataFieldOnly, chunkSamples)
%PAPR_STREAM_PLAN How to split a multi-packet burst into memory-sized chunks.
%   STREAMPLAN = PAPR_STREAM_PLAN(CFG, OSF, IDLETIMEUS, MEASUREDATAFIELDONLY)
%   packages everything PAPR_BURST_STREAM_DB needs for one CFG, so a trial
%   loop can build it once outside the loop and broadcast it to the workers.
%
%   STREAMPLAN = PAPR_STREAM_PLAN(..., CHUNKSAMPLES) sets the per-chunk
%   sample budget explicitly. The default is PAPR_TRIAL_SAMPLES, or 4e6
%   samples (64 MB of complex double) when that is unset. It is far smaller
%   than the PAPR_CHUNK_SAMPLES budget the runStats sections use because the
%   trial loops are parfor loops: every worker holds a chunk, plus the power
%   array derived from it, at the same time. A 330-symbol HE packet at
%   160 MHz and 4x oversampling is already 3.4e6 samples, so eight of them
%   per trial across twelve workers is what exhausted memory before this
%   existed.
%
%   At least one packet is always generated per chunk; a single packet that
%   overruns the budget is generated anyway, because dropping below one
%   packet would change the burst rather than just how it is measured.
%
%   STREAMPLAN has fields:
%     osf              - oversampling factor passed to the generator
%     idleTimeUs       - inter-packet idle gap, in microseconds
%     meta             - PAPR_FIELD_META struct for CFG at OSF
%     dataFieldOnly    - measurement mode, as passed to PAPR_BURST_ACCUM
%     samplesPerPacket - packet plus its trailing idle gap, at OSF
%     pktsPerChunk     - packets per wlanWaveformGenerator call
%
%   See also PAPR_BURST_STREAM_DB, PAPR_FIELD_META.

if nargin < 5 || isempty(chunkSamples)
    chunkSamples = env_num('PAPR_TRIAL_SAMPLES', 4e6);
end

meta = papr_field_meta(cfg, osf, idleTimeUs);
samplesPerPacket = meta.packetLen + meta.idleLen;

streamPlan = struct( ...
    'osf',              osf, ...
    'idleTimeUs',       idleTimeUs, ...
    'meta',             meta, ...
    'dataFieldOnly',    logical(measureDataFieldOnly), ...
    'samplesPerPacket', samplesPerPacket, ...
    'pktsPerChunk',     max(1, floor(chunkSamples / samplesPerPacket)));
end
