%% This simulation encapsulates data analysis for WiFi 802.11N (Marketed as 
%  Wifi 4, this encapsulates the HT standard

clear variables; close all; clc;

sigPath = '..\signals\wifi4\';
figPath = '..\figures\wifi4\';

% Control which elements of the code run:
runAll = 0; % Runs all elements
runLong = 0; % Runs only long signal duration study of PAPR
runStats = 0; % Runs statistics for the distributions of the signal components
runCdf = 1; % Finds the CCDF of the signal as a function of signal duration
runGen = 0; % Generates signals for loading on signal generators

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
    numSims = 10000; % Number of iterations
    numBatches = 500; % Number of batches
    batchSize = numSims/numBatches;
    mcs_list = [0];
    bw_list = [20 40];
    numPackets = 5;

    % --- DYNAMIC TIME NORMALIZATION (Max 5.484 ms) ---
    targetSymbols = 500; % 1362 is the exact number of symbols for 5.484ms
                         % 500 is 2ms, which is a typical burst length for
                         % a wifi transmission
    Nsd_list     = [52, 108];
    Nbpscs_array = [1, 2, 2, 4, 4, 6, 6, 6];
    Rate_array   = [1/2, 1/2, 3/4, 1/2, 3/4, 2/3, 3/4, 5/6];
    
    % Fixed edges focused on the realistic PAPR range for Wi-Fi (typically 6 to 14 dB)
    edges = linspace(10, 16, numBins + 1); 
    binCenters = edges(1:end-1) + diff(edges)/2;
    pdf_vals = zeros(numBins,numel(bw_list),numel(mcs_list)); cc = 0;
    
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
            
            papr_db = zeros(numSims,1);

            for b = 1:numBatches
                startIdx = (b-1) * batchSize + 1;
                endIdx   = b * batchSize;

                % Pre-allocate an array to hold thousands of individual symbol PAPR values
                randomSeed = randi([1 127],batchSize,1);
                psduBits =  randi([0 1],batchSize,8*psduTotalOctets*numPackets); % use reasonable length
            
                %peak_pow = zeros(numSims,1); 
                %mean_pow = zeros(numSims,1); 
                papr_batch_db = zeros(batchSize,1); 
            
                for k = 1:batchSize
                    
                    % Generate 1 packet at a time to isolate symbols cleanly
                    tx = wlanWaveformGenerator(psduBits(k,:), cfgHT, ...
                        'NumPackets',numPackets, ...
                        'IdleTime',idleTime*1e-6,...
                        'OversamplingFactor',osf,...
                        'ScramblerInitialization', randomSeed(k), ...
                        'WindowTransitionTime', 0);
                    
                    inst_pow = abs(tx).^2; %tx.*conj(tx);
                    peak_pow = max(max(inst_pow,[],1));
                    mean_pow = mean(mean(inst_pow,1));
                    papr_batch_db(k) = 10*log10(peak_pow / mean_pow);
                end
                papr_db(startIdx:endIdx) = papr_batch_db;
                fprintf('Batch %d/%d completed.\n', b, numBatches);
            end
            cc = cc + 1;
            fprintf('We are %2.3f percent complete\n', 100*(cc)/(numel(bw_list)*numel(mcs_list)));
            % Estimate the PDF using thousands of actual symbol data points
            % f = histcounts(papr_db, edges, 'Normalization', 'pdf'); 
            [f, xi] = ksdensity(papr_db, binCenters);
            pdf_vals(:, ibw, imcs) = f;
        end
    end

    Y = reshape(pdf_vals, size(pdf_vals,1), []);   % 50 x (2*8) = 50 x 16
    %% Estimate the mean
    % Inputs:
    %   binCenters : vector (50x1 or 1x50)
    %   pdf_vals   : matrix (50x8) where each column is a PDF over the bins
    bc = binCenters(:);            % ensure column vector (50x1)
    P = Y;                  % (50x8)
    [N, M] = size(P);
    if N ~= numel(bc)
        error('binCenters length must match number of rows of pdf_vals.');
    end
    
    % Compute bin edges and widths from centers
    if N < 2
        error('Need at least two bin centers to compute widths.');
    end
    edges = [bc(1) - (bc(2)-bc(1))/2; (bc(1:end-1)+bc(2:end))/2; bc(end) + (bc(end)-bc(end-1))/2];
    w = diff(edges);               % (N x 1) widths
    
    % Normalize each PDF column (in case not exactly normalized)
    integrals = w.' * P;           % 1xM (sum over rows: integral for each column)
    if any(integrals <= 0)
        error('One or more PDF integrals are nonpositive.');
    end
    P_norm = P ./ integrals;       % normalize columns (broadcasting)
    
    % Estimate mean for each column: mean_j = sum(bc .* P_norm(:,j) .* w)
    means = ( (bc .* w).' * P_norm ).';   % result Mx1
    
    % (Optional) estimate variance
    means_col = means(:).';                % 1xM
    var_vals = sum(((bc - means.').^2 .* w) .* P_norm, 1).';
    
    
    % Output
    means = means(:);       % Mx1
    var_vals = var_vals(:); % Mx1 (optional)
    %% Call plot_generic
    % --- 1. Dynamically Build the Legend ---
    % Match MATLAB's column-major reshaping (inner loop = BW, outer loop = MCS)
    legend_entries = cell(1, numel(bw_list) * numel(mcs_list));
    idx = 1;
    for imcs = 1:numel(mcs_list)
        for ibw = 1:numel(bw_list)
            legend_entries{idx} = sprintf('CBW=%d, MCS=%d', bw_list(ibw), mcs_list(imcs));
            idx = idx + 1;
        end
    end
    
    % --- 2. Dynamically Build the Filename ---
    % Format cleanly whether the list has one element or a range
    if numel(mcs_list) > 1
        mcs_str = sprintf('mcs=%d-%d', min(mcs_list), max(mcs_list));
    else
        mcs_str = sprintf('mcs=%d', mcs_list(1));
    end
        
    dynamic_filename = fullfile(figFile, sprintf('wifi4_mcs=%s_papr_pdf.png', mcs_str));

    fig = plot_generic(binCenters, Y, dynamic_filename, ...
        'XLabel','PAPR [dB]','YLabel','Occurences [%]',...
        'FigureSize',[1 1 6 4], 'XTick',10:0.5:15, 'YTick', 0:0.25:1.5,...
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
    
    numPackets = 10000; packetsPerChunk = 1000;
    numChunks = ceil(numPackets/packetsPerChunk);
    
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
    psduBits = randi([0 1], numChunks, psduTotalOctets*8*packetsPerChunk);

    for c = 1:numChunks
        nThis = min(packetsPerChunk, numPackets - (c-1)*packetsPerChunk);
        % generate psduBits for nThis packets (reuse your computeHTAPEP etc)
        % psduBitsChunk = randi([0 1], psduTotalOctets*8*nThis, 1);
        
        txChunk = wlanWaveformGenerator(psduBits(c,:), cfgHT, 'NumPackets', nThis, ...
                            'IdleTime', idleTime*1e-6, 'OversamplingFactor', osf);
        txChunk = txChunk / max(txChunk);

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
        totalSamples_d = totalSamples + numel(dv_max);
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
    plot_bar(binCenters_v,pdf_est_v, cat(2,'..\figures\wifi4\wifi4_env_pdf_mcs=',num2str(MCS),'_bw=',chanBW,'.png'), ...
      'Colormap','parula', 'FlipMap',true, 'FontSize',9, ...
      'FigureSize',[1 1 4 3], 'XTick',v_min:0.1:v_max, 'YTick', 0:1:5,...
      'XLabel','Normalized Output Envelope [V]','YLabel','PDF [% / V]');
    plot_bar(binCenters_dv,pdf_est_dv, cat(2,'..\figures\wifi4\wifi4_denv_pdf_mcs=',num2str(MCS),'_bw=',chanBW,'.png'), ...
      'Colormap','parula', 'FlipMap',true, 'FontSize',9, ...
      'FigureSize',[1 1 4 3], 'XTick',dv_min:0.1:dv_max, 'YTick', 0:2:8,...
      'XLabel','Normalized Output Envelope Derivative [V/s]','YLabel','PDF [% / V/s]');
    plot_bar(binCenters_p,pdf_est_p, cat(2,'..\figures\wifi4\wifi4_pha_pdf__mcs=',num2str(MCS),'_bw=',chanBW,'.png'), ...
      'Colormap','parula', 'FlipMap',true, 'FontSize',9, ...
      'FigureSize',[1 1 4 3], 'XTick',p_min:pi/2:p_max, 'YTick', 0:0.1:0.6,...
      'XLabel','Normalized Output Phase [rad]','YLabel','PDF [% / rad]');
    plot_bar(binCenters_dp,pdf_est_dp, cat(2,'..\figures\wifi4\wifi4_dpha_pdf_mcs=',num2str(MCS),'_bw=',chanBW,'.png'), ...
      'Colormap','parula', 'FlipMap',true, 'FontSize',9, ...
      'FigureSize',[1 1 4 3], 'XTick',dp_min:pi:dp_max, 'YTick', 0:0.25:1.5,...
      'XLabel','Normalized Output Phase Derivative [rad/s]','YLabel','PDF [% / rad/s]');

end

%% ------------------------------------------------------------------------
% Here we generate Wifi signals with differeht numbers of symbols to demonstrate 
% the dependency of PAPR on signal length

if runCdf || runAll
    bins = 50;
    edges = linspace(10, 16, bins + 1); 
    binCenters = edges(1:end-1) + diff(edges)/2;
    MCS = 0;
    BW = 40;
    numPackets = 5; % <--- Optimizing to 1 packet per trial significantly reduces overhead
    targetSymbols = [250 525 1362];  
    list = [10000, 15000, 25000]; % <--- Increase trials here for higher statistical confidence
    
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
    
    countsPAPR = zeros(bins,numel(targetSymbols));
    binsPAPR   = zeros(bins,numel(targetSymbols));
    cdfPAPR    = zeros(bins,numel(targetSymbols));
    maxPAPR    = zeros(1,numel(targetSymbols));
    
    for ib = 1:numel(targetSymbols)
        trials = list(ib);
        peakPower = zeros(trials,1);
        meanPower = zeros(trials,1); % <--- Pre-allocate to prevent slicing/growth issues
        
        octets = psduTotalOctets(ib);
        
        cfgHT.PSDULength = octets;

        bitLength = octets * 8 * numPackets;
        
        % Parallel execution over CPU cores
        parfor t = 1:trials
            % Generate random bits locally within the worker to bypass memory transfer bottlenecks
            localBits = randi([0 1], bitLength, 1);
            randomSeed = randi([1, 127]);
            
            % Generate waveform
            tx = wlanWaveformGenerator(localBits, cfgHT, 'NumPackets', numPackets, ...
                'IdleTime', idleTime*1e-6, 'OversamplingFactor', osf, 'ScramblerInitialization', randomSeed);
    
            sigPower = abs(tx).^2;
            peakPower(t) = max(sigPower);
            meanPower(t) = mean(sigPower);
        end
    
        % Compute PAPR correctly (both column vectors, no transpose)
        PAPR_long = 10*log10(peakPower ./ meanPower);
        maxPAPR(ib) = max(PAPR_long);
    
        % Histogram / CDF calculations
        [f, xi] = ksdensity(PAPR_long, binCenters);
        pdfPAPR(:,ib) = f;
        cdfPAPR(:,ib) = cumsum(f) / sum(f);    
        %[counts, edges] = histcounts(PAPR_long, 'NumBins', bins);
        %countsPAPR(:,ib) = counts(:);
        %binsPAPR(:,ib)   = (edges(1:end-1) + edges(2:end)) / 2;
        %cdfPAPR(:,ib)    = cumsum(counts) / sum(counts);
    end
    %% Call plot_generic
    fname = fullfile(figPath, sprintf('wifi4_PAPRPDF_mcs=%d_bw=%d.png', MCS, BW)); 
    fig1 = plot_generic(binCenters,pdfPAPR,...
        fname, 'LogY', false, 'LogX', false, ...
        'XLabel','PAPR [dB]','YLabel','Occurences [%]',...
        'FigureSize',[1 1 4 3], 'XTick',10:0.5:14, 'YTick', 0:0.4:1.6,...
        'Legend',{'#Symbols=250','#Symbols=525', '#Symbols=1362'},...
        'LegendLocation','NorthEast',...
        'FontSize', 8, 'NColors',64,'Save',true);
    fname = fullfile(figPath, sprintf('wifi4_PAPRCCDF_mcs=%d_bw=%d.png', MCS, BW)); 
    fig2 = plot_generic(binCenters,1-cdfPAPR,...
        fname, 'LogY', true, 'LogX', false, ...
        'XLabel','S [dB]','YLabel','Pr(PAPR<S)',...
        'FigureSize',[1 1 4 3], 'XTick',10:0.5:14, 'YTick', logspace(-3,0,4),...
        'Legend',{'#Symbols=250','#Symbols=525', '#Symbols=1362'},...
        'LegendLocation','SouthWest',...
        'FontSize', 8, 'NColors',64,'Save',true);
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

    % Your empirical target mean PAPR for this MCS/BW combo (Example value)
    tolerance_db = 0.05;     % Allowable variance from the mean
    switch mcs_value
        case 0
            if chanBW == 'CBW20'
                target_mean_papr_db = 11.53
                target_var_papr_db = 0.39
            else % chanBW == 'CBW40'
                target_mean_papr_db = 11.64
                target_var_papr_db = 0.22
            end
        case 1
            if chanBW == 'CBW20'
                target_mean_papr_db = 11.01
                target_var_papr_db = 0.14
            else % chanBW == 'CBW40'
                target_mean_papr_db = 11.47
                target_var_papr_db = 0.14
            end
        case 2
            if chanBW == 'CBW20'
                target_mean_papr_db = 11.10
                target_var_papr_db = 0.14
            else % chanBW == 'CBW40'
                target_mean_papr_db = 11.47
                target_var_papr_db = 0.15
            end
        case 3
            if chanBW == 'CBW20'
                target_mean_papr_db = 11.17
                target_var_papr_db = 0.15
            else % chanBW == 'CBW40'
                target_mean_papr_db = 11.50
                target_var_papr_db = 0.14
            end
        case 4
            if chanBW == 'CBW20'
                target_mean_papr_db = 11.17
                target_var_papr_db = 0.15
            else % chanBW == 'CBW40'
                target_mean_papr_db = 11.51
                target_var_papr_db = 0.15
            end
        case 5
            if chanBW == 'CBW20'
                target_mean_papr_db = 11.14
                target_var_papr_db = 0.16
            else % chanBW == 'CBW40'
                target_mean_papr_db = 11.49
                target_var_papr_db = 0.16
            end
        case 6
            if chanBW == 'CBW20'
                target_mean_papr_db = 11.29
                target_var_papr_db = 0.15
            else % chanBW == 'CBW40'
                target_mean_papr_db = 11.62
                target_var_papr_db = 0.14   
            end
        case 7
            if chanBW == 'CBW20'
                target_mean_papr_db = 11.38
                target_var_papr_db = 0.14
            else % chanBW == 'CBW40'
                target_mean_papr_db = 11.72
                target_var_papr_db = 0.12
            end
        case 8
            if chanBW == 'CBW20'
                target_mean_papr_db = 
                target_var_papr_db = 
            else % chanBW == 'CBW40'
                target_mean_papr_db = 
                target_var_papr_db = 
            end
        case 9
            if chanBW == 'CBW20'
                target_mean_papr_db = 
                target_var_papr_db = 
            else % chanBW == 'CBW40'
                target_mean_papr_db = 
                target_var_papr_db = 
            end    
    end
    
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
        
        % Calculate the PAPR of this specific generation
        inst_pow = final_waveform .* conj(final_waveform);
        peak_p = max(inst_pow(:));
        % Important: Calculate mean over the active burst duration, not including the padding
        mean_p = mean(inst_pow(1:size(tx_burst,1), :), 'all'); 
        
        current_papr_db = 10 * log10(peak_p / mean_p)
        
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