%% This simulation encapsulates data analysis for WiFi 802.11be (Marketed as
%  Wifi 7, this encapsulates the EHT standard)
%
%  Structure mirrors pa_wifi_vht.m. The measurement helpers (papr_burst_db,
%  papr_density, papr_field_meta, ...) are shared across all four standards,
%  so HT/VHT/HE/EHT results are directly comparable.
%
%  Note on symbol counts: EHT uses a 12.8 us FFT, so an OFDM symbol is 16 us
%  at the default 3.2 us guard interval, against 4 us for HT/VHT. The
%  5.484 ms TXOP limit therefore caps a packet at 339 data symbols, and the
%  [250 625 1000] sweep used by the VHT script is not reachable here.
%
%  Note on measurement mode: at 320 MHz the legacy preamble is a 16x
%  duplicated 20 MHz sequence, and its deterministic peak wins the burst
%  maximum in essentially every trial. Measured over 20 trials at MCS 4, full
%  burst mode gave 100% preamble-pinned samples with a standard deviation of
%  0.0013 dB, i.e. a delta function; the data field gave 0.264 dB. Leave
%  PAPR_MEASURE_MODE at its 'data' default unless you specifically want the
%  whole-burst crest factor for PA backoff.

clear variables; close all; clc;
scriptDir = fileparts(mfilename('fullpath'));
addpath(scriptDir);
addpath(fileparts(scriptDir));

sigPath = '..\..\Signals\Multi Carrier\WiFi\802.11BE (WiFi7)\';
figPath = '..\..\Figures\WiFi\802.11BE (WiFi7)\';

% Control which elements of the code run. Each is overridable from the shell
% (e.g. PAPR_RUN_LONG=1) so a sweep needs no edits to this file.
runAll = env_num('PAPR_RUN_ALL', 0); % Runs all elements
runLong = env_num('PAPR_RUN_LONG', 0); % Runs only long signal duration study of PAPR
runStats = env_num('PAPR_RUN_STATS', 0); % Runs statistics for the distributions of the signal components
runCdf = env_num('PAPR_RUN_CDF', 1); % Finds the CCDF of the signal as a function of signal duration
runGen = env_num('PAPR_RUN_GEN', 0); % Generates signals for loading on signal generators

numTX = 1; % Single User (SISO)
idleTime = 16; % In microseconds
osf = 4; % Oversampling factor

MAX_EHT_SYMBOLS = 339; % 5.484 ms TXOP limit at the default 3.2 us guard interval

