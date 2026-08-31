function progress = papr_progress(label, total, varargin)
%PAPR_PROGRESS Console progress reporting for the long PAPR trial loops.
%   PROGRESS = PAPR_PROGRESS(LABEL, TOTAL) prints a start line and returns a
%   controller for a loop of TOTAL units of work. A runLong sweep is tens of
%   minutes of silence otherwise, so there is no way to tell a slow run from
%   a stalled one.
%
%   PROGRESS has fields:
%     queue  - parallel.pool.DataQueue to broadcast into a parfor loop. Send
%              one message per completed iteration, SEND(PROGRESS.QUEUE, 1);
%              the listener runs on the client, so the status lines appear
%              while the loop is still running rather than after it. Empty
%              when a DataQueue cannot be created (no Parallel Computing
%              Toolbox), in which case the parfor body must skip the SEND.
%     report - function handle. Call PROGRESS.REPORT() once per completed
%              unit from a serial loop, where no queue is needed.
%     finish - function handle. Call PROGRESS.FINISH() after the loop for the
%              closing line with the total elapsed time.
%
%   PAPR_PROGRESS(..., 'StartPool', true) brings up the parallel pool before
%   the clock starts, so the minute a cold parpool takes is not charged to the
%   trials. Use it in front of a parfor loop; leave it off for a serial one.
%
%   PAPR_PROGRESS(..., 'MinInterval', SEC) sets the minimum number of seconds
%   between status lines. The default is PAPR_PROGRESS_SEC, or 15 s when that
%   is unset. A line is also printed whenever the completed fraction passes
%   the next 10% mark, so a fast loop still reports something. Set
%   PAPR_PROGRESS=0 to silence the reporting entirely.
%
%   Example:
%     progress = papr_progress('runLong CBW80 MCS0', numSims);
%     dq = progress.queue;
%     parfor t = 1:numSims
%         papr_db(t) = papr_burst_stream_db(cfg, octets, 8, seed(t), plan);
%         if ~isempty(dq)
%             send(dq, 1);
%         end
%     end
%     progress.finish();

minInterval = env_num('PAPR_PROGRESS_SEC', 15);
startPool = false;
for k = 1:2:numel(varargin)
    switch lower(varargin{k})
        case 'mininterval'
            minInterval = varargin{k+1};
        case 'startpool'
            startPool = logical(varargin{k+1});
        otherwise
            error('papr_progress:BadOption', 'Unknown option %s.', varargin{k});
    end
end

enabled = (env_num('PAPR_PROGRESS', 1) ~= 0) && total > 0;
if startPool
    % Starting a pool takes the best part of a minute. Do it before the clock
    % starts, or that minute is charged to the trials and the first ETA is off
    % by an hour.
    try
        pool = gcp('nocreate');
        if isempty(pool)
            pool = gcp();
        elseif enabled
            pool = [];      % already up, and already announced by an earlier call
        end
        if enabled && ~isempty(pool)
            fprintf('[%s] parallel pool: %d workers\n', label, pool.NumWorkers);
        end
    catch
        % No Parallel Computing Toolbox: parfor runs serially, nothing to do.
    end
end
done = 0;
lastPrint = 0;
nextMark = 10;          % next decile, in percent, that forces a line
clock = tic;

if enabled
    fprintf('[%s] start: %d trials\n', label, total);
end

% The listener holds a reference to this workspace, so `done` and the timer
% survive between calls without a persistent variable or a handle class.
queue = [];
if enabled
    try
        queue = parallel.pool.DataQueue;
        afterEach(queue, @(~) tick());
    catch
        queue = [];     % serial fallback: callers use progress.report()
    end
end

progress = struct('queue', queue, 'report', @tick, 'finish', @finish, ...
    'label', label, 'total', total);

    function tick(~)
        done = done + 1;
        if ~enabled || done >= total
            return;     % the closing line comes from finish()
        end
        elapsed = toc(clock);
        pct = 100 * done / total;
        if (elapsed - lastPrint) < minInterval && pct < nextMark
            return;
        end
        lastPrint = elapsed;
        while pct >= nextMark
            nextMark = nextMark + 10;
        end
        rate = done / max(elapsed, eps);
        fprintf('[%s] %d/%d (%.1f%%) elapsed %s, eta %s, %.2f trials/s\n', ...
            label, done, total, pct, hms(elapsed), hms((total - done) / rate), rate);
    end

    function finish(~)
        if ~enabled
            return;
        end
        elapsed = toc(clock);
        fprintf('[%s] done: %d/%d in %s (%.2f trials/s)\n', ...
            label, done, total, hms(elapsed), done / max(elapsed, eps));
    end
end

function s = hms(seconds)
%HMS Duration as HH:MM:SS, which reads better than a raw second count for the
%   multi-hour runs these loops turn into at full trial counts.
if ~isfinite(seconds) || seconds < 0
    s = '--:--:--';
    return;
end
seconds = round(seconds);
s = sprintf('%02d:%02d:%02d', floor(seconds/3600), mod(floor(seconds/60), 60), mod(seconds, 60));
end
