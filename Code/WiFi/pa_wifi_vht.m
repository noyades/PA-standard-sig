%% This simulation encapsulates data analysis for WiFi 802.11ac (Marketed as 
%  Wifi 5, this encapsulates the VHT standard)

clear variables; close all; clc;
scriptDir = fileparts(mfilename('fullpath'));
addpath(scriptDir);
addpath(fileparts(scriptDir));

sigPath = '..\..\Signals\Multi Carrier\WiFi\802.11AC (WiFi5)\';
figPath = '..\..\Figures\WiFi\802.11AC (WiFi5)\';

% Control which elements of the code run. Each is overridable from the shell
% (e.g. PAPR_RUN_LONG=1) so a sweep needs no edits to this file.
runAll = env_num('PAPR_RUN_ALL', 0); % Runs all elements
runLong = env_num('PAPR_RUN_LONG', 0); % Runs only long signal duration study of PAPR
runStats = env_num('PAPR_RUN_STATS', 0); % Runs statistics for the distributions of the signal components
runCdf = env_num('PAPR_RUN_CDF', 0); % Finds the CCDF of the signal as a function of signal duration
runGen = env_num('PAPR_RUN_GEN', 1); % Generates signals for loading on signal generators

numTX = 1; % Single User (SISO)
idleTime   = 16; % In microseconds 
osf = 4; % Oversampling factor

%% Generate an 802.11ac SU Packet
cfgVHT.NumTransmitAntennas = numTX;
cfgVHT.NumSpaceTimeStreams = numTX;
cfgVHT.SpatialMapping = 'Direct';
cfgVHT.STBC = false;               
cfgVHT.GuardInterval = 'Long';

