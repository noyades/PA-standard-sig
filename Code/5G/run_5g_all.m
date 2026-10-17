function run_5g_all(varargin)
%RUN_5G_ALL Sweep pa_5G_dl / pa_5G_ul over every channel, MCS and file size.
%   RUN_5G_ALL() runs the downlink CDF study and signal generation (4 and
%   8 MB) for every (SCS, BW) row of PAPR_5G_COMBOS and every MCS of the
%   64QAM table, in one MATLAB session so the parallel pool stays warm and
%   MATLAB is not restarted 500 times. Combinations whose outputs already
%   exist are skipped, so the sweep can be stopped and restarted. Each
%   combination runs in its own try/catch: one failure is logged and the
%   sweep moves on.
%
%   The existing scripts are run unchanged, in the base workspace, with
%   their PAPR_* environment overrides set per combination. They begin with
%   "clear variables", which is why this is a function and why they are
%   run through evalin('base', ...) rather than called directly.
%
%   RUN_5G_ALL(NAME, VALUE, ...) narrows the sweep:
%     'Direction'  'dl' (default) or 'ul'.
%     'Waveforms'  Uplink only. Default {'cp-ofdm', 'dft-s-ofdm'}.
%     'Steps'      'cdf', 'gen', or {'cdf', 'gen'} (default both).
%     'MB'         File sizes for the generation step. Default [4 8].
%     'SCS'        Keep only these SCS rows of PAPR_5G_COMBOS. Default all.
%     'BW'         Keep only these BW rows. Default all.
%     'MCS'        MCS indices. Default 0:28 (the 64QAM table; indices the
%                  selected table does not define are skipped).
%     'MCSTable'   '64QAM' (default) or '256QAM'.
%     'Force'      true re-runs combinations whose outputs exist. Default
%                  false.
%     'DryRun'     true prints the plan and runs nothing. Default false.
%
%   Every option is also readable from the shell through a PAPR_ALL_*
%   environment variable of the same name (PAPR_ALL_DIRECTION,
%   PAPR_ALL_STEPS, PAPR_ALL_MB, PAPR_ALL_SCS, PAPR_ALL_BW, PAPR_ALL_MCS,
%   PAPR_ALL_MCS_TABLE, PAPR_ALL_WAVEFORMS, PAPR_ALL_FORCE,
%   PAPR_ALL_DRYRUN), lists comma-separated, so a batch job needs no
%   MATLAB argument quoting:
%
%     matlab -batch "run_5g_all"
%     matlab -batch "run_5g_all('Direction','ul','Steps','gen')"
%     PAPR_ALL_SCS=120 PAPR_ALL_MB=4 matlab -batch "run_5g_all"
%
%   Other PAPR_* variables the scripts read (PAPR_MEASURE_MODE,
%   PAPR_TRIALS, PAPR_GEN_SUBFRAMES, PAPR_FR, ...) pass straight through.
%
%   Progress and the per-combination outcome go to run_5g_all_<dir>.log
%   next to this file as well as the command window; the scripts clear the
%   command window on every run, so the log is the record.
%
%   See also PA_5G_DL, PA_5G_UL, GEN_PAPR_5G_TARGETS, PAPR_5G_COMBOS.

scriptDir = fileparts(mfilename('fullpath'));
addpath(scriptDir);
addpath(fullfile(fileparts(scriptDir), 'WiFi'));
addpath(fileparts(scriptDir));
repoRoot = fileparts(fileparts(scriptDir));

opt = parse_options(varargin{:});

isUL = strcmp(opt.Direction, 'ul');
if isUL
    scriptName = 'pa_5G_ul.m';
    sigPath = fullfile(repoRoot, 'Signals', 'Multi Carrier', '5G NR', 'Uplink');
    figPath = fullfile(repoRoot, 'Figures', '5G NR', 'Uplink');
    waveforms = opt.Waveforms;
else
    scriptName = 'pa_5G_dl.m';
    sigPath = fullfile(repoRoot, 'Signals', 'Multi Carrier', '5G NR', 'Downlink');
    figPath = fullfile(repoRoot, 'Figures', '5G NR', 'Downlink');
    waveforms = {'cp-ofdm'};
end
scriptPath = fullfile(scriptDir, scriptName);
[~, modeTag] = papr_measure_mode(true);
doCdf = any(strcmp(opt.Steps, 'cdf'));
doGen = any(strcmp(opt.Steps, 'gen'));

combos = papr_5g_combos();
if ~isempty(opt.SCS), combos = combos(ismember(combos(:,1), opt.SCS), :); end
if ~isempty(opt.BW),  combos = combos(ismember(combos(:,2), opt.BW), :);  end
if isempty(combos)
    error('run_5g_all:NoCombos', 'The SCS/BW filters leave no channel to run.');
end

logPath = fullfile(scriptDir, sprintf('run_5g_all_%s.log', opt.Direction));
logID = fopen(logPath, 'a');
if logID < 0
    error('run_5g_all:CannotLog', 'Could not open %s for writing.', logPath);