%% Long-term statistics section
if runLong || runAll
    numBins = 50;
    numSims = env_num('PAPR_LONG_SIMS', 2000);
    statsOSF = 4;
    verboseProgress = false;
    [measureDataFieldOnly, modeTag] = papr_measure_mode(true);
    mcs_list = [0];
    bw_list = [160 320];
    minPackets = 5;
    maxPackets = 10;
    targetSymbols = min(env_num('PAPR_LONG_SYMBOLS', 250), MAX_EHT_SYMBOLS);

    numCombos = numel(bw_list) * numel(mcs_list);
    comboSamples = cell(1, numCombos);
    comboLabels  = cell(1, numCombos);
    comboPinned  = zeros(1, numCombos);
    nStored = 0;

    for ibw = 1:numel(bw_list)
        for imcs = 1:numel(mcs_list)
            bw = bw_list(ibw); mcs = mcs_list(imcs);
            cfgEHT = papr_std_config('eht', bw, mcs, numTX);

            % Solve for the payload that gives the requested symbol count
            % instead of deriving it from an Nbpscs/rate table: EHT padding
            % rules do not follow the simple HT/VHT arithmetic.
            [octets, nSym] = papr_octets_for_symbols(cfgEHT, targetSymbols, statsOSF);
            cfgEHT = papr_payload(cfgEHT, mcs, octets);
            paprMeta = papr_field_meta(cfgEHT, statsOSF, idleTime);

            papr_db = zeros(numSims,1);
            inPreamble = false(numSims,1);
            randomSeed = randi([1 127], numSims, 1);
            numPktsPerTrial = randi([minPackets maxPackets], numSims, 1);

            parfor t = 1:numSims
                nPkts = numPktsPerTrial(t);
                bits = randi([0 1], 8*octets*nPkts, 1);
                tx = wlanWaveformGenerator(papr_bits_arg(cfgEHT, bits), cfgEHT, ...
                    'NumPackets', nPkts, ...
                    'IdleTime', idleTime*1e-6, ...
                    'OversamplingFactor', statsOSF, ...
                    'ScramblerInitialization', randomSeed(t), ...
                    'WindowTransitionTime', 0);
                [papr_db(t), inPreamble(t)] = papr_burst_db(tx, paprMeta, nPkts, measureDataFieldOnly);
            end

            if verboseProgress
                fprintf('CBW%d MCS%d done (%d symbols, %d octets)\n', bw, mcs, nSym, octets);
            end

            nStored = nStored + 1;
            comboSamples{nStored} = papr_db(isfinite(papr_db));
            comboLabels{nStored}  = sprintf('CBW=%d, MCS=%d', bw, mcs);
            comboPinned(nStored)  = mean(inPreamble);
        end
    end
    comboSamples = comboSamples(1:nStored);
    comboLabels  = comboLabels(1:nStored);
    comboPinned  = comboPinned(1:nStored);
    warn_if_preamble_pinned(comboPinned, measureDataFieldOnly);

    S = papr_density(comboSamples, numBins, []);
    means = cellfun(@mean, comboSamples).';
    stds  = cellfun(@std,  comboSamples).';
    fprintf('runLong moments (mode=%s, %d symbols):\n', modeTag, targetSymbols);
    for k = 1:numel(comboSamples)
        fprintf('  %-18s n=%5d  mean=%.3f dB  std=%.4f dB  var=%.4f  maxInPreamble=%.0f%%\n', ...
            comboLabels{k}, numel(comboSamples{k}), means(k), stds(k), stds(k)^2, ...
            100*comboPinned(k));
    end

    if numel(mcs_list) > 1
        mcs_str = sprintf('mcs=%d-%d', min(mcs_list), max(mcs_list));
    else
        mcs_str = sprintf('mcs=%d', mcs_list(1));
    end
    dynamic_filename = fullfile(figPath, sprintf('wifi7_%s_papr_pdf.png', mcs_str));

    fig = plot_generic(S.binCenters, S.pdf, dynamic_filename, ...
        'XLabel','PAPR [dB]','YLabel','Probability density [1/dB]',...
        'FigureSize',[1 1 6 4], 'XTick', S.xTick, 'YTick', S.yTickPdf,...
        'Legend', comboLabels, ...
        'LegendLocation','NorthEast',...
        'LineWidth', 1.5,...
        'FontSize', 12, 'NColors',64,'Save',true);
end

