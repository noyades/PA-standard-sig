function run_wifi_all(varargin)
%RUN_WIFI_ALL Generate every WiFi signal file and remove the stale ones.
%   RUN_WIFI_ALL() runs the signal-generation step of pa_wifi_ht, pa_wifi_vht,
%   pa_wifi_he and pa_wifi_eht for every (MCS, bandwidth) that has a row in
%   papr_targets.csv, at 4 and 8 MB, in one MATLAB session so the parallel
%   pool stays warm. Files that already exist under their current name are
%   skipped, so the sweep can be stopped and restarted. Each file runs in
%   its own try/catch: one failure is logged and the sweep moves on.
%
%   Afterwards it deletes stale files: any .bin in the four signal folders
%   whose name is not the current one (e.g. the older 4x "osf=4" exports, or
%   odd sizes such as 7.617188e+00MB). A stale file is only removed once
%   every current file for its (standard, MCS, bandwidth) exists, so a
%   failed or interrupted run never leaves a combination with nothing.
%   Deleted files remain in git history.
%
%   The scripts are run unchanged, in the base workspace, with their PAPR_*
%   environment overrides set per file. They begin with "clear variables",
%   which is why this is a function and why they go through evalin('base').
%
%   RUN_WIFI_ALL(NAME, VALUE, ...) narrows the sweep:
%     'Standards'  Any of {'ht', 'vht', 'he', 'eht'}. Default all four.
%     'MB'         File sizes. Default [4 8].
%     'BW'         Keep only these bandwidths. Default all.
%     'MCS'        Keep only these MCS indices. Default all.
%     'Force'      true regenerates files that exist. Default false.
%     'Clean'      false keeps stale files. Default true.
%     'Plots'      Constellation plots. Default true from the desktop, false
%                  under matlab -batch, where rendering crashes MATLAB on
%                  some machines (exit 0x8f).
%     'DryRun'     true prints the plan, including what would be deleted,
%                  and runs nothing. Default false.
%
%   Every option is also readable from the shell as PAPR_ALL_<NAME>
%   (PAPR_ALL_STANDARDS, PAPR_ALL_MB, PAPR_ALL_BW, PAPR_ALL_MCS,
%   PAPR_ALL_FORCE, PAPR_ALL_CLEAN, PAPR_ALL_PLOTS, PAPR_ALL_DRYRUN), lists
%   comma-separated:
%
%     matlab -batch "run_wifi_all('DryRun', true)"
%     matlab -batch "run_wifi_all('Standards', {'he','eht'}, 'MB', 8)"
%     PAPR_ALL_STANDARDS=vht PAPR_ALL_BW=20 matlab -batch "run_wifi_all"
%
%   The export rate follows PAPR_EXPORT_OSF and PAPR_MAX_FS_MHZ (see
%   PAPR_EXPORT_RATE); they are read here too, so the expected file names
%   match what the scripts write.
%
%   Progress goes to run_wifi_all.log next to this file as well as the
%   command window; the scripts clear the command window on every run, so
%   the log is the record.
%
%   See also PA_WIFI_HT, PA_WIFI_VHT, PA_WIFI_HE, PA_WIFI_EHT,
%   PAPR_EXPORT_RATE, RUN_5G_ALL.

scriptDir = fileparts(mfilename('fullpath'));
addpath(scriptDir);
addpath(fileparts(scriptDir));
repoRoot = fileparts(fileparts(scriptDir));
sigRoot = fullfile(repoRoot, 'Signals', 'Multi Carrier', 'WiFi');

opt = parse_options(varargin{:});
[~, modeTag] = papr_measure_mode(true);

% Per standard: generator script, signal folder, file prefix. HT names
% also carry the guard interval, which the script picks; match it with *.
info = struct( ...
    'ht',  struct('script', 'pa_wifi_ht.m',  'folder', '802.11N (WiFi4)',  'prefix', 'wifi4', 'gi', '_GI=*'), ...
    'vht', struct('script', 'pa_wifi_vht.m', 'folder', '802.11AC (WiFi5)', 'prefix', 'wifi5', 'gi', ''), ...
    'he',  struct('script', 'pa_wifi_he.m',  'folder', '802.11AX (WiFi6)', 'prefix', 'wifi6', 'gi', ''), ...
    'eht', struct('script', 'pa_wifi_eht.m', 'folder', '802.11BE (WiFi7)', 'prefix', 'wifi7', 'gi', ''));

% The targets table defines which combinations exist (it already leaves
% out invalid ones such as VHT MCS 9 at 20 MHz).
targets = readtable(fullfile(scriptDir, 'papr_targets.csv'), 'TextType', 'string');
targets = targets(targets.mode == modeTag, :);