end
cleanupLog = onCleanup(@() fclose(logID));
say = @(varargin) log_line(logID, varargin{:});

if ~isfile(fullfile(scriptDir, 'papr_5g_targets.csv'))
    say(['WARNING: papr_5g_targets.csv not found. Every generation run will ' ...
         'measure a local target (PAPR_GEN_LOCAL_TRIALS bursts) instead of ' ...
         'using the table. Run gen_papr_5g_targets.m first for table targets.']);
end

% Build the plan first so the count is known and a dry run has something to
% print. One job per (waveform, channel, MCS): the CDF study once, then one
% generation per file size. The first job of a combination carries both the
% CDF and the first size so the scripts are invoked as few times as possible.
jobs = struct('waveform', {}, 'scs', {}, 'bw', {}, 'mcs', {}, 'cdf', {}, 'mb', {});
nSkipped = 0;
for iw = 1:numel(waveforms)
    wf = waveforms{iw};
    wfTag = strrep(wf, '-', '');
    for ic = 1:size(combos, 1)
        scs = combos(ic, 1); bw = combos(ic, 2);
        for mcs = opt.MCS
            try
                papr_5g_mcs(mcs, opt.MCSTable, strcmp(wf, 'dft-s-ofdm'));
            catch
                continue;   % reserved index in this table
            end
            if isUL
                tag = sprintf('%s_mcs=%d_bw=%d_scs=%d', wfTag, mcs, bw, scs);
            else
                tag = sprintf('mcs=%d_bw=%d_scs=%d', mcs, bw, scs);
            end

            wantCdf = doCdf && (opt.Force || ~cdf_done(figPath, opt.Direction, modeTag, tag));
            wantMb = [];
            if doGen
                for mb = opt.MB
                    if opt.Force || ~gen_done(sigPath, opt.Direction, tag, mb)
                        wantMb(end+1) = mb; %#ok<AGROW>
                    end
                end
            end
            if ~wantCdf && isempty(wantMb)
                nSkipped = nSkipped + 1;
                continue;
            end
            if isempty(wantMb)
                jobs(end+1) = struct('waveform', wf, 'scs', scs, 'bw', bw, 'mcs', mcs, ...
                    'cdf', true, 'mb', []); %#ok<AGROW>
            else
                for k = 1:numel(wantMb)
                    jobs(end+1) = struct('waveform', wf, 'scs', scs, 'bw', bw, 'mcs', mcs, ...
                        'cdf', wantCdf && k == 1, 'mb', wantMb(k)); %#ok<AGROW>
                end
            end
        end
    end
end

say('run_5g_all %s: %d job(s) to run, %d combination(s) already complete (mode=%s, table=%s, steps=%s, MB=[%s]).', ...
    upper(opt.Direction), numel(jobs), nSkipped, modeTag, opt.MCSTable, ...
    strjoin(opt.Steps, '+'), num2str(opt.MB));
if isempty(jobs)
    say('Nothing to do.');
    return;
end
if opt.DryRun
    for j = 1:numel(jobs)
        say('  %s', job_label(jobs(j)));
    end
    say('Dry run; nothing executed.');
    return;
end

% Save the environment the scripts read so the sweep leaves it as found.
envNames = {'PAPR_RUN_ALL', 'PAPR_RUN_CDF', 'PAPR_RUN_GEN', 'PAPR_BW', 'PAPR_SCS', ...
            'PAPR_MCS', 'PAPR_MCS_TABLE', 'PAPR_MB', 'PAPR_WAVEFORM'};
envSaved = cellfun(@getenv, envNames, 'UniformOutput', false);
cleanupEnv = onCleanup(@() cellfun(@setenv, envNames, envSaved));

