%% Measure PAPR targets for every MCS/BW combination and write papr_targets.csv
%
% These are the numbers runGen matches generated waveforms against. They must
% be measured with the SAME definition runGen uses (papr_burst_db), otherwise
% the search loop compares two different quantities and, at the default
% tolerance of 0.05 dB, may never converge.
%
% Results MERGE into any existing papr_targets.csv: only the (standard, mcs,
% bw, mode) rows this run produces are replaced, so a sweep of one standard
% does not discard the others.
%
%   % add Wi-Fi 6 and 7 without redoing Wi-Fi 4 and 5
%   PAPR_TARGET_STANDARDS=he,eht matlab -batch "run('gen_papr_targets.m')"
%
%   % data-field rows only, the mode the PAPR-vs-length study uses
%   PAPR_TARGET_MODES=data matlab -batch "run('gen_papr_targets.m')"
%
%   % just the expensive 320 MHz EHT rows
%   PAPR_TARGET_STANDARDS=eht PAPR_TARGET_BW=320 matlab -batch "run('gen_papr_targets.m')"
%
% Burst length is matched by TIME, not symbol count: HE and EHT use a 16 us
% OFDM symbol against 4 us for HT and VHT, so an equal symbol count would
% compare bursts of very different duration (and 500 HE symbols exceeds the
% 5.484 ms TXOP limit outright).
%
% This is a long run. Cost scales with bandwidth; the EHT 320 MHz rows alone
% are roughly 16x an HT 20 MHz row. Trial counts are scaled down for wide
% channels and every reduction is logged, never silent.

clear variables; close all; clc;
scriptDir = fileparts(mfilename('fullpath'));
addpath(scriptDir);
addpath(fileparts(scriptDir));

baseTrials  = env_num('PAPR_TARGET_TRIALS', 300);
minTrials   = env_num('PAPR_TARGET_MIN_TRIALS', 80);
burstUs     = env_num('PAPR_TARGET_US', 2000);   % 2 ms => 500 HT/VHT symbols
numPackets  = env_num('PAPR_TARGET_PACKETS', 8);
osf         = env_num('PAPR_TARGET_OSF', 4);     % must match the osf runGen uses
idleTime    = 16;                                % microseconds
modes       = split_csv_env('PAPR_TARGET_MODES', {'data', 'full'});

standards = split_csv_env('PAPR_TARGET_STANDARDS', {'ht','vht','he','eht'});
bwFilter  = str2double(split_csv_env('PAPR_TARGET_BW', {}));

% MCS and bandwidth coverage per standard, single spatial stream.
plan = struct( ...
    'ht',  struct('mcs', 0:7,  'bw', [20 40]), ...
    'vht', struct('mcs', 0:9,  'bw', [20 40 80 160]), ...
    'he',  struct('mcs', 0:11, 'bw', [20 40 80 160]), ...
    'eht', struct('mcs', 0:13, 'bw', [20 40 80 160 320]));

rows = {};
for im = 1:numel(modes)
    mode = modes{im};
    measureDataFieldOnly = strcmp(mode, 'data');

    for is = 1:numel(standards)
        std = standards{is};
        if ~isfield(plan, std)
            warning('gen_papr_targets:UnknownStandard', 'Skipping unknown standard "%s".', std);
            continue;
        end
        bwList = plan.(std).bw;
        if ~isempty(bwFilter) && all(isfinite(bwFilter))
            bwList = intersect(bwList, bwFilter, 'stable');
        end

        for bw = bwList
            % Wider channels cost proportionally more samples per trial, so
            % reduce the trial count above 80 MHz. Never scale UP: baseTrials
            % is the count for 80 MHz and narrower.
            trials = max(minTrials, round(baseTrials * min(1, 80/bw)));
            if trials ~= baseTrials
                fprintf('%s %d MHz: %d trials (reduced from %d for bandwidth).\n', ...
                    upper(std), bw, trials, baseTrials);
            end

            for mcs = plan.(std).mcs
                try
                    cfg = papr_std_config(std, bw, mcs, 1);
                catch err
                    fprintf('Skipping %s MCS %d @ %d MHz: %s\n', upper(std), mcs, bw, err.message);
                    continue;
                end

                symbols = floor(burstUs / papr_symbol_us(cfg));
                [octets, nSym] = papr_octets_for_symbols(cfg, symbols, osf);
                cfg = papr_payload(cfg, mcs, octets);

                try
                    row = sweep_one(cfg, std, mcs, bw, mode, measureDataFieldOnly, ...
                        octets, numPackets, osf, idleTime, trials, nSym);
                catch err
                    fprintf('Skipping %s MCS %d @ %d MHz (%s): %s\n', ...
                        upper(std), mcs, bw, mode, err.message);
                    continue;
                end
                rows(end+1,:) = row; %#ok<SAGROW>
            end
        end
    end
end

if isempty(rows)
    error('gen_papr_targets:NoRows', 'The sweep produced no rows; check the filters.');
end

Tnew = cell2table(rows, 'VariableNames', ...
    {'standard','mcs','bw','mode','mean_db','std_db','max_db','preamble_frac','trials'});

outPath = fullfile(scriptDir, 'papr_targets.csv');
if isfile(outPath)
    Told = readtable(outPath, 'TextType', 'char');
    keyOld = strcat(string(Told.standard), '|', string(Told.mcs), '|', ...
                    string(Told.bw), '|', string(Told.mode));
    keyNew = strcat(string(Tnew.standard), '|', string(Tnew.mcs), '|', ...
                    string(Tnew.bw), '|', string(Tnew.mode));
    replaced = ismember(keyOld, keyNew);
    fprintf('\nMerging: %d existing rows kept, %d replaced, %d added.\n', ...
        sum(~replaced), sum(replaced), height(Tnew) - sum(replaced));
    Told(replaced, :) = [];
    T = [Told; Tnew];
else
    T = Tnew;
end

T = sortrows(T, {'standard','bw','mcs','mode'});
writetable(T, outPath);
fprintf('Wrote %d rows to %s\n', height(T), outPath);

function row = sweep_one(cfg, standard, mcs, bw, mode, measureDataFieldOnly, ...
                         octets, numPackets, osf, idleTime, trials, nSym)
streamPlan = papr_stream_plan(cfg, osf, idleTime, measureDataFieldOnly);
papr_db = zeros(trials,1);
inPreamble = false(trials,1);
seeds = randi([1 127], trials, 1);

% Chunked generation: at 320 MHz an eight-packet burst is several hundred
% megabytes, on every parallel worker at once. papr_burst_stream_db reduces
% it over the same sample set papr_burst_db uses on an assembled burst, so
% the targets written here stay comparable with the rows already in
% papr_targets.csv and with what the runGen sections measure.
parfor t = 1:trials
    [papr_db(t), inPreamble(t)] = papr_burst_stream_db(cfg, octets, ...
        numPackets, seeds(t), streamPlan);
end

papr_db = papr_db(isfinite(papr_db));
row = {standard, mcs, bw, mode, mean(papr_db), std(papr_db), max(papr_db), ...
       mean(inPreamble), numel(papr_db)};
fprintf('%-4s MCS %-2d @ %3d MHz (%-4s): %3d sym, mean=%.3f std=%.4f preamblePinned=%3.0f%%\n', ...
    upper(standard), mcs, bw, mode, nSym, row{5}, row{6}, 100*row{8});
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