logPath = fullfile(scriptDir, 'run_wifi_all.log');
logID = fopen(logPath, 'a');
if logID < 0
    error('run_wifi_all:CannotLog', 'Could not open %s for writing.', logPath);
end
cleanupLog = onCleanup(@() fclose(logID));
say = @(varargin) log_line(logID, varargin{:});

% Build the plan.
jobs = struct('std', {}, 'mcs', {}, 'bw', {}, 'mb', {}, 'pattern', {});
combos = struct('std', {}, 'mcs', {}, 'bw', {}, 'patterns', {});
nSkipped = 0;
for is = 1:numel(opt.Standards)
    sd = opt.Standards{is};
    I = info.(sd);
    folder = fullfile(sigRoot, I.folder);
    rows = targets(targets.standard == sd, :);
    pairs = unique([rows.mcs rows.bw], 'rows');
    if ~isempty(opt.BW),  pairs = pairs(ismember(pairs(:,2), opt.BW), :);  end
    if ~isempty(opt.MCS), pairs = pairs(ismember(pairs(:,1), opt.MCS), :); end
    for ip = 1:size(pairs, 1)
        mcs = pairs(ip, 1); bw = pairs(ip, 2);
        pats = cell(1, numel(opt.MB));
        for im = 1:numel(opt.MB)
            mb = opt.MB(im);
            ex = papr_export_rate(bw*1e6, 4*bw*1e6, mb*1024*1024/8);
            pats{im} = sprintf('%s_mcs=%d_bw=%d%s_osf=%g_%dMB.bin', I.prefix, mcs, bw, I.gi, ex.osf, mb);
            if opt.Force || isempty(dir(fullfile(folder, pats{im})))
                jobs(end+1) = struct('std', sd, 'mcs', mcs, 'bw', bw, 'mb', mb, 'pattern', pats{im}); %#ok<AGROW>
            else
                nSkipped = nSkipped + 1;
            end
        end
        combos(end+1) = struct('std', sd, 'mcs', mcs, 'bw', bw, 'patterns', {pats}); %#ok<AGROW>
    end
end

say('run_wifi_all: %d file(s) to generate, %d already current (standards=%s, MB=[%s], mode=%s, plots=%d).', ...
    numel(jobs), nSkipped, strjoin(opt.Standards, ','), num2str(opt.MB), modeTag, opt.Plots);

if opt.DryRun
    for j = 1:numel(jobs)
        say('  generate %s', job_label(jobs(j)));
    end
    if opt.Clean
        clean_stale(combos, info, sigRoot, opt.Standards, true, say);
    end
    say('Dry run; nothing executed.');
    return;
end

% Save the environment the scripts read so the sweep leaves it as found.
envNames = {'PAPR_RUN_ALL', 'PAPR_RUN_LONG', 'PAPR_RUN_STATS', 'PAPR_RUN_CDF', ...
            'PAPR_RUN_GEN', 'PAPR_BW', 'PAPR_MCS', 'PAPR_MB', 'PAPR_GEN_PLOT'};
envSaved = cellfun(@getenv, envNames, 'UniformOutput', false);
cleanupEnv = onCleanup(@() cellfun(@setenv, envNames, envSaved));

