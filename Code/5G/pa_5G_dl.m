%% This simulation encapsulates data analysis for 5G NR downlink signals
%  (3GPP TS 38.211/38.214, one PDSCH filling the carrier).
%
%  Structure mirrors pa_wifi_eht.m. The measurement helpers (papr_burst_db,
%  papr_burst_stream_db, papr_density, ...) are shared with the four 802.11
%  scripts, and the NR sample map (papr_5g_meta) feeds them in the same
%  range form, so NR and WLAN results are directly comparable.
%
%  Note on burst length: the NR unit of airtime is the subframe (1 ms, 14 x
%  2^mu OFDM symbols), not the packet. The PAPR-versus-length sweep below is
%  therefore over burst duration in subframes, and a "packet" in the shared
%  helpers is one repeating unit of the slot pattern (one subframe unless a
%  TDD-style SlotAllocation/Period is configured).
%
%  Note on measurement mode: 'data' measures the PDSCH symbols only. The
%  2-symbol CORESET/PDCCH at the start of each slot and the DM-RS symbol are
%  excluded, the way the 802.11 preamble is. The SS burst is not excluded:
%  PDSCH is rate-matched around it, so it shares symbols 2-5 with data once
%  per 20 ms. Set PAPR_SSB=0 for a pure PDSCH carrier.
%
%  Note on sample rate: nrWaveformGenerator runs at Nfft x SCS, which is not
%  bandwidth x osf. 100 MHz at 30 kHz is 122.88 MS/s, so the exported file
%  name carries fs explicitly and a .json sidecar records the configuration.
%
%  Deferred: the receiver / EVM check that closes the 802.11 scripts
%  (nrPDSCHDecode chain) is not yet implemented here.

clear variables; close all; clc;
scriptDir = fileparts(mfilename('fullpath'));
addpath(scriptDir);
addpath(fullfile(fileparts(scriptDir), 'WiFi'));   % shared papr_* helpers
addpath(fileparts(scriptDir));                     % plot_generic, plot_bar
repoRoot = fileparts(fileparts(scriptDir));

sigPath = fullfile(repoRoot, 'Signals', 'Multi Carrier', '5G NR', 'Downlink');
figPath = fullfile(repoRoot, 'Figures', '5G NR', 'Downlink');

% Control which elements of the code run. Each is overridable from the shell
% (e.g. PAPR_RUN_CDF=1) so a sweep needs no edits to this file.
runAll = env_num('PAPR_RUN_ALL', 0);
runCdf = env_num('PAPR_RUN_CDF', 1); % CCDF of the PAPR as a function of burst duration
runGen = env_num('PAPR_RUN_GEN', 1); % Generates signals for loading on signal generators

direction = 'dl';
waveform = 'cp-ofdm';                % downlink is always CP-OFDM
osf = 4;                             % Oversampling factor (SampleRate = osf x Nfft x SCS)

% Carrier and options, all shell-overridable.
BW  = env_num('PAPR_BW', 100);       % MHz
SCS = env_num('PAPR_SCS', 30);       % kHz
MCS = env_num('PAPR_MCS', 20);       % TS 38.214 index; 20 is 64QAM R=567/1024
cfgOpts = struct( ...
    'MCSTable',       upper(env_str('PAPR_MCS_TABLE', '64QAM')), ...
    'FrequencyRange', upper(env_str('PAPR_FR', '')), ...
    'SSB',            env_num('PAPR_SSB', 1) ~= 0, ...
    'PDCCH',          env_num('PAPR_PDCCH', 1) ~= 0);
tagOf = @(mcs, bw, scs) sprintf('mcs=%d_bw=%d_scs=%d', mcs, bw, scs);