%% Long-term statistics section
if runLong || runAll
    numBins = 50;
    numSims = env_num('PAPR_LONG_SIMS', 2000);
    statsOSF = 4;
    verboseProgress = false;
    [measureDataFieldOnly, modeTag] = papr_measure_mode(true);
    mcs_list = [0]; % Added MCS 9 (256-QAM) for Wi-Fi 5
    bw_list = [20 40 80 160];   % Added 80 MHz
    minPackets = 5;
    maxPackets = 10;
    
    % --- DYNAMIC TIME NORMALIZATION (Max 5.484 ms) ---
    targetSymbols = 500; % Remains the same. 
                         % Max duration for VHT is still 5.484 ms.
        
    Nsd_list     = [52, 108, 234, 468]; 
    Nbpscs_array = [1, 2, 2, 4, 4, 6, 6, 6, 8, 8];
    Rate_array   = [1/2, 1/2, 3/4, 1/2, 3/4, 2/3, 3/4, 5/6, 3/4, 5/6];

    % Samples are pooled first and the grid, kernel width and axis ticks are
    % derived from them by papr_density. The previous fixed linspace(10,16)
    % grid fed histcounts, which silently DISCARDS out-of-range trials, so the
    % "pdf" no longer integrated to 1 and the moment estimates below were
    % biased by whatever fell outside the window.
    numCombos = numel(bw_list) * numel(mcs_list);
    comboSamples = cell(1, numCombos);
    comboLabels  = cell(1, numCombos);
    comboPinned  = zeros(1, numCombos);
    nStored = 0;   % forbidden combinations are skipped, so this trails cc
    cc = 0;

    for ibw = 1:numel(bw_list)
        chanBW_loop = ['CBW' num2str(bw_list(ibw))];
        cfgVHT = wlanVHTConfig('ChannelBandwidth', chanBW_loop);
        for imcs = 1:numel(mcs_list)
            
            cfgVHT.MCS = mcs_list(imcs);

            if bw_list(ibw) == 20
                Nsd = 52;
            elseif bw_list(ibw) == 40
                Nsd = 108;
            elseif bw_list(ibw) == 80
                Nsd = 234;
            else %bw_list(ibw) == 160
                Nsd = 468;
            end

            % Skip forbidden configuration
            if bw_list(ibw) == 20 && mcs_list(imcs) == 9
                fprintf('Skipping forbidden VHT config: CBW20 and MCS 9\n');
                cc = cc + 1; 
                continue;    
            end
            
            Nbpscs = Nbpscs_array(mcs_list(imcs)+1);
            Rate = Rate_array(mcs_list(imcs)+1);
            % Calculate exact Data Bits Per Symbol (1 Spatial Stream)
            Ndbps = Nsd * Nbpscs * Rate;
            % Calculate ideal payload length (subtracting 16 service and 6 tail bits)
            ideal_bytes = floor((targetSymbols * Ndbps - 22) / 8);
            % Enforce the absolute maximum IEEE limit for a single HT packet
            cfgVHT.APEPLength = min(ideal_bytes, 1048575);
            psduTotalOctets = cfgVHT.APEPLength;

            streamPlan = papr_stream_plan(cfgVHT, statsOSF, idleTime, measureDataFieldOnly);

            papr_db = zeros(numSims,1);
            inPreamble = false(numSims,1);
            randomSeed = randi([1 127],numSims,1);
            numPktsPerTrial = randi([minPackets maxPackets],numSims,1);

            % Chunked generation, for the reason given in the runCdf section.
            % The DataQueue listener runs on the client, so the status lines
            % come out while the parfor is still going.
            progress = papr_progress(sprintf('runLong VHT CBW%d MCS%d (combo %d/%d)', ...
                bw_list(ibw), mcs_list(imcs), cc+1, numCombos), numSims, 'StartPool', true);
            dq = progress.queue;
            parfor t = 1:numSims
                [papr_db(t), inPreamble(t)] = papr_burst_stream_db(cfgVHT, ...
                    psduTotalOctets, numPktsPerTrial(t), randomSeed(t), streamPlan);
                if ~isempty(dq)
                    send(dq, 1);
                end
            end
            progress.finish();
            cc = cc + 1;
            if verboseProgress
                fprintf('We are %2.3f percent complete\n', 100*(cc)/(numel(bw_list)*numel(mcs_list)));
            end

            % Store in loop order so the legend cannot drift out of step with
            % the curves (the old reshape relied on column-major ordering
            % happening to match a separately built legend).
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
    % Taken straight from the samples rather than from the binned PDF: the
    % binned estimate inherited every out-of-range trial the histogram had
    % already thrown away. These are the numbers the runGen target table
    % should be built from.
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
        
    dynamic_filename = fullfile(figPath, sprintf('wifi5_mcs=%s_papr_pdf.png', mcs_str));

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
    MCS = 2;
    BW = 160;
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
    
    Nbpscs_array = [1, 2, 2, 4, 4, 6, 6, 6, 8, 8];
    Rate_array   = [1/2, 1/2, 3/4, 1/2, 3/4, 2/3, 3/4, 5/6, 3/4, 5/6];

    chanBW = ['CBW' num2str(BW)];
    cfgVHT = wlanVHTConfig('ChannelBandwidth',chanBW);
    cfgVHT.MCS = MCS; % set MCS correctly
            
    if BW == 20
        Nsd = 52;
    elseif BW == 40
        Nsd = 108;
    elseif BW == 80
        Nsd = 234;
    else %BW == 160
        Nsd = 468;
    end
            
    Nbpscs = Nbpscs_array(MCS+1);
    Rate = Rate_array(MCS+1);
    % Calculate exact Data Bits Per Symbol (1 Spatial Stream)
    Ndbps = Nsd * Nbpscs * Rate;
    
    % Calculate ideal payload length (subtracting 16 service and 6 tail bits)
    ideal_bytes = floor((targetSymbols * Ndbps - 22) / 8);
    % Enforce the absolute maximum IEEE limit for a single HT packet
    cfgVHT.APEPLength = min(ideal_bytes, 1048575);
    psduTotalOctets = cfgVHT.APEPLength;
    
    % Size a chunk by sample budget, using one probe packet to learn its length.
    probeBits = randi([0 1], psduTotalOctets*8, 1);
    probeTx = wlanWaveformGenerator(probeBits, cfgVHT, 'NumPackets', 1, ...
        'IdleTime', idleTime*1e-6, 'OversamplingFactor', osf);
    samplesPerPacket = size(probeTx, 1);
    packetsPerChunk = max(1, floor(chunkSampleBudget / samplesPerPacket));
    numChunks = ceil(numPackets / packetsPerChunk);
    clear probeBits probeTx
    fprintf('runStats: %d packets, %d samples each, %d per chunk, %d chunks\n', ...
        numPackets, samplesPerPacket, packetsPerChunk, numChunks);

    % Bits are drawn per chunk. Allocating every chunk up front defeated the
    % chunking entirely: at MCS 2 / CBW160 that array is 40 x 87,744,000
    % doubles, i.e. ~26 GB.
    for c = 1:numChunks
        nThis = min(packetsPerChunk, numPackets - (c-1)*packetsPerChunk);
        psduBitsChunk = randi([0 1], psduTotalOctets*8*nThis, 1);

        txChunk = wlanWaveformGenerator(psduBitsChunk, cfgVHT, ...
                        'NumPackets',nThis, ...
                        'IdleTime',idleTime*1e-6,...
                        'OversamplingFactor',osf,...
                        'WindowTransitionTime', 0);

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
    % Paths go through figPath (these used to hard-code '..\figures\wifi5\',
    % which resolves to Code/figures/wifi5 and does not exist), and the y
    % ticks come from the data so plot_bar cannot clip a peak.
    statName = @(kind) fullfile(figPath, ...
        sprintf('wifi5_%s_pdf_mcs=%d_bw=%s.png', kind, MCS, chanBW));

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
    MCS = env_num('PAPR_MCS', 9);
    BW  = env_num('PAPR_BW', 160);
    numPackets = 8;
    statsOSF = 4;
    useExactSymbolProber = false;
    verboseProgress = false;
    [measureDataFieldOnly, modeTag] = papr_measure_mode(true);
    kernelBw = []; % [] => Silverman's rule from the pooled samples (see below)
    targetSymbols = [250 625 1000];
    list = [500, 500, 500];
    trialOverride = str2double(getenv('PAPR_TRIALS'));
    if isfinite(trialOverride) && trialOverride > 0
        list = repmat(round(trialOverride), size(targetSymbols));
    end
    fprintf('runCdf start: mode=%s, MCS=%d, BW=%d, trials=[%s]\n', ...
        modeTag, MCS, BW, num2str(list));

    Nbpscs_array = [1, 2, 2, 4, 4, 6, 6, 6, 8, 8];
    Rate_array = [1/2, 1/2, 3/4, 1/2, 3/4, 2/3, 3/4, 5/6, 3/4, 5/6];
    chanBW = ['CBW' num2str(BW)];
    cfgVHT = wlanVHTConfig('ChannelBandwidth', chanBW);
    cfgVHT.MCS = MCS;

    if BW == 20
        Nsd = 52;
    elseif BW == 40
        Nsd = 108;
    elseif BW == 80
        Nsd = 234;
    else
        Nsd = 468;
    end

    Nbpscs = Nbpscs_array(MCS+1);
    Rate = Rate_array(MCS+1);
    Ndbps = Nsd * Nbpscs * Rate;

    samples_per_sym = 4 * BW * statsOSF;
    preamble_samples = 40 * BW * statsOSF;
    paprSamples = cell(1, numel(targetSymbols));
    preamblePinned = zeros(1, numel(targetSymbols));

    for ib = 1:numel(targetSymbols)
        current_target = targetSymbols(ib);

        if useExactSymbolProber
            target_length_samples = preamble_samples + (current_target * samples_per_sym);
            current_bytes = floor((current_target * Ndbps - 200) / 8);
            current_bytes = floor(current_bytes / 4) * 4;
            optimal_bytes = current_bytes;

            for safety_counter = 1:100
                cfgVHT.APEPLength = current_bytes;
                test_bits = randi([0 1], 8 * current_bytes, 1);
                tx_test = wlanWaveformGenerator(test_bits, cfgVHT, ...
                    'NumPackets', 1, ...
                    'WindowTransitionTime', 0, ...
                    'OversamplingFactor', statsOSF);

                if length(tx_test) > target_length_samples
                    break;
                elseif length(tx_test) < target_length_samples
                    current_bytes = current_bytes + 4;
                else
                    optimal_bytes = current_bytes;
                    current_bytes = current_bytes + 4;
                end
            end
            octets = optimal_bytes;
        else
            octets = floor((current_target * Ndbps - 22) / 8);
            octets = min(max(floor(octets/4)*4, 1), 1048575);
        end

        cfgVHT.APEPLength = octets;
        streamPlan = papr_stream_plan(cfgVHT, statsOSF, idleTime, measureDataFieldOnly);
        trials = list(ib);
        papr_db = zeros(trials, 1);
        inPreamble = false(trials, 1);
        randomSeed = randi([1 127], trials, 1);

        % The burst is generated a few packets at a time rather than in one
        % call: 1000 symbols at 160 MHz is 2.6e6 samples per packet, and eight
        % of those on every parallel worker at once exhausted memory.
        % papr_burst_stream_db measures the same sample set either way.
        parfor t = 1:trials
            [papr_db(t), inPreamble(t)] = papr_burst_stream_db(cfgVHT, octets, ...
                numPackets, randomSeed(t), streamPlan);
        end
        preamblePinned(ib) = sum(inPreamble) / trials;

        if verboseProgress
            fprintf('Target %d symbols completed with %d trials.\n', current_target, trials);
        end

        paprSamples{ib} = papr_db(isfinite(papr_db));
        fprintf('  %5d symbols: n=%3d  mean=%.3f dB  std=%.4f dB  span=[%.2f %.2f] dB  maxInPreamble=%.0f%%\n', ...
            current_target, numel(paprSamples{ib}), mean(paprSamples{ib}), ...
            std(paprSamples{ib}), min(paprSamples{ib}), max(paprSamples{ib}), ...
            100*preamblePinned(ib));
    end

    warn_if_preamble_pinned(preamblePinned, measureDataFieldOnly);

    S = papr_density(paprSamples, bins, kernelBw);
    binCenters = S.binCenters;
    pdfPAPR = S.pdf;
    ccdfPAPR = S.ccdf;
    symbolLegend = arrayfun(@(n) sprintf('#Symbols=%d', n), targetSymbols, ...
        'UniformOutput', false);
    fprintf('  KDE bandwidth=%.4f dB, grid=[%.2f %.2f] dB, peak density=%.2f 1/dB\n', ...
        S.bandwidth, S.edges(1), S.edges(end), max(pdfPAPR(:)));

    fname = fullfile(figPath, sprintf('wifi5_PAPRPDF_%s_mcs=%d_bw=%d.png', modeTag, MCS, BW));
    fig1 = plot_generic(binCenters, pdfPAPR, ...
        fname, 'LogY', false, 'LogX', false, ...
        'XLabel', 'PAPR [dB]', 'YLabel', 'Probability density [1/dB]', ...
        'FigureSize', [1 1 4 3], 'XTick', S.xTick, 'YTick', S.yTickPdf, ...
        'Legend', symbolLegend, ...
        'LegendLocation', 'NorthEast', ...
        'FontSize', 8, 'NColors', 64, 'Save', true);

    fname = fullfile(figPath, sprintf('wifi5_PAPRCCDF_%s_mcs=%d_bw=%d.png', modeTag, MCS, BW));
    fig2 = plot_generic(binCenters, ccdfPAPR, ...
        fname, 'LogY', true, 'LogX', false, ...
        'XLabel', 'S [dB]', 'YLabel', 'Pr(PAPR>S)', ...
        'FigureSize', [1 1 4 3], 'XTick', S.xTick, 'YTick', S.yTickCcdf, ...
        'Legend', symbolLegend, ...
        'LegendLocation', 'SouthWest', ...
        'FontSize', 8, 'NColors', 64, 'Save', true);
    fprintf('runCdf done: wrote %s and %s\n', ...
        sprintf('wifi5_PAPRPDF_%s_mcs=%d_bw=%d.png', modeTag, MCS, BW), ...
        sprintf('wifi5_PAPRCCDF_%s_mcs=%d_bw=%d.png', modeTag, MCS, BW));