setenv('PAPR_RUN_ALL', '0');
setenv('PAPR_RUN_LONG', '0');
setenv('PAPR_RUN_STATS', '0');
setenv('PAPR_RUN_CDF', '0');
setenv('PAPR_RUN_GEN', '1');
setenv('PAPR_GEN_PLOT', num2str(double(opt.Plots)));
nOk = 0; nFail = 0;
tSweep = tic;
for j = 1:numel(jobs)
    job = jobs(j);
    I = info.(job.std);
    setenv('PAPR_BW',  num2str(job.bw));
    setenv('PAPR_MCS', num2str(job.mcs));
    setenv('PAPR_MB',  num2str(job.mb));

    say('[%d/%d] start %s', j, numel(jobs), job_label(job));
    tJob = tic;
    try
        evalin('base', sprintf('run(''%s'');', ...
            strrep(fullfile(scriptDir, I.script), '''', '''''')));
        % The scripts warn rather than error when no burst matches the
        % PAPR target, so confirm the file is actually there.
        if isempty(dir(fullfile(sigRoot, I.folder, job.pattern)))
            error('run_wifi_all:NoFile', 'The script finished but wrote no %s.', job.pattern);
        end
        nOk = nOk + 1;
        say('[%d/%d] done  %s (%.1f min)', j, numel(jobs), job_label(job), toc(tJob)/60);
    catch err
        nFail = nFail + 1;
        say('[%d/%d] FAIL  %s (%.1f min): %s', j, numel(jobs), job_label(job), ...
            toc(tJob)/60, strrep(err.message, newline, ' '));
    end
    close all force;   % plots left open by the scripts would pile up
end
say('run_wifi_all finished generating: %d ok, %d failed, %.1f h total.', ...
    nOk, nFail, toc(tSweep)/3600);

if opt.Clean
    clean_stale(combos, info, sigRoot, opt.Standards, false, say);
end
say('Log: %s', logPath);
end

%% ------------------------------------------------------------------------
function clean_stale(combos, info, sigRoot, standards, dryRun, say)
% Delete .bin files that are not a current name, but only for combinations
% whose current files all exist. Only the standards in this sweep are
% touched, and only the top level of each folder (lab_osr_test etc. stay).
nDel = 0; nKept = 0;
for is = 1:numel(standards)
    sd = standards{is};
    I = info.(sd);
    folder = fullfile(sigRoot, I.folder);
    files = dir(fullfile(folder, [I.prefix '_mcs=*_bw=*.bin']));
    for f = 1:numel(files)
        name = files(f).name;
        tok = regexp(name, '_mcs=(\d+)_bw=(\d+)_', 'tokens', 'once');
        if isempty(tok), continue; end
        mcs = str2double(tok{1}); bw = str2double(tok{2});
        c = combos(strcmp({combos.std}, sd) & [combos.mcs] == mcs & [combos.bw] == bw);
        if isempty(c), continue; end            % outside this sweep's filters
        current = any(cellfun(@(p) matches_glob(name, p), c.patterns));
        % Same export rate at another size counts as current too.
        osfTag = regexp(c.patterns{1}, '_osf=[^_]+_', 'match', 'once');
        if current || contains(name, osfTag), continue; end
        complete = all(cellfun(@(p) ~isempty(dir(fullfile(folder, p))), c.patterns));
        if ~complete
            nKept = nKept + 1;
            say('  keep   %s (its replacement is not complete yet)', name);
            continue;
        end
        if dryRun
            say('  delete %s', name);
        else
            delete(fullfile(folder, name));
            say('  deleted %s', name);
        end
        nDel = nDel + 1;
    end
end
if dryRun
    say('Clean: %d stale file(s) would be deleted, %d kept until replaced.', nDel, nKept);
else
    say('Clean: %d stale file(s) deleted, %d kept until replaced.', nDel, nKept);
end
end

function tf = matches_glob(name, pattern)
rx = ['^' strrep(regexptranslate('escape', pattern), '\*', '.*') '$'];
tf = ~isempty(regexp(name, rx, 'once'));
end

function s = job_label(job)
s = sprintf('%-3s MCS %2d @ %3d MHz, %g MB -> %s', upper(job.std), job.mcs, job.bw, job.mb, job.pattern);
end

function opt = parse_options(varargin)
p = inputParser;
p.FunctionName = 'run_wifi_all';
addParameter(p, 'Standards', env_list('PAPR_ALL_STANDARDS', {'ht', 'vht', 'he', 'eht'}));
addParameter(p, 'MB',        env_nums('PAPR_ALL_MB', [4 8]));
addParameter(p, 'BW',        env_nums('PAPR_ALL_BW', []));
addParameter(p, 'MCS',       env_nums('PAPR_ALL_MCS', []));
addParameter(p, 'Force',     env_num('PAPR_ALL_FORCE', 0) ~= 0);
addParameter(p, 'Clean',     env_num('PAPR_ALL_CLEAN', 1) ~= 0);
addParameter(p, 'Plots',     env_num('PAPR_ALL_PLOTS', double(~batchStartupOptionUsed)) ~= 0);
addParameter(p, 'DryRun',    env_num('PAPR_ALL_DRYRUN', 0) ~= 0);
parse(p, varargin{:});
opt = p.Results;

opt.Standards = lower(cellstr(opt.Standards));
if ~all(ismember(opt.Standards, {'ht', 'vht', 'he', 'eht'}))
    error('run_wifi_all:BadStandard', 'Standards must be any of ht, vht, he, eht.');
end
validateattributes(opt.MB, {'numeric'}, {'vector', 'positive', 'integer'}, 'run_wifi_all', 'MB');
opt.MB = opt.MB(:)';
opt.BW = opt.BW(:)';
opt.MCS = opt.MCS(:)';
end

function log_line(logID, fmt, varargin)
line = sprintf(fmt, varargin{:});
stamp = char(datetime('now', 'Format', 'yyyy-MM-dd HH:mm:ss'));
fprintf('%s  %s\n', stamp, line);
fprintf(logID, '%s  %s\n', stamp, line);
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
        error('run_wifi_all:BadEnv', '%s must be a comma-separated list of numbers, got "%s".', name, raw);
    end
end
end
