%% This simulation encapsulates data analysis for WiFi 802.11N (Marketed as 
%  Wifi 4, this encapsulates the HT standard

clear variables; close all; clc;
scriptDir = fileparts(mfilename('fullpath'));
addpath(scriptDir);
addpath(fileparts(scriptDir));

sigPath = '..\..\Signals\Multi Carrier\WiFi\802.11N (WiFi4)\';
figPath = '..\..\Figures\WiFi\802.11N (WiFi4)\';

% Control which elements of the code run. Each is overridable from the shell
% (e.g. PAPR_RUN_LONG=1) so a sweep needs no edits to this file.
runAll = env_num('PAPR_RUN_ALL', 0); % Runs all elements
runLong = env_num('PAPR_RUN_LONG', 0); % Runs only long signal duration study of PAPR
runStats = env_num('PAPR_RUN_STATS', 0); % Runs statistics for the distributions of the signal components
runCdf = env_num('PAPR_RUN_CDF', 1); % Finds the CCDF of the signal as a function of signal duration
runGen = env_num('PAPR_RUN_GEN', 0); % Generates signals for loading on signal generators

numTX = 1; % Single User (SISO)
idleTime   = 16; % In microseconds (time inserted between packets if desired)
osf = 4; % oversampling factor for the waveform

%% Generate an 802.11N SU Packet
cfgHT.NumTransmitAntennas = numTX;
cfgHT.NumSpaceTimeStreams = numTX;
cfgHT.SpatialMapping = 'Direct';

%% This small section can be run to better understand long-term statistics 
if runLong || runAll
    numBins = 50;
    numSims = env_num('PAPR_LONG_SIMS', 10000); % Number of iterations
    verboseProgress = false;
    % Derive the batching so numSims need not divide evenly by numBatches
    % (it does not once PAPR_LONG_SIMS is used for a short validation run).
    batchSize = max(1, ceil(numSims / env_num('PAPR_LONG_BATCHES', 500)));
    numBatches = ceil(numSims / batchSize);
    mcs_list = [0];
    bw_list = [20 40];
    numPackets = 5;
    [measureDataFieldOnly, modeTag] = papr_measure_mode(true);

    % --- DYNAMIC TIME NORMALIZATION (Max 5.484 ms) ---
    targetSymbols = 500; % 1362 is the exact number of symbols for 5.484ms
                         % 500 is 2ms, which is a typical burst length for
                         % a wifi transmission
    Nsd_list     = [52, 108];
    Nbpscs_array = [1, 2, 2, 4, 4, 6, 6, 6];
    Rate_array   = [1/2, 1/2, 3/4, 1/2, 3/4, 2/3, 3/4, 5/6];
    
    % The grid, kernel width and axis ticks are derived from the samples by
    % papr_density rather than fixed here, so no MCS/BW combination can land
    % outside the window or be clipped by a hard-coded YTick.
    numCombos = numel(bw_list) * numel(mcs_list);
    comboSamples = cell(1, numCombos);
    comboLabels  = cell(1, numCombos);
    comboPinned  = zeros(1, numCombos);
    nStored = 0; cc = 0;
    
    for ibw = 1:numel(bw_list)
        chanBW = ['CBW' num2str(bw_list(ibw))];
        cfgHT = wlanHTConfig('ChannelBandwidth',chanBW);
        for imcs = 1:numel(mcs_list)
            %rng(ibw*10 + imcs*100, 'twister');
            cfgHT.MCS = mcs_list(imcs); % set MCS correctly
            
            if bw_list(ibw) == 20
                Nsd = 52;
            else %bw_list(ibw) == 40
                Nsd = 108;
            end
            
            Nbpscs = Nbpscs_array(mcs_list(imcs)+1);
            Rate = Rate_array(mcs_list(imcs)+1);
            % Calculate exact Data Bits Per Symbol (1 Spatial Stream)
            Ndbps = Nsd * Nbpscs * Rate;
            % Calculate ideal payload length (subtracting 16 service and 6 tail bits)
            ideal_bytes = floor((targetSymbols * Ndbps - 22) / 8);
            % Enforce the absolute maximum IEEE limit for a single HT packet
            cfgHT.PSDULength = min(ideal_bytes, 65535);

            % Generate PSDU bits (payload + APEP padding octets)
            psduTotalOctets = min(ideal_bytes, 65535);

            paprMeta = papr_field_meta(cfgHT, osf, idleTime);
            papr_db = zeros(numSims,1);
            inPreamble = false(numSims,1);

            for b = 1:numBatches
                startIdx = (b-1) * batchSize + 1;
                endIdx   = min(b * batchSize, numSims);
                thisBatch = endIdx - startIdx + 1;

                % Pre-allocate an array to hold thousands of individual symbol PAPR values
                randomSeed = randi([1 127],thisBatch,1);
                psduBits =  randi([0 1],thisBatch,8*psduTotalOctets*numPackets); % use reasonable length

                papr_batch_db = zeros(thisBatch,1);
                inPre_batch = false(thisBatch,1);

                for k = 1:thisBatch

                    % Generate 1 packet at a time to isolate symbols cleanly
                    tx = wlanWaveformGenerator(psduBits(k,:), cfgHT, ...
                        'NumPackets',numPackets, ...
                        'IdleTime',idleTime*1e-6,...
                        'OversamplingFactor',osf,...
                        'ScramblerInitialization', randomSeed(k), ...
                        'WindowTransitionTime', 0);

                    % Was max/mean over the raw waveform, which averaged the
                    % inter-packet idle zeros into mean_pow and inflated PAPR.
                    [papr_batch_db(k), inPre_batch(k)] = ...
                        papr_burst_db(tx, paprMeta, numPackets, measureDataFieldOnly);
                end
                papr_db(startIdx:endIdx) = papr_batch_db;
                inPreamble(startIdx:endIdx) = inPre_batch;
                if verboseProgress
                    fprintf('Batch %d/%d completed.\n', b, numBatches);
                end
            end
            cc = cc + 1;
            if verboseProgress
                fprintf('We are %2.3f percent complete\n', 100*(cc)/(numel(bw_list)*numel(mcs_list)));
            end

            nStored = nStored + 1;
            comboSamples{nStored} = papr_db(isfinite(papr_db));
            comboLabels{nStored}  = sprintf('CBW=%d, MCS=%d', bw_list(ibw), mcs_list(imcs));
            comboPinned(nStored)  = mean(inPreamble);
        end
    end
    comboSamples = comboSamples(1:nStored);
    comboLabels  = comboLabels(1:nStored);
    comboPinned  = comboPinned(1:nStored);

    warn_if_preamble_pinned(comboPinned, measureDataFieldOnly);

    S = papr_density(comboSamples, numBins, []);
    binCenters = S.binCenters;
    Y = S.pdf;

    %% Moments
    % Taken straight from the samples rather than from the binned PDF.
    means    = cellfun(@mean, comboSamples).';
    stds     = cellfun(@std,  comboSamples).';
    var_vals = stds.^2;
    fprintf('runLong moments (mode=%s):\n', modeTag);
    for k = 1:numel(comboSamples)
        fprintf('  %-18s n=%5d  mean=%.3f dB  std=%.4f dB  var=%.4f  maxInPreamble=%.0f%%\n', ...
            comboLabels{k}, numel(comboSamples{k}), means(k), stds(k), var_vals(k), ...
            100*comboPinned(k));
    end

    %% Call plot_generic
    legend_entries = comboLabels;

    % --- Dynamically Build the Filename ---
    % Format cleanly whether the list has one element or a range
    if numel(mcs_list) > 1
        mcs_str = sprintf('mcs=%d-%d', min(mcs_list), max(mcs_list));
    else
        mcs_str = sprintf('mcs=%d', mcs_list(1));
    end
        
    dynamic_filename = fullfile(figPath, sprintf('wifi4_mcs=%s_papr_pdf.png', mcs_str));

    fig = plot_generic(binCenters, Y, dynamic_filename, ...
        'XLabel','PAPR [dB]','YLabel','Probability density [1/dB]',...
        'FigureSize',[1 1 6 4], 'XTick', S.xTick, 'YTick', S.yTickPdf,...
        'Legend', legend_entries, ...{'CBW=20, MCS=0','CBW=40, MCS=0'},... ,'CBW=20, MCS=1','CBW=40, MCS=1','CBW=20, MCS=2','CBW=40, MCS=2','CBW=20, MCS=3','CBW=40, MCS=3','CBW=20, MCS=4','CBW=40, MCS=4','CBW=20, MCS=5','CBW=40, MCS=5','CBW=20, MCS=6','CBW=40, MCS=6','CBW=20, MCS=7','CBW=40, MCS=7'},
        'LegendLocation','NorthEast',...
        'LineWidth', 1.5,...
        'FontSize', 12, 'NColors',64,'Save',true);
