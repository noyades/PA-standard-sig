%% Measure 5G NR PAPR targets and write papr_5g_targets.csv
%
% These are the numbers the runGen sections of pa_5G_dl / pa_5G_ul match
% generated waveforms against. They are measured with the SAME definition
% those scripts use (papr_burst_db through the range-form sample map of
% papr_5g_meta), otherwise the search loop compares two different quantities
% and, at the default tolerance of 0.05 dB, may never converge.
%
% Results MERGE into any existing papr_5g_targets.csv, one row at a time:
% every (direction, waveform, MCS table, MCS, BW, SCS, mode) row is written
% to the file the moment it is measured, so an interrupted run keeps what it
% finished, and a sweep of one direction does not discard the other.
%
% Restarting RESUMES: rows whose key is already in the file are skipped.
% Set PAPR_TARGET_FORCE=1 to re-measure and replace them (for instance after
% changing PAPR_TARGET_TRIALS or PAPR_TARGET_MS).
%
%   % uplink only, both waveform types
%   PAPR_TARGET_DIRS=ul matlab -batch "run('gen_papr_5g_targets.m')"
%
%   % data-field rows for the FR2 combinations only
%   PAPR_TARGET_MODES=data PAPR_TARGET_SCS=120 matlab -batch "run('gen_papr_5g_targets.m')"
%
%   % one MCS at 100 MHz / 30 kHz, quick check
%   PAPR_TARGET_MCS=20 PAPR_TARGET_BW=100 PAPR_TARGET_SCS=30 matlab -batch "run('gen_papr_5g_targets.m')"
%
% Every trial is a burst of PAPR_TARGET_MS milliseconds (default 8, matching
% the eight-packet WLAN bursts in duration), generated a few subframes at a
% time by papr_burst_stream_db so the per-worker memory never scales with
% the burst length.
%
% This is a long run: 29 MCS x 2 modes per (direction, waveform, BW, SCS)
% combination. Trial counts are scaled down for wide channels and every
% reduction is logged, never silent.

clear variables; close all; clc;
scriptDir = fileparts(mfilename('fullpath'));
addpath(scriptDir);
addpath(fullfile(fileparts(scriptDir), 'WiFi'));
addpath(fileparts(scriptDir));

baseTrials = env_num('PAPR_TARGET_TRIALS', 300);
minTrials  = env_num('PAPR_TARGET_MIN_TRIALS', 80);
burstMs    = env_num('PAPR_TARGET_MS', 8);
osf        = env_num('PAPR_TARGET_OSF', 4);     % must match the osf runGen uses
force      = env_num('PAPR_TARGET_FORCE', 0) ~= 0;
modes      = split_csv_env('PAPR_TARGET_MODES', {'data', 'full'});
dirs       = split_csv_env('PAPR_TARGET_DIRS', {'dl', 'ul'});
wfFilter   = split_csv_env('PAPR_TARGET_WAVEFORMS', {});
mcsTable   = upper(char(split_csv_env('PAPR_TARGET_MCS_TABLE', {'64QAM'})));
bwFilter   = str2double(split_csv_env('PAPR_TARGET_BW', {}));
scsFilter  = str2double(split_csv_env('PAPR_TARGET_SCS', {}));
mcsFilter  = str2double(split_csv_env('PAPR_TARGET_MCS', {}));

% Channel coverage: (SCS kHz, BW MHz) pairs, shared with run_5g_all so the
% table always covers what the generators ask for.
combos = papr_5g_combos();
mcsAll = 0:28;                       % the 64QAM tables; 256QAM stops at 27
if strcmp(mcsTable, '256QAM')
    mcsAll = 0:27;
end
if ~isempty(mcsFilter) && all(isfinite(mcsFilter))
    mcsAll = intersect(mcsAll, mcsFilter, 'stable');
end

% mcs_table is the TS 38.214 table the index was resolved against ('64QAM'
% or '256QAM'); modulation and code_rate are what that index means in it.
varNames = {'direction','waveform','mcs_table','mcs','modulation','code_rate', ...
            'bw','scs','mode','mean_db','std_db','max_db','outside_frac','trials'};