setenv('PAPR_RUN_ALL', '0');
setenv('PAPR_MCS_TABLE', opt.MCSTable);
nOk = 0; nFail = 0;
tSweep = tic;
for j = 1:numel(jobs)
    job = jobs(j);
    setenv('PAPR_BW',  num2str(job.bw));
    setenv('PAPR_SCS', num2str(job.scs));
    setenv('PAPR_MCS', num2str(job.mcs));
    setenv('PAPR_RUN_CDF', num2str(double(job.cdf)));
    setenv('PAPR_RUN_GEN', num2str(double(~isempty(job.mb))));
    if isUL
        setenv('PAPR_WAVEFORM', job.waveform);
    end
    if ~isempty(job.mb)
        setenv('PAPR_MB', num2str(job.mb));
    end

    say('[%d/%d] start %s', j, numel(jobs), job_label(job));
    tJob = tic;
    try
        % Run in the base workspace: the script's "clear variables" then
        % clears base, not this function's loop state.
        evalin('base', sprintf('run(''%s'');', strrep(scriptPath, '''', '''''')));
        nOk = nOk + 1;
        say('[%d/%d] done  %s (%.1f min)', j, numel(jobs), job_label(job), toc(tJob)/60);
    catch err
        nFail = nFail + 1;
        say('[%d/%d] FAIL  %s (%.1f min): %s', j, numel(jobs), job_label(job), ...
            toc(tJob)/60, strrep(err.message, newline, ' '));
    end
end
say('run_5g_all %s finished: %d ok, %d failed, %.1f h total. Log: %s', ...
    upper(opt.Direction), nOk, nFail, toc(tSweep)/3600, logPath);
end

%% ------------------------------------------------------------------------
function opt = parse_options(varargin)
p = inputParser;
p.FunctionName = 'run_5g_all';
addParameter(p, 'Direction', env_str('PAPR_ALL_DIRECTION', 'dl'));
addParameter(p, 'Waveforms', env_list('PAPR_ALL_WAVEFORMS', {'cp-ofdm', 'dft-s-ofdm'}));
addParameter(p, 'Steps',     env_list('PAPR_ALL_STEPS', {'cdf', 'gen'}));
addParameter(p, 'MB',        env_nums('PAPR_ALL_MB', [4 8]));
addParameter(p, 'SCS',       env_nums('PAPR_ALL_SCS', []));
addParameter(p, 'BW',        env_nums('PAPR_ALL_BW', []));
addParameter(p, 'MCS',       env_nums('PAPR_ALL_MCS', 0:28));
addParameter(p, 'MCSTable',  env_str('PAPR_ALL_MCS_TABLE', '64QAM'));
addParameter(p, 'Force',     env_num('PAPR_ALL_FORCE', 0) ~= 0);
addParameter(p, 'DryRun',    env_num('PAPR_ALL_DRYRUN', 0) ~= 0);
parse(p, varargin{:});
opt = p.Results;

opt.Direction = lower(char(opt.Direction));
if ~any(strcmp(opt.Direction, {'dl', 'ul'}))
    error('run_5g_all:BadDirection', 'Direction must be ''dl'' or ''ul'', got "%s".', opt.Direction);
end
opt.Waveforms = lower(cellstr(opt.Waveforms));
if ~all(ismember(opt.Waveforms, {'cp-ofdm', 'dft-s-ofdm'}))
    error('run_5g_all:BadWaveform', 'Waveforms must be cp-ofdm and/or dft-s-ofdm.');
end
opt.Steps = lower(cellstr(opt.Steps));
if ~all(ismember(opt.Steps, {'cdf', 'gen'}))
    error('run_5g_all:BadStep', 'Steps must be ''cdf'' and/or ''gen''.');
end
opt.MCSTable = upper(char(opt.MCSTable));
validateattributes(opt.MB,  {'numeric'}, {'vector', 'positive'}, 'run_5g_all', 'MB');
validateattributes(opt.MCS, {'numeric'}, {'vector', 'integer', 'nonnegative'}, 'run_5g_all', 'MCS');
opt.MCS = opt.MCS(:)';
opt.MB = opt.MB(:)';
end

function tf = cdf_done(figPath, direction, modeTag, tag)
tf = isfile(fullfile(figPath, sprintf('5g_%s_PAPRPDF_%s_%s.png', direction, modeTag, tag))) && ...
     isfile(fullfile(figPath, sprintf('5g_%s_PAPRCCDF_%s_%s.png', direction, modeTag, tag)));
end

function tf = gen_done(sigPath, direction, tag, mb)
% The file name carries the sample rate, which the scripts compute; match it
% with a wildcard rather than recomputing it here.
tf = ~isempty(dir(fullfile(sigPath, sprintf('5g_%s_%s_osf=*_fs=*MSps_%gMB.bin', direction, tag, mb))));
end

function s = job_label(job)
steps = {};
if job.cdf, steps{end+1} = 'cdf'; end
if ~isempty(job.mb), steps{end+1} = sprintf('gen %g MB', job.mb); end
s = sprintf('%s MCS %2d @ %3d MHz / %3d kHz: %s', job.waveform, job.mcs, job.bw, job.scs, ...
    strjoin(steps, ' + '));
end

function log_line(logID, fmt, varargin)
line = sprintf(fmt, varargin{:});
stamp = char(datetime('now', 'Format', 'yyyy-MM-dd HH:mm:ss'));
fprintf('%s  %s\n', stamp, line);
fprintf(logID, '%s  %s\n', stamp, line);
end

function s = env_str(name, defaultValue)
s = strtrim(getenv(name));
if isempty(s)
    s = defaultValue;
end
end

function c = env_list(name, defaultValue)
raw = strtrim(getenv(name));
if isempty(raw)
    c = defaultValue;
else
    c = strtrim(strsplit(raw, ','));
end
end

function v = env_nums(name, defaultValue)
raw = strtrim(getenv(name));
if isempty(raw)
    v = defaultValue;
else
    v = str2double(strsplit(raw, ','));
    if any(~isfinite(v))
        error('run_5g_all:BadEnv', '%s must be a comma-separated list of numbers, got "%s".', name, raw);
    end
end
end
