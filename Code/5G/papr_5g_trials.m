function [papr_db, outside, nWorkers] = papr_5g_trials(nUnits, seeds, streamPlan, dq, maxWorkers)
%PAPR_5G_TRIALS Run the burst-PAPR trials in parallel within the memory budget.
%   [PAPR_DB, OUTSIDE] = PAPR_5G_TRIALS(NUNITS, SEEDS, STREAMPLAN) runs one
%   PAPR_BURST_STREAM_DB trial of NUNITS units per entry of SEEDS on the
%   parallel pool and returns the per-trial PAPR and outside-data flag.
%
%   Wide NR carriers are memory-bound, not CPU-bound: one chunk of a 400 MHz
%   FR2 burst at 4x oversampling is 63 MB of samples but peaks near 1 GB
%   inside nrWaveformGenerator, so a full pool of workers exhausts physical
%   memory even though each worker alone is fine. The worker count is
%   therefore capped at what PAPR_MEM_FRACTION (default 0.75) of physical
%   memory holds, counting PAPR_WORKER_BASE_GB (default 0.5) per worker plus
%   PAPR_MEM_FACTOR (default 18, measured) times the chunk's complex-double
%   size. An out-of-memory error halves the worker count and reruns the
%   trials rather than failing the job. Every reduction is printed. The progress
%   queue DQ, when given, receives one message per completed trial; a
%   rerun sends them again.
%
%   [...] = PAPR_5G_TRIALS(..., DQ, MAXWORKERS) also caps the worker count
%   at MAXWORKERS, so a sweep can carry forward the count that last worked.
%   The third output NWORKERS is the count the trials completed on.
%
%   See also PAPR_BURST_STREAM_DB, PAPR_5G_STREAM_PLAN.

if nargin < 4
    dq = [];
end
if nargin < 5 || isempty(maxWorkers)
    maxWorkers = Inf;
end

trials = numel(seeds);
chunkSamples = min(streamPlan.pktsPerChunk, nUnits) * streamPlan.meta.unitLen;
[nWorkers, poolSize] = worker_cap(chunkSamples);
nWorkers = min(nWorkers, maxWorkers);
if nWorkers < poolSize
    fprintf('  Memory: %d of %d workers (%.0f MB chunks, ~%.1f GB peak each).\n', ...
        nWorkers, poolSize, chunkSamples * 16 / 1e6, ...
        env_num('PAPR_WORKER_BASE_GB', 0.5) + chunkSamples * 16 * env_num('PAPR_MEM_FACTOR', 18) / 1e9);
end

while true
    papr_db = zeros(trials, 1);
    outside = false(trials, 1);
    try
        parfor (t = 1:trials, nWorkers)
            [papr_db(t), outside(t)] = papr_burst_stream_db([], [], nUnits, seeds(t), streamPlan);
            if ~isempty(dq)
                send(dq, 1);
            end
        end
        return;
    catch err
        if ~is_oom(err) || nWorkers <= 1
            rethrow(err);
        end
        nWorkers = max(1, floor(nWorkers / 2));
        fprintf('  Out of memory; rerunning the trials on %d worker(s).\n', nWorkers);
    end
end
end

function [nWorkers, poolSize] = worker_cap(chunkSamples)
%WORKER_CAP Workers whose peak memory fits a share of physical memory.
%   The budget is a share of TOTAL physical memory, not of what is free
%   right now: an idle worker keeps the heap of its last trial, so a pool
%   that has just run looks like it has used everything up when that memory
%   is in fact what its workers will reuse.
pool = gcp('nocreate');
if isempty(pool)
    poolSize = feature('numcores');
else
    poolSize = pool.NumWorkers;
end
nWorkers = poolSize;
perWorker = env_num('PAPR_WORKER_BASE_GB', 0.5) * 1e9 + ...   % idle worker, toolboxes loaded
    chunkSamples * 16 * env_num('PAPR_MEM_FACTOR', 18);       % one chunk at its peak
try
    [user, sys] = memory;           % Windows only
    budget = env_num('PAPR_MEM_FRACTION', 0.75) * sys.PhysicalMemory.Total - user.MemUsedMATLAB;
catch
    return;                         % no estimate: rely on the OOM retry
end
nWorkers = max(1, min(poolSize, floor(budget / perWorker)));
end

function tf = is_oom(err)
%IS_OOM True for an out-of-memory error, also when a parfor worker raised it.
tf = strcmp(err.identifier, 'MATLAB:nomem') || ...
    contains(getReport(err, 'basic'), 'Out of memory');
if ~tf
    for k = 1:numel(err.cause)
        tf = tf || is_oom(err.cause{k});
    end
end
end
