%% Measure 5G NR PAPR targets and write papr_5g_targets.csv
%
% These are the numbers the runGen sections of pa_5G_dl / pa_5G_ul match
% generated waveforms against. They are measured with the SAME definition
% those scripts use (papr_burst_db through the range-form sample map of
% papr_5g_meta), otherwise the search loop compares two different quantities
% and, at the default tolerance of 0.05 dB, may never converge.
%
% Results MERGE into any existing papr_5g_targets.csv: only the rows this
% run produces (same direction, waveform, MCS table, MCS, BW, SCS, mode) are
% replaced, so a sweep of one direction does not discard the other.
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
modes      = split_csv_env('PAPR_TARGET_MODES', {'data', 'full'});
dirs       = split_csv_env('PAPR_TARGET_DIRS', {'dl', 'ul'});
wfFilter   = split_csv_env('PAPR_TARGET_WAVEFORMS', {});
mcsTable   = upper(char(split_csv_env('PAPR_TARGET_MCS_TABLE', {'64QAM'})));
bwFilter   = str2double(split_csv_env('PAPR_TARGET_BW', {}));
scsFilter  = str2double(split_csv_env('PAPR_TARGET_SCS', {}));
mcsFilter  = str2double(split_csv_env('PAPR_TARGET_MCS', {}));

% Channel coverage: (SCS kHz, BW MHz) pairs, FR1 at 15/30 kHz, FR2 at 120.
combos = [ 15  5;  15 10;  15 20; ...
           30 20;  30 50;  30 100; ...
          120 100; 120 200; 120 400];
mcsAll = 0:28;                       % the 64QAM tables; 256QAM stops at 27
if strcmp(mcsTable, '256QAM')
    mcsAll = 0:27;
end
if ~isempty(mcsFilter) && all(isfinite(mcsFilter))
    mcsAll = intersect(mcsAll, mcsFilter, 'stable');
end

rows = {};
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
                    rows(end+1,:) = row; %#ok<SAGROW>
                end
            end
        end
    end
end

if isempty(rows)
    error('gen_papr_5g_targets:NoRows', 'The sweep produced no rows; check the filters.');
end

Tnew = cell2table(rows, 'VariableNames', ...
    {'direction','waveform','mcs_table','mcs','bw','scs','mode', ...
     'mean_db','std_db','max_db','outside_frac','trials'});

outPath = fullfile(scriptDir, 'papr_5g_targets.csv');
if isfile(outPath)
    Told = readtable(outPath, 'TextType', 'char');
    keyOld = row_key(Told);
    keyNew = row_key(Tnew);
    replaced = ismember(keyOld, keyNew);
    fprintf('\nMerging: %d existing rows kept, %d replaced, %d added.\n', ...
        sum(~replaced), sum(replaced), height(Tnew) - sum(replaced));
    Told(replaced, :) = [];
    T = [Told; Tnew];
else
    T = Tnew;
end

T = sortrows(T, {'direction','waveform','mcs_table','scs','bw','mcs','mode'});
writetable(T, outPath);
fprintf('Wrote %d rows to %s\n', height(T), outPath);

function row = sweep_one(streamPlan, direction, waveform, mcsTable, mcs, bw, scs, ...
                         mode, nUnits, trials, info)
papr_db = zeros(trials,1);
outside = false(trials,1);
seeds = randi([1 2^20], trials, 1);

parfor t = 1:trials
    [papr_db(t), outside(t)] = papr_burst_stream_db([], [], nUnits, seeds(t), streamPlan);
end

papr_db = papr_db(isfinite(papr_db));
row = {direction, waveform, mcsTable, mcs, bw, scs, mode, mean(papr_db), std(papr_db), ...
       max(papr_db), mean(outside), numel(papr_db)};
fprintf('%s %-10s MCS %-2d (%s R=%.3f) @ %3d MHz / %3d kHz (%-4s): %d ms, mean=%.3f std=%.4f outsideData=%3.0f%%\n', ...
    upper(direction), waveform, mcs, info.modulation, info.codeRate, bw, scs, mode, ...
    nUnits * streamPlan.meta.subframesPerUnit, row{8}, row{9}, 100*row{11});
end

function key = row_key(T)
key = strcat(lower(string(T.direction)), '|', lower(string(T.waveform)), '|', ...
             upper(string(T.mcs_table)), '|', string(T.mcs), '|', string(T.bw), '|', ...
             string(T.scs), '|', lower(string(T.mode)));
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