end
%% Plot statistics
if runStats || runAll
    MCS = 0;
    BW = 40;
    nbins = 200;
    v_min = 0; v_max = 1; dv_min = -1; dv_max = 1;
    p_min = -pi; p_max = pi; dp_min = -2*pi; dp_max = 2*pi;
    edges_v = linspace(v_min,v_max, nbins + 1);
    edges_dv = linspace(dv_min,dv_max, nbins + 1);
    edges_p = linspace(p_min,p_max, nbins + 1);
    edges_dp = linspace(dp_min,dp_max, nbins + 1);
    
    % packetsPerChunk is derived from a sample budget rather than fixed: at
    % wide bandwidths a fixed count made a single chunk many GB of complex
    % doubles. numPackets is overridable so a smoke test need not edit this.
    numPackets = env_num('PAPR_STATS_PACKETS', 10000);
    chunkSampleBudget = env_num('PAPR_CHUNK_SAMPLES', 2e7);
    
    countsSum_v = zeros(nbins,1);
    countsSum_dv = zeros(nbins,1);
    countsSum_p = zeros(nbins,1);
    countsSum_dp = zeros(nbins,1);
    totalSamples = 0;
    totalSamples_d = 0;

    % --- DYNAMIC TIME NORMALIZATION (Max 5.484 ms) ---
    targetSymbols = 500; % 1362 is the exact number of symbols for 5.484ms
                         % 500 is 2ms, which is a typical burst length for
                         % a wifi transmission
    Nsd_list     = [52, 108];
    Nbpscs_array = [1, 2, 2, 4, 4, 6, 6, 6];
    Rate_array   = [1/2, 1/2, 3/4, 1/2, 3/4, 2/3, 3/4, 5/6];

    chanBW = ['CBW' num2str(BW)];
    cfgHT = wlanHTConfig('ChannelBandwidth',chanBW);
    cfgHT.MCS = MCS; % set MCS correctly
            
    if BW == 20
        Nsd = 52;
    else %BW == 40
        Nsd = 108;
    end
            
    Nbpscs = Nbpscs_array(MCS+1);
    Rate = Rate_array(MCS+1);
    % Calculate exact Data Bits Per Symbol (1 Spatial Stream)
    Ndbps = Nsd * Nbpscs * Rate;
    % Calculate ideal payload length (subtracting 16 service and 6 tail bits)
    ideal_bytes = floor((targetSymbols * Ndbps - 22) / 8);
    % Enforce the absolute maximum IEEE limit for a single HT packet
    cfgHT.PSDULength = min(ideal_bytes, 65535);

    % Generate PSDU bits (payload + APEP padding octets)
    psduTotalOctets = min(ideal_bytes, 65535);
    % Size a chunk by sample budget, using one probe packet to learn its length.
    probeBits = randi([0 1], psduTotalOctets*8, 1);
    probeTx = wlanWaveformGenerator(probeBits, cfgHT, 'NumPackets', 1, ...
        'IdleTime', idleTime*1e-6, 'OversamplingFactor', osf);
    samplesPerPacket = size(probeTx, 1);
    packetsPerChunk = max(1, floor(chunkSampleBudget / samplesPerPacket));
    numChunks = ceil(numPackets / packetsPerChunk);
    clear probeBits probeTx
    fprintf('runStats: %d packets, %d samples each, %d per chunk, %d chunks\n', ...
        numPackets, samplesPerPacket, packetsPerChunk, numChunks);

    % Bits are drawn per chunk. Allocating every chunk up front defeated the
    % chunking and made this section allocate many GB before doing any work.
    for c = 1:numChunks
        nThis = min(packetsPerChunk, numPackets - (c-1)*packetsPerChunk);
        psduBitsChunk = randi([0 1], psduTotalOctets*8*nThis, 1);

        txChunk = wlanWaveformGenerator(psduBitsChunk, cfgHT, 'NumPackets', nThis, ...
                            'IdleTime', idleTime*1e-6, 'OversamplingFactor', osf);

        % max() of a complex vector returns the largest-MAGNITUDE element,
        % which is itself complex, so dividing by it rotated the whole chunk
        % by that element's phase and smeared the phase histograms.
        txChunk = txChunk / max(abs(txChunk));

        % compute power in dB normalized to max (same as your p)
        v = abs(txChunk);
        dv = diff(v);
        p = angle(txChunk);
        dp = diff(p);

        % histogram for this chunk (use same edges)
        counts_v = histcounts(v, edges_v); 
        counts_dv = histcounts(dv, edges_dv);
        counts_p = histcounts(p, edges_p); 
        counts_dp = histcounts(dp, edges_dp);
        countsSum_v = countsSum_v + counts_v(:);
        countsSum_dv = countsSum_dv + counts_dv(:);
        countsSum_p = countsSum_p + counts_p(:);
        countsSum_dp = countsSum_dp + counts_dp(:);

        totalSamples = totalSamples + numel(v);
        totalSamples_d = totalSamples_d + numel(dv); % was numel(dv_max), i.e. 1
        clear txChunk v dv p dp psduBitsChunk   % free memory early
    end
    
    binCenters_v = edges_v(1:end-1) + diff(edges_v)/2;
    binCenters_dv = edges_dv(1:end-1) + diff(edges_dv)/2;
    binCenters_p = edges_p(1:end-1) + diff(edges_p)/2;
    binCenters_dp = edges_dp(1:end-1) + diff(edges_dp)/2;

    binWidths_v = diff(edges_v); binWidths_dv = diff(edges_dv);
    binWidths_p = diff(edges_p); binWidths_dp = diff(edges_dp);
    pdf_est_v = countsSum_v ./ (totalSamples * binWidths_v');
    pdf_est_dv = countsSum_dv ./ (totalSamples_d * binWidths_dv');
    pdf_est_p = countsSum_p ./ (totalSamples * binWidths_p');
    pdf_est_dp = countsSum_dp ./ (totalSamples_d * binWidths_dp');

    %% Plot Statistics
    % Paths go through figPath. These used to hard-code a relative path
    % into Code/figures/wifi4, which does not exist. The y ticks come
    % from the data so plot_bar cannot clip a peak.
    statName = @(kind) fullfile(figPath, ...
        sprintf('wifi4_%s_pdf_mcs=%d_bw=%s.png', kind, MCS, chanBW));

    plot_bar(binCenters_v,pdf_est_v, statName('env'), ...
      'Colormap','parula', 'FlipMap',true, 'FontSize',9, ...
      'FigureSize',[1 1 4 3], 'XTick',v_min:0.1:v_max, ...
      'YTick', nice_ticks(0, max(pdf_est_v), 5),...
      'XLabel','Normalized Output Envelope [V]','YLabel','PDF [1/V]');
    plot_bar(binCenters_dv,pdf_est_dv, statName('denv'), ...
      'Colormap','parula', 'FlipMap',true, 'FontSize',9, ...
      'FigureSize',[1 1 4 3], 'XTick',dv_min:0.1:dv_max, ...
      'YTick', nice_ticks(0, max(pdf_est_dv), 5),...
      'XLabel','Normalized Output Envelope Derivative [V/s]','YLabel','PDF [1/(V/s)]');
    plot_bar(binCenters_p,pdf_est_p, statName('pha'), ...
      'Colormap','parula', 'FlipMap',true, 'FontSize',9, ...
      'FigureSize',[1 1 4 3], 'XTick',p_min:pi/2:p_max, ...
      'YTick', nice_ticks(0, max(pdf_est_p), 5),...
      'XLabel','Normalized Output Phase [rad]','YLabel','PDF [1/rad]');
    plot_bar(binCenters_dp,pdf_est_dp, statName('dpha'), ...
      'Colormap','parula', 'FlipMap',true, 'FontSize',9, ...
      'FigureSize',[1 1 4 3], 'XTick',dp_min:pi:dp_max, ...
      'YTick', nice_ticks(0, max(pdf_est_dp), 5),...
      'XLabel','Normalized Output Phase Derivative [rad/s]','YLabel','PDF [1/(rad/s)]');

end

%% ------------------------------------------------------------------------
% Here we generate Wifi signals with differeht numbers of symbols to demonstrate 
% the dependency of PAPR on signal length

if runCdf || runAll
    bins = 50;
    MCS = env_num('PAPR_MCS', 0);
    BW  = env_num('PAPR_BW', 40);
    numPackets = 5; % <--- Optimizing to 1 packet per trial significantly reduces overhead
    [measureDataFieldOnly, modeTag] = papr_measure_mode(true);
    kernelBw = []; % [] => Silverman's rule from the pooled samples
    targetSymbols = [250 525 1362];
    list = [10000, 15000, 25000]; % <--- Increase trials here for higher statistical confidence
    trialOverride = str2double(getenv('PAPR_TRIALS'));
    if isfinite(trialOverride) && trialOverride > 0
        list = repmat(round(trialOverride), size(targetSymbols));
    end
    fprintf('runCdf start: mode=%s, MCS=%d, BW=%d, trials=[%s]\n', ...
        modeTag, MCS, BW, num2str(list));

    Nbpscs_array = [1, 2, 2, 4, 4, 6, 6, 6];
    Rate_array   = [1/2, 1/2, 3/4, 1/2, 3/4, 2/3, 3/4, 5/6];
    chanBW = ['CBW' num2str(BW)];
    cfgHT = wlanHTConfig('ChannelBandwidth',chanBW);
    cfgHT.MCS = MCS; 
            
    if BW == 20
        Nsd = 52;
    else
        Nsd = 108;
    end
            
    Nbpscs = Nbpscs_array(MCS+1);
    Rate = Rate_array(MCS+1);
    Ndbps = Nsd * Nbpscs * Rate;
    ideal_bytes = floor((targetSymbols * Ndbps - 22) / 8);
    psduTotalOctets = min(ideal_bytes, 65535);
    
    paprSamples    = cell(1, numel(targetSymbols));
    preamblePinned = zeros(1, numel(targetSymbols));
    maxPAPR        = zeros(1, numel(targetSymbols));

    for ib = 1:numel(targetSymbols)
        trials = list(ib);
        papr_db = zeros(trials,1);
        inPreamble = false(trials,1);

        octets = psduTotalOctets(ib);
        cfgHT.PSDULength = octets;
        bitLength = octets * 8 * numPackets;
        paprMeta = papr_field_meta(cfgHT, osf, idleTime);

        % Parallel execution over CPU cores
        parfor t = 1:trials
            % Generate random bits locally within the worker to bypass memory transfer bottlenecks
            localBits = randi([0 1], bitLength, 1);
            randomSeed = randi([1, 127]);

            % Generate waveform
            tx = wlanWaveformGenerator(localBits, cfgHT, 'NumPackets', numPackets, ...
                'IdleTime', idleTime*1e-6, 'OversamplingFactor', osf, ...
                'ScramblerInitialization', randomSeed, 'WindowTransitionTime', 0);

            % Was max(sigPower)/mean(sigPower) over the raw waveform, so the
            % inter-packet idle zeros entered the mean and inflated PAPR.
            [papr_db(t), inPreamble(t)] = papr_burst_db(tx, paprMeta, numPackets, measureDataFieldOnly);
        end

        paprSamples{ib}    = papr_db(isfinite(papr_db));
        preamblePinned(ib) = mean(inPreamble);
        maxPAPR(ib)        = max(paprSamples{ib});
        fprintf('  %5d symbols: n=%6d  mean=%.3f dB  std=%.4f dB  span=[%.2f %.2f] dB  maxInPreamble=%.0f%%\n', ...
            targetSymbols(ib), numel(paprSamples{ib}), mean(paprSamples{ib}), ...
            std(paprSamples{ib}), min(paprSamples{ib}), maxPAPR(ib), ...
            100*preamblePinned(ib));
    end
    warn_if_preamble_pinned(preamblePinned, measureDataFieldOnly);

    % The CCDF now comes from a real CDF estimate. It used to be
    % cumsum(f)/sum(f), which renormalises over only the samples inside the
    % fixed linspace(10,16) grid and so forces the curve to 1 at the left edge
    % and exactly 0 at the right edge regardless of the data.
    S = papr_density(paprSamples, bins, kernelBw);
    binCenters = S.binCenters;
    pdfPAPR = S.pdf;
    ccdfPAPR = S.ccdf;
    symbolLegend = arrayfun(@(n) sprintf('#Symbols=%d', n), targetSymbols, ...
        'UniformOutput', false);
    fprintf('  KDE bandwidth=%.4f dB, grid=[%.2f %.2f] dB, peak density=%.2f 1/dB\n', ...
        S.bandwidth, S.edges(1), S.edges(end), max(pdfPAPR(:)));

    %% Call plot_generic
    fname = fullfile(figPath, sprintf('wifi4_PAPRPDF_%s_mcs=%d_bw=%d.png', modeTag, MCS, BW));
    fig1 = plot_generic(binCenters,pdfPAPR,...
        fname, 'LogY', false, 'LogX', false, ...
        'XLabel','PAPR [dB]','YLabel','Probability density [1/dB]',...
        'FigureSize',[1 1 4 3], 'XTick', S.xTick, 'YTick', S.yTickPdf,...
        'Legend', symbolLegend,...
        'LegendLocation','NorthEast',...
        'FontSize', 8, 'NColors',64,'Save',true);
    fname = fullfile(figPath, sprintf('wifi4_PAPRCCDF_%s_mcs=%d_bw=%d.png', modeTag, MCS, BW));
    fig2 = plot_generic(binCenters,ccdfPAPR,...
        fname, 'LogY', true, 'LogX', false, ...
        'XLabel','S [dB]','YLabel','Pr(PAPR>S)',...
        'FigureSize',[1 1 4 3], 'XTick', S.xTick, 'YTick', S.yTickCcdf,...
        'Legend', symbolLegend,...
        'LegendLocation','SouthWest',...
        'FontSize', 8, 'NColors',64,'Save',true);
    fprintf('runCdf done: wrote wifi4_PAPRPDF_%s_mcs=%d_bw=%d.png and wifi4_PAPRCCDF_%s_mcs=%d_bw=%d.png\n', ...
        modeTag, MCS, BW, modeTag, MCS, BW);
end

%% Signal Generation
if runGen == 1
    % --- Configuration Parameters ---
    idleTime = 16e-6; % Should be between 16-34us
    BW = 40; % Target bandwidth
    chanBW = ['CBW' num2str(BW)];        
    mcs_value = 0;           % Target MCS
    target_mbytes = 8;       % Target memory size: 4, 8, or 16 MB
    bytes_per_sample = 8;    % 8 for float32 (IQ), 4 for int16 (IQ)
    osf = 4;                 % Oversampling factor used in your previous runs
    numTX = 1;               % Number of TX Antennas

    % Targets come from papr_targets.csv (see gen_papr_targets), measured with
    % the same papr_burst_db definition the search loop below uses. The old
    % inline switch/case table was populated from runs whose maximum could be
    % pinned to a deterministic preamble sample, which is why several wide-BW
    % entries carried impossibly small spreads.
    tolerance_db = 0.05;     % Allowable deviation from the target mean
    [measureDataFieldOnly, modeTag] = papr_measure_mode(true);
    [target_mean_papr_db, target_std_papr_db] = ...
        papr_target('ht', mcs_value, BW, modeTag);
    fprintf('Target for HT MCS %d @ %d MHz (%s): mean=%.3f dB, std=%.3f dB\n', ...
        mcs_value, BW, modeTag, target_mean_papr_db, target_std_papr_db);

    % --- Step 1: Calculate Strict Sample Allocation ---
    total_target_bytes = target_mbytes * 1024 * 1024;
    total_target_samples = total_target_bytes / bytes_per_sample;
    
    % --- Step 2: Initialize Wi-Fi 4 Config ---
    cfgHT = wlanHTConfig('ChannelBandwidth', chanBW);
    cfgHT.MCS = mcs_value;
    cfgHT.NumSpaceTimeStreams = numTX;
    cfgHT.NumTransmitAntennas = numTX;
    
    % Define a target airtime duration per packet (e.g., 1.5 milliseconds)
    target_packet_duration_sec = 1.5e-3;

    % Wi-Fi 4 approximate data rates in Mbps for 20MHz (approximate mapping)
    % This maps roughly how many bytes fit into your target airtime window
    if BW == 20
        mcs_rates_bps = [6.5, 13, 19.5, 26, 39, 52, 58.5, 65] * 1e6;
    else % BW == 40
        mcs_rates_bps = [13.5, 27, 40.5, 54, 81, 108, 121.5, 135] * 1e6;
    end 
    approx_rate = mcs_rates_bps(mcs_value + 1);

    % Calculate the ideal byte length to hit that airtime target
    calculated_bytes = floor((target_packet_duration_sec * approx_rate) / 8);

    % Clip the bytes to strict Wi-Fi 4 limits (Max PSDU is 65535 bytes)
    cfgHT.PSDULength = min(max(calculated_bytes, 500), 65535);
    fprintf('For MCS %d, dynamically set PSDULength to %d bytes to maintain uniform airtime.\n', ...
    mcs_value, cfgHT.PSDULength);

    % Generate one test packet to see how many samples it produces
    test_bits = randi([0 1], 8 * cfgHT.PSDULength, 1);
    tx_test = wlanWaveformGenerator(test_bits, cfgHT, 'OversamplingFactor', osf,...
        'IdleTime',idleTime);
    samples_per_packet = size(tx_test, 1);
    
    % Determine how many full packets can fit inside the target sample budget
    numPackets = floor(total_target_samples / samples_per_packet);
    if numPackets == 0
        error('The target memory size is too small for even a single packet. Increase memory size or lower PSDULength.');
    end
    
    remaining_samples = total_target_samples - (numPackets * samples_per_packet);
    
    fprintf('Targeting %d packets with %d padding samples to reach exactly %d MB.\n', ...
        numPackets, remaining_samples, target_mbytes);
    
    genPaprMeta = papr_field_meta(cfgHT, osf, idleTime*1e6);

    % --- Step 3: Search Loop for Mean PAPR Matching ---
    matched = false;
    max_attempts = 2000;
    attempt = 0;
    
    while ~matched && attempt < max_attempts
        attempt = attempt + 1;
        
        % Generate a totally fresh random bitstream for the full packet burst
        psduBits = randi([0 1], 8 * cfgHT.PSDULength * numPackets, 1);
        randomSeed = randi([1 127]);
        
        % Generate the full burst
        tx_burst = wlanWaveformGenerator(psduBits, cfgHT, ...
            'NumPackets', numPackets, ...
            'OversamplingFactor', osf, ...
            'IdleTime',idleTime,...
            'ScramblerInitialization', randomSeed);
        
        % Append the exact required idle zero-padding to meet memory boundaries
        % This maintains validity for signal generator playback looping
        padding_zeros = zeros(remaining_samples, size(tx_burst, 2));
        final_waveform = [tx_burst; padding_zeros];
        
        % Measured with the same definition as the targets. The previous
        % inline max/mean averaged over every active sample including the
        % inter-packet idle gaps, so it was comparing a different quantity
        % against the table and could never converge at a 0.05 dB tolerance.
        current_papr_db = papr_burst_db(tx_burst, genPaprMeta, numPackets, ...
            measureDataFieldOnly);
        
        % Check if it hits your target mean PAPR window
        if abs(current_papr_db - target_mean_papr_db) <= tolerance_db
            matched = true;
            fprintf('Success on attempt %d! Matched PAPR: %2.2f dB\n', attempt, current_papr_db);
            
            % --- Step 4: Export to Signal Generator Compatible File ---
            % Convert to interleaved complex float32 values (I1, Q1, I2, Q2...)
            interleaved_data = zeros(2 * length(final_waveform), 1, 'single');
            interleaved_data(1:2:end) = real(final_waveform(:,1));
            interleaved_data(2:2:end) = imag(final_waveform(:,1));
            
            filename = sprintf('wifi4_mcs=%d_bw=%d_osf=%d_%dMB.bin', mcs_value, BW, osf, target_mbytes);
            full_dest_path = fullfile(sigPath, filename);
            
            fileID = fopen(full_dest_path, 'w');
            fwrite(fileID, interleaved_data, 'single');
            fclose(fileID);
            fprintf('Conforming waveform written to %s (%d samples)\n', filename, length(final_waveform));
        end
    end
    
    if ~matched
        warning('Could not find a waveform matching the precise target PAPR within limit. Try expanding the tolerance.');
    end
    
    %% --- Step 5: Receiver & EVM (SNR) Measurement ---
    fprintf('\n--- Initiating Receiver Test ---\n');
    
    % 2. Decimate to remove the Oversampling Factor (osf)
    % The receiver algorithms expect baseband sampling (e.g., 20 MHz)
    fs = wlanSampleRate(cfgHT);
    ofdmInfo = wlanHTOFDMInfo('HT-Data',cfgHT); % OFDM parameters
    SCS = fs/ofdmInfo.FFTLength; % Subcarrier spacing
    txbw = max(abs(ofdmInfo.ActiveFrequencyIndices))*2*SCS; % Occupied bandwidth
    
    aStop = 20; % Stopband attenuation
    [L,M] = rat(osf);
    maxLM = max([L M]);
    R = (fs-txbw)/fs;
    TW = 2*R/maxLM; % Transition width
    b = designMultirateFIR(L,M,TW,aStop);
    firinterp = dsp.FIRRateConverter(M,L,b);
    rx_baseband = firinterp(tx_burst);
    
    refConstellation = wlanReferenceSymbols(cfgHT); 
    evmMeas = comm.EVM(...
    'ReferenceSignalSource', 'Estimated from reference constellation', ...
    'ReferenceConstellation', refConstellation);
    ind = wlanFieldIndices(cfgHT);
    minPktLen = double(ind.LSTF(2)-ind.LSTF(1))+1;

    rxWaveformLength = size(rx_baseband,1);
    pktLength = double(ind.HTData(2));
    rmsEVM = zeros(numPackets,1);
    pktOffsetStore = zeros(numPackets,1);
    %rng(savedState); % Restore random state
    pktNum = 0;
    searchOffset = 0; % Start at first sample (no offset)
    
    while (searchOffset+minPktLen)<=rxWaveformLength
        % Detect packet and determine coarse packet offset
        pktOffset = wlanPacketDetect(rx_baseband,cfgHT.ChannelBandwidth,searchOffset);
        % Packet offset from start of the waveform
        pktOffset = searchOffset+pktOffset; 
        % Skip packet if L-STF is empty
        if isempty(pktOffset) || (pktOffset<0) || ...
                ((pktOffset+ind.LSIG(2))>rxWaveformLength)
            break;
        end
  
        % Extract L-STF and perform coarse frequency offset correction
        nonht = rx_baseband(pktOffset+(ind.LSTF(1):ind.LSIG(2)),:);  
        coarsefreqOff = wlanCoarseCFOEstimate(nonht,cfgHT.ChannelBandwidth);
        nonht = frequencyOffset(nonht,fs,-coarsefreqOff);
        
        % Extract the legacy fields and determine fine packet offset
        lltfOffset = wlanSymbolTimingEstimate(nonht,cfgHT.ChannelBandwidth);
        pktOffset = pktOffset+lltfOffset; % Determine packet offset

        % If offset is outwith bounds of the waveform, then skip samples and
        % continue searching within remainder of the waveform
        if (pktOffset<0) || ((pktOffset+pktLength)>rxWaveformLength)
            searchOffset = pktOffset+double(ind.LSTF(2))+1;
            continue;
        end  
        
        % Timing synchronization complete; extract the detected packet
        rxPacket = rx_baseband(pktOffset+(1:pktLength),:);
        pktNum = pktNum+1;
        disp(['  Packet ' num2str(pktNum) ' at index: ' num2str(pktOffset+1)]);

        % Apply coarse frequency correction to the extracted packet
        % % % rxPacket = frequencyOffset(rxPacket,fs,-coarsefreqOff);

        htLTF = rxPacket(ind.HTLTF(1):ind.HTLTF(2),:);
        htLTFDemod = wlanHTLTFDemodulate(htLTF, cfgHT);
        chanEst = wlanHTLTFChannelEstimate(htLTFDemod, cfgHT);
        
        % Estimate the noise variance in the channel
        noiseVar = 1e-12; % Rough estimate from idle noise
        
        % 6. Data Recovery and EVM Measurement
        % Extract the actual data payload
        htdata = rx_baseband(pktOffset + (ind.HTData(1):ind.HTData(2)));
        
        % Recover the data (Eq. Demodulation, Deinterleaving, Viterbi Decoding)
        [rxPSDU, rxDataSym] = wlanHTDataRecover(htdata, chanEst, noiseVar, cfgHT, ...
            'EqualizationMethod', 'MMSE');

        rmsEvm = 20*log10((sqrt(mean(evmMeas(rxDataSym).^2)))/100);
        disp([' RMS EVM: ' num2str(rmsEvm, '%.2f') ' %']);

        % Plot equalized constellation and RMS EVM per subcarrier
        %%ehtTxEVMConstellationPlots(eqSym,evmPerSC,cfgEHT,pktNum);

        % Store the offset of each packet within the waveform
        pktOffsetStore(pktNum) = pktOffset;
    
        % Increment waveform offset and search remaining waveform for a packet
        searchOffset = pktOffset+pktLength+minPktLen;

    end
    %% Plot Constellation
    fname = sprintf('wifi4_Constellation_mcs=%d_bw=%d_osf=%d_%dMB.png', mcs_value, BW, osf, target_mbytes); % MCS03_BW05
    
    figConst = plot_generic(real(rxDataSym),imag(rxDataSym),...
        fname, 'LogY', false, 'LogX', false, ...
        'XLabel','I','YLabel','Q',...
        'FigureSize',[1 1 3 3], 'XTick',-1.1:1.1:1.1, 'YTick', -1.1:1.1:1.1,...
        'LegendLocation','SouthWest','LineStyle','none',...
        'Markers', '*',...
        'FontSize', 8, 'NColors',64,'Save',true);


end