outPath = fullfile(scriptDir, 'papr_5g_targets.csv');
if isfile(outPath)
    T = backfill_columns(readtable(outPath, 'TextType', 'char'), varNames);
    if force
        fprintf('%d rows in %s; PAPR_TARGET_FORCE set, rows in this sweep will be re-measured.\n', ...
            height(T), outPath);
    else
        fprintf('%d rows in %s; rows already present are skipped (PAPR_TARGET_FORCE=1 to redo).\n', ...
            height(T), outPath);
    end
else
    T = [];
end

nMeasured = 0;
nSkipped  = 0;
for im = 1:numel(modes)
    mode = modes{im};
    measureDataFieldOnly = strcmp(mode, 'data');

    for id = 1:numel(dirs)
        direction = dirs{id};
        if strcmp(direction, 'ul')
            waveforms = {'cp-ofdm', 'dft-s-ofdm'};
        else
            waveforms = {'cp-ofdm'};
        end
        if ~isempty(wfFilter)
            waveforms = intersect(waveforms, wfFilter, 'stable');
        end

        for iw = 1:numel(waveforms)
            waveform = waveforms{iw};
            opts = struct('MCSTable', mcsTable, ...
                          'TransformPrecoding', strcmp(waveform, 'dft-s-ofdm'));

            for ic = 1:size(combos, 1)
                scs = combos(ic, 1); bw = combos(ic, 2);
                if ~isempty(bwFilter) && all(isfinite(bwFilter)) && ~ismember(bw, bwFilter)
                    continue;
                end
                if ~isempty(scsFilter) && all(isfinite(scsFilter)) && ~ismember(scs, scsFilter)
                    continue;
                end

                % Wider channels cost proportionally more samples per trial;
                % reduce the trial count above 80 MHz, never scale up.
                trials = max(minTrials, round(baseTrials * min(1, 80/bw)));
                if trials ~= baseTrials
                    fprintf('%s %s %d MHz / %d kHz: %d trials (reduced from %d for bandwidth).\n', ...
                        upper(direction), waveform, bw, scs, trials, baseTrials);
                end

                for mcs = mcsAll
                    key = key_of(direction, waveform, mcsTable, mcs, bw, scs, mode);
                    if ~force && ~isempty(T) && any(row_key(T) == key)
                        nSkipped = nSkipped + 1;
                        continue;
                    end
                    try
                        [cfg, info] = papr_5g_config(direction, bw, scs, mcs, osf, opts);
                        streamPlan = papr_5g_stream_plan(cfg, info, measureDataFieldOnly);
                    catch err
                        fprintf('Skipping %s %s MCS %d @ %d MHz / %d kHz: %s\n', ...
                            upper(direction), waveform, mcs, bw, scs, err.message);
                        continue;
                    end
                    nUnits = max(1, round(burstMs / streamPlan.meta.subframesPerUnit));

                    try
                        row = sweep_one(streamPlan, direction, waveform, mcsTable, mcs, bw, scs, ...
                            mode, nUnits, trials, info);
                    catch err
                        fprintf('Skipping %s %s MCS %d @ %d MHz / %d kHz (%s): %s\n', ...
                            upper(direction), waveform, mcs, bw, scs, mode, err.message);
                        continue;
                    end
                    % Write immediately so an interruption keeps this row.
                    T = upsert_row(T, row, varNames);
                    write_atomic(T, outPath);
                    nMeasured = nMeasured + 1;
                end
            end
        end
    end
end

if nMeasured == 0 && nSkipped == 0
    error('gen_papr_5g_targets:NoRows', 'The sweep produced no rows; check the filters.');
end
fprintf('\nDone: %d row(s) measured this run, %d skipped as already present; %s holds %d rows.\n', ...
    nMeasured, nSkipped, outPath, height(T));

function row = sweep_one(streamPlan, direction, waveform, mcsTable, mcs, bw, scs, ...
                         mode, nUnits, trials, info)