%% ------------------------------------------------------------------------
% PAPR as a function of burst duration
if runCdf || runAll
    bins = 50;
    statsOSF = 4;
    [measureDataFieldOnly, modeTag] = papr_measure_mode(true);
    kernelBw = []; % [] => Silverman's rule from the pooled samples

    targetSubframes = [1 5 10];      % ms; 10 ms is one radio frame
    list = [500, 500, 500];
    trialOverride = str2double(getenv('PAPR_TRIALS'));
    if isfinite(trialOverride) && trialOverride > 0
        list = repmat(round(trialOverride), size(targetSubframes));
    end

    [cfgNR, info] = papr_5g_config(direction, BW, SCS, MCS, statsOSF, cfgOpts);
    fprintf('runCdf start: mode=%s, %s %s, MCS=%d (%s R=%.3f), BW=%d MHz, SCS=%d kHz, %d RB, fs=%.2f MS/s, trials=[%s]\n', ...
        modeTag, upper(direction), waveform, MCS, info.modulation, info.codeRate, BW, SCS, ...
        info.nrb, info.fs/1e6, num2str(list));

    % One plan serves every burst length: the sample map does not depend on
    % how many units are strung together.
    streamPlan = papr_5g_stream_plan(cfgNR, info, measureDataFieldOnly);
    spu = streamPlan.meta.subframesPerUnit;

    paprSamples = cell(1, numel(targetSubframes));
    outsideData = zeros(1, numel(targetSubframes));
    achieved    = zeros(1, numel(targetSubframes));

    for ib = 1:numel(targetSubframes)
        nUnits = max(1, round(targetSubframes(ib) / spu));
        achieved(ib) = nUnits * spu;
        trials = list(ib);
        papr_db = zeros(trials, 1);
        outside = false(trials, 1);
        randomSeed = randi([1 2^20], trials, 1);

        % Chunked generation for the reason given in the 802.11 scripts: a
        % 400 MHz subframe at 4x oversampling is 2e6 samples, and ten of them
        % on every worker at once is what exhausts memory.
        progress = papr_progress(sprintf('runCdf %s %d ms', upper(direction), achieved(ib)), ...
            trials, 'StartPool', true);
        dq = progress.queue;
        parfor t = 1:trials
            [papr_db(t), outside(t)] = papr_burst_stream_db([], [], nUnits, ...
                randomSeed(t), streamPlan);
            if ~isempty(dq)
                send(dq, 1);
            end
        end
        progress.finish();

        paprSamples{ib} = papr_db(isfinite(papr_db));
        outsideData(ib) = mean(outside);
        fprintf('  %3d ms: n=%4d  mean=%.3f dB  std=%.4f dB  span=[%.2f %.2f] dB  maxOutsideData=%.0f%%\n', ...
            achieved(ib), numel(paprSamples{ib}), mean(paprSamples{ib}), ...
            std(paprSamples{ib}), min(paprSamples{ib}), max(paprSamples{ib}), ...
            100*outsideData(ib));
    end
    if ~measureDataFieldOnly && any(outsideData > 0.05)
        warning('pa_5G:OutsideDataPAPR', ...
            ['The burst maximum landed outside the PDSCH symbols (SSB, PDCCH or ' ...
             'DM-RS) for up to %.0f%% of trials. Set PAPR_MEASURE_MODE=data to ' ...
             'characterise the data symbols alone.'], 100*max(outsideData));
    end

    S = papr_density(paprSamples, bins, kernelBw);
    durationLegend = arrayfun(@(n) sprintf('T=%d ms', n), achieved, 'UniformOutput', false);
    fprintf('  KDE bandwidth=%.4f dB, grid=[%.2f %.2f] dB, peak density=%.2f 1/dB\n', ...
        S.bandwidth, S.edges(1), S.edges(end), max(S.pdf(:)));

    if ~exist(figPath, 'dir')
        mkdir(figPath);
    end
    fname = fullfile(figPath, sprintf('5g_%s_PAPRPDF_%s_%s.png', direction, modeTag, tagOf(MCS, BW, SCS)));
    fig1 = plot_generic(S.binCenters, S.pdf, ...
        fname, 'LogY', false, 'LogX', false, ...
        'XLabel', 'PAPR [dB]', 'YLabel', 'Probability density [1/dB]', ...
        'FigureSize', [1 1 4 3], 'XTick', S.xTick, 'YTick', S.yTickPdf, ...
        'Legend', durationLegend, ...
        'LegendLocation', 'NorthEast', ...
        'FontSize', 8, 'NColors', 64, 'Save', true);

    fname = fullfile(figPath, sprintf('5g_%s_PAPRCCDF_%s_%s.png', direction, modeTag, tagOf(MCS, BW, SCS)));
    fig2 = plot_generic(S.binCenters, S.ccdf, ...
        fname, 'LogY', true, 'LogX', false, ...
        'XLabel', 'S [dB]', 'YLabel', 'Pr(PAPR>S)', ...
        'FigureSize', [1 1 4 3], 'XTick', S.xTick, 'YTick', S.yTickCcdf, ...
        'Legend', durationLegend, ...
        'LegendLocation', 'SouthWest', ...
        'FontSize', 8, 'NColors', 64, 'Save', true);
    fprintf('runCdf done: wrote 5g_%s_PAPRPDF_%s_%s.png and 5g_%s_PAPRCCDF_%s_%s.png\n', ...
        direction, modeTag, tagOf(MCS, BW, SCS), direction, modeTag, tagOf(MCS, BW, SCS));