%% Plot statistics
if runStats || runAll
    MCS = env_num('PAPR_MCS', 4);
    BW  = env_num('PAPR_BW', 160);
    nbins = 200;
    v_min = 0; v_max = 1; dv_min = -1; dv_max = 1;
    p_min = -pi; p_max = pi; dp_min = -2*pi; dp_max = 2*pi;
    edges_v  = linspace(v_min, v_max, nbins + 1);
    edges_dv = linspace(dv_min, dv_max, nbins + 1);
    edges_p  = linspace(p_min, p_max, nbins + 1);
    edges_dp = linspace(dp_min, dp_max, nbins + 1);

    numPackets = env_num('PAPR_STATS_PACKETS', 2000);
    chunkSampleBudget = env_num('PAPR_CHUNK_SAMPLES', 2e7);
    targetSymbols = min(env_num('PAPR_STATS_SYMBOLS', 250), MAX_EHT_SYMBOLS);

    countsSum_v = zeros(nbins,1); countsSum_dv = zeros(nbins,1);
    countsSum_p = zeros(nbins,1); countsSum_dp = zeros(nbins,1);
    totalSamples = 0; totalSamples_d = 0;

    chanBW = sprintf('CBW%d', BW);
    cfgEHT = papr_std_config('eht', BW, MCS, numTX);
    [psduTotalOctets, nSym] = papr_octets_for_symbols(cfgEHT, targetSymbols, osf);
    cfgEHT = papr_payload(cfgEHT, MCS, psduTotalOctets);

    probeBits = randi([0 1], psduTotalOctets*8, 1);
    probeTx = wlanWaveformGenerator(papr_bits_arg(cfgEHT, probeBits), cfgEHT, ...
        'NumPackets', 1, 'IdleTime', idleTime*1e-6, 'OversamplingFactor', osf);
    samplesPerPacket = size(probeTx, 1);
    packetsPerChunk = max(1, floor(chunkSampleBudget / samplesPerPacket));
    numChunks = ceil(numPackets / packetsPerChunk);
    clear probeBits probeTx
    fprintf('runStats: MCS %d @ %d MHz, %d symbols, %d packets, %d samples each, %d per chunk, %d chunks\n', ...
        MCS, BW, nSym, numPackets, samplesPerPacket, packetsPerChunk, numChunks);

    for c = 1:numChunks
        nThis = min(packetsPerChunk, numPackets - (c-1)*packetsPerChunk);
        psduBitsChunk = randi([0 1], psduTotalOctets*8*nThis, 1);

        txChunk = wlanWaveformGenerator(papr_bits_arg(cfgEHT, psduBitsChunk), cfgEHT, ...
            'NumPackets', nThis, 'IdleTime', idleTime*1e-6, ...
            'OversamplingFactor', osf, 'WindowTransitionTime', 0);

        % Normalise by the peak MAGNITUDE. max() of a complex vector returns
        % the largest-magnitude element, which is itself complex, so dividing
        % by it would rotate the chunk and smear the phase histograms.
        txChunk = txChunk / max(abs(txChunk));

        v = abs(txChunk);  dv = diff(v);
        p = angle(txChunk); dp = diff(p);

        countsSum_v  = countsSum_v  + reshape(histcounts(v,  edges_v),  [], 1);
        countsSum_dv = countsSum_dv + reshape(histcounts(dv, edges_dv), [], 1);
        countsSum_p  = countsSum_p  + reshape(histcounts(p,  edges_p),  [], 1);
        countsSum_dp = countsSum_dp + reshape(histcounts(dp, edges_dp), [], 1);

        totalSamples   = totalSamples   + numel(v);
        totalSamples_d = totalSamples_d + numel(dv);
        clear txChunk v dv p dp psduBitsChunk
    end

    binCenters_v  = edges_v(1:end-1)  + diff(edges_v)/2;
    binCenters_dv = edges_dv(1:end-1) + diff(edges_dv)/2;
    binCenters_p  = edges_p(1:end-1)  + diff(edges_p)/2;
    binCenters_dp = edges_dp(1:end-1) + diff(edges_dp)/2;

    pdf_est_v  = countsSum_v  ./ (totalSamples   * diff(edges_v)');
    pdf_est_dv = countsSum_dv ./ (totalSamples_d * diff(edges_dv)');
    pdf_est_p  = countsSum_p  ./ (totalSamples   * diff(edges_p)');
    pdf_est_dp = countsSum_dp ./ (totalSamples_d * diff(edges_dp)');

    statName = @(kind) fullfile(figPath, ...
        sprintf('wifi7_%s_pdf_mcs=%d_bw=%s.png', kind, MCS, chanBW));

    plot_bar(binCenters_v, pdf_est_v, statName('env'), ...
      'Colormap','parula', 'FlipMap',true, 'FontSize',9, ...
      'FigureSize',[1 1 4 3], 'XTick',v_min:0.1:v_max, ...
      'YTick', nice_ticks(0, max(pdf_est_v), 5),...
      'XLabel','Normalized Output Envelope [V]','YLabel','PDF [1/V]');
    plot_bar(binCenters_dv, pdf_est_dv, statName('denv'), ...
      'Colormap','parula', 'FlipMap',true, 'FontSize',9, ...
      'FigureSize',[1 1 4 3], 'XTick',dv_min:0.1:dv_max, ...
      'YTick', nice_ticks(0, max(pdf_est_dv), 5),...
      'XLabel','Normalized Output Envelope Derivative [V/s]','YLabel','PDF [1/(V/s)]');
    plot_bar(binCenters_p, pdf_est_p, statName('pha'), ...
      'Colormap','parula', 'FlipMap',true, 'FontSize',9, ...
      'FigureSize',[1 1 4 3], 'XTick',p_min:pi/2:p_max, ...
      'YTick', nice_ticks(0, max(pdf_est_p), 5),...
      'XLabel','Normalized Output Phase [rad]','YLabel','PDF [1/rad]');
    plot_bar(binCenters_dp, pdf_est_dp, statName('dpha'), ...
      'Colormap','parula', 'FlipMap',true, 'FontSize',9, ...
      'FigureSize',[1 1 4 3], 'XTick',dp_min:pi:dp_max, ...
      'YTick', nice_ticks(0, max(pdf_est_dp), 5),...
      'XLabel','Normalized Output Phase Derivative [rad/s]','YLabel','PDF [1/(rad/s)]');
end

%% ------------------------------------------------------------------------
% PAPR as a function of signal length
if runCdf || runAll
    bins = 50;
    MCS = env_num('PAPR_MCS', 4);
    BW  = env_num('PAPR_BW', 160);
    numPackets = 8;
    statsOSF = 4;
    [measureDataFieldOnly, modeTag] = papr_measure_mode(true);
    kernelBw = []; % [] => Silverman's rule from the pooled samples

    % Capped at MAX_EHT_SYMBOLS: 1000 symbols would be 16 ms of HE data, three
    % times the 5.484 ms a single packet may occupy.
    targetSymbols = [100 220 330];
    list = [500, 500, 500];
    trialOverride = str2double(getenv('PAPR_TRIALS'));
    if isfinite(trialOverride) && trialOverride > 0
        list = repmat(round(trialOverride), size(targetSymbols));
    end
    fprintf('runCdf start: mode=%s, MCS=%d, BW=%d, trials=[%s]\n', ...
        modeTag, MCS, BW, num2str(list));

    paprSamples    = cell(1, numel(targetSymbols));
    preamblePinned = zeros(1, numel(targetSymbols));
    achieved       = zeros(1, numel(targetSymbols));

    for ib = 1:numel(targetSymbols)
        cfgEHT = papr_std_config('eht', BW, MCS, numTX);
        [octets, nSym] = papr_octets_for_symbols(cfgEHT, ...
            min(targetSymbols(ib), MAX_EHT_SYMBOLS), statsOSF);
        cfgEHT = papr_payload(cfgEHT, MCS, octets);
        achieved(ib) = nSym;

        paprMeta = papr_field_meta(cfgEHT, statsOSF, idleTime);
        trials = list(ib);
        papr_db = zeros(trials, 1);
        inPreamble = false(trials, 1);
        randomSeed = randi([1 127], trials, 1);

        parfor t = 1:trials
            localBits = randi([0 1], 8*octets*numPackets, 1);
            tx = wlanWaveformGenerator(papr_bits_arg(cfgEHT, localBits), cfgEHT, ...
                'NumPackets', numPackets, ...
                'IdleTime', idleTime*1e-6, ...
                'OversamplingFactor', statsOSF, ...
                'ScramblerInitialization', randomSeed(t), ...
                'WindowTransitionTime', 0);
            [papr_db(t), inPreamble(t)] = papr_burst_db(tx, paprMeta, numPackets, measureDataFieldOnly);
        end

        paprSamples{ib} = papr_db(isfinite(papr_db));
        preamblePinned(ib) = mean(inPreamble);
        fprintf('  %4d symbols (%6d octets): n=%4d  mean=%.3f dB  std=%.4f dB  span=[%.2f %.2f] dB  maxInPreamble=%.0f%%\n', ...
            nSym, octets, numel(paprSamples{ib}), mean(paprSamples{ib}), ...
            std(paprSamples{ib}), min(paprSamples{ib}), max(paprSamples{ib}), ...
            100*preamblePinned(ib));
    end
    warn_if_preamble_pinned(preamblePinned, measureDataFieldOnly);

    S = papr_density(paprSamples, bins, kernelBw);
    symbolLegend = arrayfun(@(n) sprintf('#Symbols=%d', n), achieved, ...
        'UniformOutput', false);
    fprintf('  KDE bandwidth=%.4f dB, grid=[%.2f %.2f] dB, peak density=%.2f 1/dB\n', ...
        S.bandwidth, S.edges(1), S.edges(end), max(S.pdf(:)));

    fname = fullfile(figPath, sprintf('wifi7_PAPRPDF_%s_mcs=%d_bw=%d.png', modeTag, MCS, BW));
    fig1 = plot_generic(S.binCenters, S.pdf, ...
        fname, 'LogY', false, 'LogX', false, ...
        'XLabel', 'PAPR [dB]', 'YLabel', 'Probability density [1/dB]', ...
        'FigureSize', [1 1 4 3], 'XTick', S.xTick, 'YTick', S.yTickPdf, ...
        'Legend', symbolLegend, ...
        'LegendLocation', 'NorthEast', ...
        'FontSize', 8, 'NColors', 64, 'Save', true);

    fname = fullfile(figPath, sprintf('wifi7_PAPRCCDF_%s_mcs=%d_bw=%d.png', modeTag, MCS, BW));
    fig2 = plot_generic(S.binCenters, S.ccdf, ...
        fname, 'LogY', true, 'LogX', false, ...
        'XLabel', 'S [dB]', 'YLabel', 'Pr(PAPR>S)', ...
        'FigureSize', [1 1 4 3], 'XTick', S.xTick, 'YTick', S.yTickCcdf, ...
        'Legend', symbolLegend, ...
        'LegendLocation', 'SouthWest', ...
        'FontSize', 8, 'NColors', 64, 'Save', true);
    fprintf('runCdf done: wrote wifi7_PAPRPDF_%s_mcs=%d_bw=%d.png and wifi7_PAPRCCDF_%s_mcs=%d_bw=%d.png\n', ...
        modeTag, MCS, BW, modeTag, MCS, BW);
end

%% Signal Generation
if runGen || runAll
    mcs_value = env_num('PAPR_MCS', 7);
    BW = env_num('PAPR_BW', 320);
    target_mbytes = 8;       % Target memory size: 4, 8, or 16 MB
    bytes_per_sample = 4;    % 4 for int16 IQ, 8 for float32 IQ
    tolerance_db = 0.05;
    max_attempts = 2000;
    targetSymbols = min(env_num('PAPR_GEN_SYMBOLS', 300), MAX_EHT_SYMBOLS);

    [measureDataFieldOnly, modeTag] = papr_measure_mode(true);
    [target_mean_papr_db, target_std_papr_db] = papr_target('eht', mcs_value, BW, modeTag);
    fprintf('Target for EHT MCS %d @ %d MHz (%s): mean=%.3f dB, std=%.3f dB\n', ...
        mcs_value, BW, modeTag, target_mean_papr_db, target_std_papr_db);

    cfgEHT = papr_std_config('eht', BW, mcs_value, numTX);
    [octets, nSym] = papr_octets_for_symbols(cfgEHT, targetSymbols, osf);
    cfgEHT = papr_payload(cfgEHT, mcs_value, octets);
    fprintf('APEPLength %d octets gives %d data symbols.\n', octets, nSym);

    total_target_samples = (target_mbytes * 1024 * 1024) / bytes_per_sample;
    probeBits = randi([0 1], 8*octets, 1);
    probeTx = wlanWaveformGenerator(papr_bits_arg(cfgEHT, probeBits), cfgEHT, ...
        'NumPackets', 1, 'IdleTime', idleTime*1e-6, 'OversamplingFactor', osf);
    samples_per_packet = size(probeTx, 1);
    numPackets = floor(total_target_samples / samples_per_packet);
    if numPackets == 0
        error('pa_wifi_eht:MemoryTooSmall', ...
            ['A single %d MHz packet is %d samples, more than the %d MB budget. ' ...
             'Raise target_mbytes or lower PAPR_GEN_SYMBOLS.'], ...
            BW, samples_per_packet, target_mbytes);
    end
    remaining_samples = total_target_samples - numPackets * samples_per_packet;
    fprintf('Targeting %d packets with %d padding samples to reach exactly %d MB.\n', ...
        numPackets, remaining_samples, target_mbytes);

    genPaprMeta = papr_field_meta(cfgEHT, osf, idleTime);
    matched = false;
    for attempt = 1:max_attempts
        psduBits = randi([0 1], 8*octets*numPackets, 1);
        tx_burst = wlanWaveformGenerator(papr_bits_arg(cfgEHT, psduBits), cfgEHT, ...
            'NumPackets', numPackets, ...
            'IdleTime', idleTime*1e-6, ...
            'OversamplingFactor', osf, ...
            'ScramblerInitialization', randi([1 127]));

        % Same definition as the targets, so the comparison is meaningful.
        current_papr_db = papr_burst_db(tx_burst, genPaprMeta, numPackets, measureDataFieldOnly);

        if abs(current_papr_db - target_mean_papr_db) <= tolerance_db
            matched = true;
            fprintf('Success on attempt %d! Matched PAPR: %2.2f dB\n', attempt, current_papr_db);

            final_waveform = [tx_burst; zeros(remaining_samples, size(tx_burst,2))];
            interleaved_data = zeros(2*length(final_waveform), 1, 'single');
            interleaved_data(1:2:end) = real(final_waveform(:,1));
            interleaved_data(2:2:end) = imag(final_waveform(:,1));

            filename = sprintf('wifi7_mcs=%d_bw=%d_osf=%d_%dMB.bin', ...
                mcs_value, BW, osf, target_mbytes);
            full_dest_path = fullfile(sigPath, filename);
            fileID = fopen(full_dest_path, 'w');
            if fileID < 0
                error('pa_wifi_eht:CannotWrite', 'Could not open %s for writing.', full_dest_path);
            end
            fwrite(fileID, interleaved_data, 'single');
            fclose(fileID);
            fprintf('Wrote %s\n', full_dest_path);
            break;
        end
    end
    if ~matched
        warning('pa_wifi_eht:NoMatch', ...
            ['No burst landed within %.2f dB of the %.3f dB target in %d attempts. ' ...
             'The measured spread for this combination is %.3f dB, so widen ' ...
             'tolerance_db or confirm papr_targets.csv is current.'], ...
            tolerance_db, target_mean_papr_db, max_attempts, target_std_papr_db);
    end
end