end

%% Signal Generation
if runGen == 1
    % --- Configuration Parameters ---
    idleTime = 16e-6; % Should be between 16-34us
    BW = 80; % Target bandwidth
    chanBW = ['CBW' num2str(BW)];        
    mcs_value = 9;           % Target MCS
    target_mbytes = 4;       % Target memory size: 4, 8, or 16 MB
    % 8 bytes per complex sample: the export below writes float32 I and
    % float32 Q via fwrite(...,'single'). Using 4 here made every file
    % twice the size its name claims.
    bytes_per_sample = 8;
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
        papr_target('vht', mcs_value, BW, modeTag);
    fprintf('Target for VHT MCS %d @ %d MHz (%s): mean=%.3f dB, std=%.3f dB\n', ...
        mcs_value, BW, modeTag, target_mean_papr_db, target_std_papr_db);

    % --- Step 1: Calculate Strict Sample Allocation ---
    total_target_bytes = target_mbytes * 1024 * 1024;
    total_target_samples = total_target_bytes / bytes_per_sample;
    
    % --- Step 2: Initialize Wi-Fi 4 Config ---
    cfgVHT = wlanVHTConfig('ChannelBandwidth', chanBW);
    cfgVHT.MCS = mcs_value;
    cfgVHT.NumSpaceTimeStreams = numTX;
    cfgVHT.NumTransmitAntennas = numTX;
    
    % Define a target airtime duration per packet (e.g., 1.5 milliseconds)
    target_packet_duration_sec = 1.5e-3;

    % Wi-Fi 5 approximate data rates in Mbps
    % This maps roughly how many bytes fit into your target airtime window
    if BW == 20
        % Note: MCS 9 is forbidden on 20 MHz. Index 10 is a dummy value to prevent indexing errors.
        mcs_rates_bps = [6.5, 13, 19.5, 26, 39, 52, 58.5, 65, 78, 78] * 1e6;
    elseif BW == 40
        mcs_rates_bps = [13.5, 27, 40.5, 54, 81, 108, 121.5, 135, 162, 180] * 1e6;
    elseif BW == 80
        mcs_rates_bps = [29.3, 58.5, 87.8, 117, 175.5, 234, 263.3, 292.5, 351, 390] * 1e6;
    else % BW == 160
        mcs_rates_bps = [58.5, 117, 175.5, 234, 351, 468, 526.5, 585, 702, 780] * 1e6;
    end
    % Catch the forbidden CBW20 / MCS 9 combination
    if BW == 20 && mcs_value == 9
        error('MCS 9 is not valid for a 20 MHz bandwidth in Wi-Fi 5.');
    end
    approx_rate = mcs_rates_bps(mcs_value + 1);

    % Calculate the ideal byte length to hit that airtime target
    calculated_bytes = floor((target_packet_duration_sec * approx_rate) / 8);

    % Clip the bytes to strict Wi-Fi 5 limits (Max APEPLength is 1,048,575 bytes)
    cfgVHT.APEPLength = min(max(calculated_bytes, 500), 1048575);
    fprintf('For MCS %d, dynamically set APEPLength to %d bytes to maintain uniform airtime.\n', ...
        mcs_value, cfgVHT.APEPLength);

    % The airtime above is what keeps the MCS sweep comparable, but the
    % waveform still has to load onto the signal generator. Growing the file
    % to fit the packet, as this used to do, defeats the point of asking for
    % a given memory size, so shorten the packet instead: the budget is the
    % hard limit and the airtime is the negotiable one.
    [cfgVHT, fit] = papr_fit_airtime(cfgVHT, osf, idleTime*1e6, total_target_samples);
    if fit.reduced
        fprintf(['A %.3f ms packet does not fit %d MB at %d MHz; airtime ' ...
            'reduced to %.3f ms (APEPLength now %d bytes).\n'], ...
            fit.requestedUs/1000, target_mbytes, BW, fit.airtimeUs/1000, fit.octets);
    end
    samples_per_packet = fit.samplesPerPacket;
    numPackets = fit.numPackets;
    
    remaining_samples = total_target_samples - (numPackets * samples_per_packet);
    
    fprintf('Targeting %d packets with %d padding samples to reach exactly %d MB.\n', ...
        numPackets, remaining_samples, target_mbytes);
    
    genPaprMeta = papr_field_meta(cfgVHT, osf, idleTime*1e6);

    % --- Step 3: Search Loop for Mean PAPR Matching ---
    matched = false;
    max_attempts = 2000;
    attempt = 0;
    
    while ~matched && attempt < max_attempts
        attempt = attempt + 1;
        
        % Generate a totally fresh random bitstream for the full packet burst
        psduBits = randi([0 1], 8 * cfgVHT.APEPLength * numPackets, 1);
        randomSeed = randi([1 127]);
        
        % Generate the full burst
        tx_burst = wlanWaveformGenerator(psduBits, cfgVHT, ...
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
            
            filename = sprintf('wifi5_mcs=%d_bw=%d_osf=%d_%dMB.bin', mcs_value, BW, osf, target_mbytes);
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
    fs = wlanSampleRate(cfgVHT);
    rx_baseband = tx_burst(1:osf:end, :);
    % % % ofdmInfo = wlanVHTOFDMInfo('VHT-Data',cfgVHT); % OFDM parameters
    % % % SCS = fs/ofdmInfo.FFTLength; % Subcarrier spacing
    % % % txbw = max(abs(ofdmInfo.ActiveFrequencyIndices))*2*SCS; % Occupied bandwidth
    % % % 
    % % % aStop = 20; % Stopband attenuation
    % % % [L,M] = rat(osf);
    % % % maxLM = max([L M]);
    % % % R = (fs-txbw)/fs;
    % % % TW = 2*R/maxLM; % Transition width
    % % % b = designMultirateFIR(L,M,TW,aStop);
    % % % firinterp = dsp.FIRRateConverter(M,L,b);
    % % % rx_baseband = firinterp(tx_burst);
    
    refConstellation = double(wlanReferenceSymbols(cfgVHT)); 
    evmMeas = comm.EVM(...
    'ReferenceSignalSource', 'Estimated from reference constellation', ...
    'ReferenceConstellation', refConstellation);
    ind = wlanFieldIndices(cfgVHT);
    minPktLen = double(ind.LSTF(2)-ind.LSTF(1))+1;

    rxWaveformLength = size(rx_baseband,1);
    pktLength = double(ind.VHTData(2));
    rmsEVM = zeros(numPackets,1);
    pktOffsetStore = zeros(numPackets,1);
    %rng(savedState); % Restore random state
    pktNum = 0;
    searchOffset = 0; % Start at first sample (no offset)
    
    while (searchOffset+minPktLen)<=rxWaveformLength
        % Detect packet and determine coarse packet offset
        pktOffset = wlanPacketDetect(rx_baseband,cfgVHT.ChannelBandwidth,searchOffset);
        % Packet offset from start of the waveform
        pktOffset = searchOffset+pktOffset; 
        % Skip packet if L-STF is empty
        if isempty(pktOffset) || (pktOffset<0) || ...
                ((pktOffset+ind.LSIG(2))>rxWaveformLength)
            break;
        end
  
        % Extract L-STF and perform coarse frequency offset correction
        nonht = rx_baseband(pktOffset+(ind.LSTF(1):ind.LSIG(2)),:);  
        coarsefreqOff = wlanCoarseCFOEstimate(nonht,cfgVHT.ChannelBandwidth);
        nonht = frequencyOffset(nonht,fs,-coarsefreqOff);
        
        % Extract the legacy fields and determine fine packet offset
        lltfOffset = wlanSymbolTimingEstimate(nonht,cfgVHT.ChannelBandwidth);
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

        vhtLTF = rxPacket(ind.VHTLTF(1):ind.VHTLTF(2),:);
        vhtLTFDemod = wlanVHTLTFDemodulate(vhtLTF, cfgVHT);
        chanEst = wlanVHTLTFChannelEstimate(vhtLTFDemod, cfgVHT);
        
        % Estimate the noise variance in the channel
        noiseVar = 1e-12; % Rough estimate from idle noise
        
        % 6. Data Recovery and EVM Measurement
        % Extract the actual data payload
        vhtdata = rx_baseband(pktOffset + (ind.VHTData(1):ind.VHTData(2)), :);
        
        % Recover the data (Eq. Demodulation, Deinterleaving, Viterbi Decoding)
        [rxPSDU, ~, eqDataSym] = wlanVHTDataRecover(vhtdata, chanEst, noiseVar, cfgVHT, ...
            'EqualizationMethod', 'MMSE');

        flatSyms = double(eqDataSym(:));
        rmsEvm = 20*log10(evmMeas(flatSyms) / 100);
        
        disp([' RMS EVM: ' num2str(rmsEvm, '%.2f') ' dB']);

        % Plot equalized constellation and RMS EVM per subcarrier
        %%ehtTxEVMConstellationPlots(eqSym,evmPerSC,cfgEHT,pktNum);

        % Store the offset of each packet within the waveform
        pktOffsetStore(pktNum) = pktOffset;
    
        % Increment waveform offset and search remaining waveform for a packet
        searchOffset = pktOffset+pktLength+minPktLen;

    end
    %% Plot Constellation
    fname = sprintf('wifi5_Constellation_mcs=%d_bw=%d_osf=%d_%dMB.png', mcs_value, BW, osf, target_mbytes); % MCS03_BW05
    fname = cat(2, figPath, 'Constellations\', fname);
    figConst = plot_generic(real(eqDataSym),imag(eqDataSym),...
        fname, 'LogY', false, 'LogX', false, ...
        'XLabel','I','YLabel','Q',...
        'FigureSize',[1 1 3 3], 'XTick',-1.1:1.1:1.1, 'YTick', -1.1:1.1:1.1,...
        'LegendLocation','SouthWest','LineStyle','none',...
        'Markers', '*',...
        'FontSize', 8, 'NColors',64,'Save',true);


end