end

%% Signal Generation
if runGen || runAll
    target_mbytes = env_num('PAPR_MB', 4);     % Target memory size: 4, 8, or 16 MB
    % 8 bytes per complex sample: the export below writes float32 I and
    % float32 Q via fwrite(...,'single').
    bytes_per_sample = 8;
    tolerance_db = 0.05;
    max_attempts = 2000;
    maxSubframes = env_num('PAPR_GEN_SUBFRAMES', Inf);   % cap the burst below the budget
    localTrials = env_num('PAPR_GEN_LOCAL_TRIALS', 100);

    [measureDataFieldOnly, modeTag] = papr_measure_mode(true);
    [cfgNR, info] = papr_5g_config(direction, BW, SCS, MCS, osf, cfgOpts);
    fprintf('runGen: %s %s MCS %d (%s R=%.3f) @ %d MHz / %d kHz, %d RB, fs=%.2f MS/s, %g MB, mode=%s\n', ...
        upper(direction), waveform, MCS, info.modulation, info.codeRate, BW, SCS, info.nrb, ...
        info.fs/1e6, target_mbytes, modeTag);

    genMeta = papr_5g_meta(cfgNR, info);
    total_target_samples = (target_mbytes * 1024 * 1024) / bytes_per_sample;

    % The memory budget is the hard limit and the airtime is the negotiable
    % one: papr_5g_fit_airtime packs whole units and cuts the last one at a
    % slot boundary only when even one unit would not fit.
    fit = papr_5g_fit_airtime(genMeta, total_target_samples, maxSubframes);
    if fit.reduced
        fprintf(['One %d-subframe unit (%.3f ms) does not fit %g MB at %.2f MS/s; ' ...
            'burst cut to %d slot(s) (%.3f ms).\n'], ...
            genMeta.subframesPerUnit, fit.requestedUs/1000, target_mbytes, info.fs/1e6, ...
            fit.tailSlots, fit.airtimeUs/1000);
    end
    if fit.reduced
        fprintf('Targeting %d slot(s) = %.3f ms of NR signal with %d padding samples to reach exactly %g MB.\n', ...
            fit.tailSlots, fit.airtimeUs/1000, fit.padSamples, target_mbytes);
    else
        fprintf('Targeting %d unit(s) = %.3f ms of NR signal with %d padding samples to reach exactly %g MB.\n', ...
            fit.numUnits, fit.airtimeUs/1000, fit.padSamples, target_mbytes);
    end

    % Target from the measured table; when the combination has not been
    % swept yet, measure a local target on the spot rather than stop. It is
    % noisier than a table row (localTrials bursts instead of hundreds) and
    % is reported as such.
    try
        [target_mean_papr_db, target_std_papr_db, nTarget] = papr_5g_target( ...
            direction, waveform, cfgOpts.MCSTable, MCS, BW, SCS, modeTag);
        fprintf('Target for %s MCS %d @ %d MHz / %d kHz (%s, n=%d): mean=%.3f dB, std=%.3f dB\n', ...
            upper(direction), MCS, BW, SCS, modeTag, nTarget, target_mean_papr_db, target_std_papr_db);
    catch err
        if ~any(strcmp(err.identifier, {'papr_5g_target:NoEntry', 'papr_5g_target:MissingTable'}))
            rethrow(err);
        end
        fprintf('%s\nMeasuring a local target over %d bursts of %.3f ms instead.\n', ...
            err.message, localTrials, fit.airtimeUs/1000);
        % Measured on exactly the burst shape exported below (same unit
        % count, same slot cut), so the comparison is like for like.
        localSeeds = randi([1 2^20], localTrials, 1);
        localPapr = zeros(localTrials, 1);
        parfor t = 1:localTrials
            txL = papr_5g_generate(cfgNR, genMeta, fit.unitsToGen, 0, localSeeds(t));
            localPapr(t) = papr_burst_db(txL(1:fit.burstSamples, :), genMeta, ...
                fit.unitsToGen, measureDataFieldOnly);
        end
        localPapr = localPapr(isfinite(localPapr));
        target_mean_papr_db = mean(localPapr);
        target_std_papr_db = std(localPapr);
        fprintf('Local target (%s, n=%d): mean=%.3f dB, std=%.3f dB\n', ...
            modeTag, numel(localPapr), target_mean_papr_db, target_std_papr_db);
    end

    matched = false;
    for attempt = 1:max_attempts
        seed = randi([1 2^20]);
        tx_burst = papr_5g_generate(cfgNR, genMeta, fit.unitsToGen, 0, seed);
        tx_burst = tx_burst(1:fit.burstSamples, :);

        % Same definition as the targets, so the comparison is meaningful.
        current_papr_db = papr_burst_db(tx_burst, genMeta, fit.unitsToGen, measureDataFieldOnly);

        if abs(current_papr_db - target_mean_papr_db) <= tolerance_db
            matched = true;
            fprintf('Success on attempt %d! Matched PAPR: %2.2f dB\n', attempt, current_papr_db);

            final_waveform = [tx_burst; zeros(fit.padSamples, size(tx_burst,2))];
            interleaved_data = zeros(2*length(final_waveform), 1, 'single');
            interleaved_data(1:2:end) = real(final_waveform(:,1));
            interleaved_data(2:2:end) = imag(final_waveform(:,1));

            baseName = sprintf('5g_%s_%s_osf=%d_fs=%.2fMSps_%gMB', ...
                direction, tagOf(MCS, BW, SCS), osf, info.fs/1e6, target_mbytes);
            if ~exist(sigPath, 'dir')
                mkdir(sigPath);
            end
            full_dest_path = fullfile(sigPath, [baseName '.bin']);
            fileID = fopen(full_dest_path, 'w');
            if fileID < 0
                error('pa_5G_dl:CannotWrite', 'Could not open %s for writing.', full_dest_path);
            end
            fwrite(fileID, interleaved_data, 'single');
            fclose(fileID);
            fprintf('Wrote %s\n', full_dest_path);

            % Sidecar: everything a reader needs that the file name cannot
            % carry, in particular the sample rate, which is not BW x osf.
            side = struct('standard', '5G NR', 'direction', direction, 'waveform', waveform, ...
                'frequencyRange', info.frequencyRange, 'bandwidthMHz', BW, 'scsKHz', SCS, ...
                'numRB', info.nrb, 'mcs', MCS, 'mcsTable', cfgOpts.MCSTable, ...
                'modulation', info.modulation, 'codeRate', info.codeRate, ...
                'oversampling', osf, 'sampleRateHz', info.fs, ...
                'burstSubframes', fit.subframes, 'burstSamples', fit.burstSamples, ...
                'padSamples', fit.padSamples, 'airtimeReduced', fit.reduced, ...
                'ssb', cfgOpts.SSB, 'pdcch', cfgOpts.PDCCH, ...
                'measureMode', modeTag, 'paprDb', current_papr_db, ...
                'targetMeanDb', target_mean_papr_db, 'targetStdDb', target_std_papr_db, ...
                'format', 'float32 interleaved I,Q', 'seed', seed);
            sideID = fopen(fullfile(sigPath, [baseName '.json']), 'w');
            fwrite(sideID, jsonencode(side, 'PrettyPrint', true), 'char');
            fclose(sideID);
            break;
        end
    end
    if ~matched
        warning('pa_5G_dl:NoMatch', ...
            ['No burst landed within %.2f dB of the %.3f dB target in %d attempts. ' ...
             'The measured spread for this combination is %.3f dB, so widen ' ...
             'tolerance_db or confirm papr_5g_targets.csv is current.'], ...
            tolerance_db, target_mean_papr_db, max_attempts, target_std_papr_db);
    end
end

function s = env_str(name, defaultValue)
%ENV_STR String environment override, the text counterpart of env_num.
s = strtrim(getenv(name));
if isempty(s)
    s = defaultValue;
end
end