papr_db = zeros(trials,1);
outside = false(trials,1);
seeds = randi([1 2^20], trials, 1);

parfor t = 1:trials
    [papr_db(t), outside(t)] = papr_burst_stream_db([], [], nUnits, seeds(t), streamPlan);
end

papr_db = papr_db(isfinite(papr_db));
row = {direction, waveform, mcsTable, mcs, info.modulation, info.codeRate, bw, scs, mode, ...
       mean(papr_db), std(papr_db), max(papr_db), mean(outside), numel(papr_db)};
fprintf('%s %-10s MCS %-2d (%s R=%.3f) @ %3d MHz / %3d kHz (%-4s): %d ms, mean=%.3f std=%.4f outsideData=%3.0f%%\n', ...
    upper(direction), waveform, mcs, info.modulation, info.codeRate, bw, scs, mode, ...
    nUnits * streamPlan.meta.subframesPerUnit, row{10}, row{11}, 100*row{13});
end

function key = row_key(T)
%ROW_KEY One key string per table row, in the form KEY_OF produces.
if isempty(T)
    key = strings(0, 1);
    return;
end
key = key_of(T.direction, T.waveform, T.mcs_table, T.mcs, T.bw, T.scs, T.mode);
end

function key = key_of(direction, waveform, mcsTable, mcs, bw, scs, mode)
%KEY_OF The identity of a target row: everything but the measured numbers.
key = strcat(lower(string(direction)), '|', lower(string(waveform)), '|', ...
             upper(string(mcsTable)), '|', string(mcs), '|', string(bw), '|', ...
             string(scs), '|', lower(string(mode)));
end

function T = backfill_columns(T, varNames)
%BACKFILL_COLUMNS Bring a table written by an earlier version of this
%   script up to the current column set. modulation and code_rate follow
%   from (mcs_table, mcs, waveform) alone, so they are filled in rather
%   than re-measured.
if ~ismember('modulation', T.Properties.VariableNames)
    modulation = cell(height(T), 1);
    codeRate = zeros(height(T), 1);
    for r = 1:height(T)
        [modulation{r}, codeRate(r)] = papr_5g_mcs(T.mcs(r), T.mcs_table{r}, ...
            strcmpi(T.waveform{r}, 'dft-s-ofdm'));
    end
    T.modulation = modulation;
    T.code_rate = codeRate;
    fprintf('Added modulation and code_rate columns to %d existing rows.\n', height(T));
end
missing = setdiff(varNames, T.Properties.VariableNames);
if ~isempty(missing)
    error('gen_papr_5g_targets:BadTable', 'papr_5g_targets.csv lacks column(s): %s', ...
        strjoin(missing, ', '));
end
T = T(:, varNames);
end

function T = upsert_row(T, row, varNames)
%UPSERT_ROW Replace the row with the same key, or append, and keep the
%   table sorted so the file is stable regardless of sweep order.
Tnew = cell2table(row, 'VariableNames', varNames);
if isempty(T)
    T = Tnew;
else
    T(row_key(T) == row_key(Tnew), :) = [];
    T = [T; Tnew];
end
T = sortrows(T, {'direction','waveform','mcs_table','scs','bw','mcs','mode'});
end

function write_atomic(T, outPath)
%WRITE_ATOMIC Write to a sibling temp file and rename over the target, so
%   an interruption during the write never leaves a truncated CSV behind.
tmpPath = [outPath '.tmp'];
writetable(T, tmpPath, 'FileType', 'text', 'Delimiter', ',');
[ok, msg] = movefile(tmpPath, outPath, 'f');
if ~ok
    error('gen_papr_5g_targets:WriteFailed', 'Could not update %s: %s', outPath, msg);
end
end

function out = split_csv_env(name, defaultValue)
%SPLIT_CSV_ENV Comma-separated environment override as a cellstr.
raw = strtrim(getenv(name));
if isempty(raw)
    out = defaultValue;
    return;
end
out = strtrim(strsplit(lower(raw), ','));
out = out(~cellfun(@isempty, out));
end
