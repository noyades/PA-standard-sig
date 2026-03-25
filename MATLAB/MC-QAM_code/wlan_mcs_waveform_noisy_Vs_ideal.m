function [out,xIdeal] = wlan_mcs_waveform_noisy_Vs_ideal( ...
    bandwidthMHz, GI_us, coding, nSS, modulation, mcsIndex, ...
    ofdmFormat, numSymbols, varargin)

%% ========================================================================
%  USER GUIDE: HOW TO USE THIS FUNCTION (AI generated)
%  ========================================================================
%
%  This function generates WLAN OFDM waveforms (ideal and noisy TX),
%  computes envelope/phase derivatives, and plots their histograms.
%
%  ------------------------------------------------------------------------
%  REQUIRED INPUTS (must be provided in order)
%  ------------------------------------------------------------------------
%
%  1) bandwidthMHz
%     Channel bandwidth in MHz:
%     → Allowed values: [20, 40, 80, 160]
%
%  2) GI_us
%     Guard interval in microseconds:
%     → Allowed values: [0.8, 1.6, 3.2]
%
%  3) coding
%     Channel coding type:
%     → 'BCC' or 'LDPC'
%
%  4) nSS
%     Number of spatial streams:
%     → Integer from 1 to 8
%
%  5) modulation
%     Modulation type (must match MCS automatically):
%     → 'BPSK', 'QPSK', '16QAM', '64QAM', '256QAM', '1024QAM'
%
%  6) mcsIndex
%     MCS index (0–11):
%     → Automatically defines modulation + coding rate
%
%     Example mapping:
%       MCS 0  → BPSK
%       MCS 1–2 → QPSK
%       MCS 3–4 → 16QAM
%       MCS 5–7 → 64QAM
%       MCS 8–9 → 256QAM
%       MCS 10–11 → 1024QAM
%
%  7) ofdmFormat
%     Transmission mode:
%     → 'OFDM'       (Single user)
%     → 'MU-OFDMA'   (Multi-user)
%
%  8) numSymbols
%     Number of OFDM symbols:
%     → Controls waveform length
%
%  ------------------------------------------------------------------------
%  OPTIONAL PARAMETERS (Name-Value pairs)
%  ------------------------------------------------------------------------
%
%  --- Noise control ---
%  'ApplyTxNoise' : true/false
%       → Add AWGN noise at transmitter
%
%  'TxSNRdB' : numeric
%       → TX SNR (default = 30 dB)
%
%  'ApplyRxNoise' : true/false
%       → Add AWGN at receiver
%
%  'RxSNRdB' : numeric
%
%  --- Signal configuration ---
%  'OversamplingFactor' : integer ≥ 1
%  'NumPackets'         : number of packets
%  'IdleTime'           : time between packets
%
%  --- Plot control ---
%  'PlotDerivativeMetrics' : true/false
%       → Enable histogram plots
%
%  'HistogramBins' : integer
%       → Number of bins in PDF histogram
%
%  'PrintMetrics' : true/false
%       → Print statistics (std of derivatives, PAPR)
%
%  ------------------------------------------------------------------------
%  OUTPUT STRUCTURE
%  ------------------------------------------------------------------------
%
%  out.waveformTxIdeal   → Ideal TX waveform
%  out.waveformTxNoisy   → Noisy TX waveform
%  out.waveformRx        → RX waveform
%
%  out.derivatives:
%       .dEnvIdeal       → Envelope derivative (ideal)
%       .dEnvNoisy       → Envelope derivative (noisy)
%       .dPhIdeal        → Phase derivative (ideal)
%       .dPhNoisy        → Phase derivative (noisy)
%
%  out.papr:
%       → PAPR values (ideal / noisy / RX)
%
%  out.info:
%       → All configuration parameters + QAM label
%
%  ------------------------------------------------------------------------
%  EXAMPLE USAGE
%  ------------------------------------------------------------------------
%
%  % Example: 256-QAM, 20 MHz, noisy TX
%
%  out = generate_wlan_mcs_waveform2( ...
%      20, ...                % bandwidth (MHz)
%      0.8, ...               % guard interval (us)
%      'BCC', ...             % coding
%      1, ...                 % spatial streams
%      '256QAM', ...          % modulation
%      8, ...                 % MCS index
%      'OFDM', ...            % format
%      100, ...               % number of symbols
%      'ApplyTxNoise', true, ...
%      'TxSNRdB', 25, ...
%      'HistogramBins', 200);
%
%  ------------------------------------------------------------------------
%  NOTES
%  ------------------------------------------------------------------------
%
%  - Histograms are normalized as PDF (area = 1)
%  - No artificial bias is applied to the signal
%  - QAM order is automatically detected from MCS
%  - Figures are saved automatically as:
%        QAM256_...
%        QAM64_...
%        etc.
%
% ========================================================================


%% -------------------- Parse inputs --------------------
p = inputParser;

addRequired(p,'bandwidthMHz',@(x) isnumeric(x) && isscalar(x) && any(x==[20 40 80 160]));
addRequired(p,'GI_us',@(x) isnumeric(x) && isscalar(x) && any(abs(x-[0.8 1.6 3.2])<1e-12));
addRequired(p,'coding',@(x) ischar(x) || isstring(x));
addRequired(p,'nSS',@(x) isnumeric(x) && isscalar(x) && x>=1 && x<=8);
addRequired(p,'modulation',@(x) ischar(x) || isstring(x));
addRequired(p,'mcsIndex',@(x) isnumeric(x) && isscalar(x) && x>=0 && x<=11);
addRequired(p,'ofdmFormat',@(x) ischar(x) || isstring(x));
addRequired(p,'numSymbols',@(x) isnumeric(x) && isscalar(x) && x>=1);

addParameter(p,'NumUsers',[],@(x) isempty(x) || (isscalar(x) && x>=1));
addParameter(p,'AllocationIndex',[],@(x) isempty(x) || isnumeric(x) || isstring(x) || ischar(x));
addParameter(p,'NumPackets',1,@(x) isnumeric(x) && isscalar(x) && x>=1);
addParameter(p,'IdleTime',0,@(x) isnumeric(x) && isscalar(x) && x>=0);
addParameter(p,'OversamplingFactor',1,@(x) isnumeric(x) && isscalar(x) && x>=1);
addParameter(p,'NumTransmitAntennas',[],@(x) isempty(x) || (isscalar(x) && x>=1));
addParameter(p,'ScramblerInitialization',93,@(x) isnumeric(x));

addParameter(p,'ApplyTxNoise',false,@islogical);
addParameter(p,'TxSNRdB',30,@(x) isnumeric(x) && isscalar(x));
addParameter(p,'ApplyRxNoise',false,@islogical);
addParameter(p,'RxSNRdB',30,@(x) isnumeric(x) && isscalar(x));

addParameter(p,'PlotDerivativeMetrics',true,@islogical);
addParameter(p,'PrintMetrics',true,@islogical);
addParameter(p,'HistogramBins',200,@(x) isnumeric(x) && isscalar(x) && x>=10);

parse(p,bandwidthMHz,GI_us,coding,nSS,modulation,mcsIndex,ofdmFormat,numSymbols,varargin{:});
prm = p.Results;

coding     = upper(string(prm.coding));
modulation = upper(strrep(string(prm.modulation),' ',''));
fmt        = upper(string(prm.ofdmFormat));

if isempty(prm.NumTransmitAntennas)
    numTx = nSS;
else
    numTx = prm.NumTransmitAntennas;
end

if numTx < nSS
    error('NumTransmitAntennas must be >= nSS.');
end

%% -------------------- Validate MCS/modulation --------------------
[mcsMod, mcsRateNum, mcsRateDen, bitsPerSubcarrier] = localMCSMap(mcsIndex);
mcsModClean = upper(strrep(mcsMod,'-',''));
modClean    = upper(strrep(modulation,'-',''));

if modClean ~= mcsModClean
    error('Input modulation (%s) does not match HE MCS %d modulation (%s).', ...
        char(modulation), mcsIndex, char(mcsMod));
end

if coding ~= "BCC" && coding ~= "LDPC"
    error('coding must be ''BCC'' or ''LDPC''.');
end

rateStrExpected = sprintf('%d/%d',mcsRateNum,mcsRateDen);

%% -------------------- Auto naming from QAM order --------------------
M = localMCSOrder(mcsIndex);
if M == 2
    qamStr = 'BPSK';
else
    qamStr = sprintf('QAM%d', M);
end

%% -------------------- Build HE config --------------------
cbw = sprintf('CBW%d', bandwidthMHz);

switch fmt
    case "OFDM"
        cfg = wlanHESUConfig( ...
            'ChannelBandwidth', cbw, ...
            'GuardInterval', GI_us, ...
            'MCS', mcsIndex, ...
            'ChannelCoding', char(coding), ...
            'NumSpaceTimeStreams', nSS);

        cfg.NumTransmitAntennas = numTx;

        Nsd = localHEDataSubcarriersFullBand(bandwidthMHz);
        apepBytes = localEstimateAPEPLengthBytes(numSymbols, Nsd, bitsPerSubcarrier, ...
            mcsRateNum/mcsRateDen, nSS);

        try
            cfg.APEPLength = apepBytes;
        catch
        end

        try
            psduLengthBytes = getPSDULength(cfg);
        catch
            psduLengthBytes = apepBytes;
        end

        psdu = randi([0 1], 8*psduLengthBytes, 1, 'int8');

    case "MU-OFDMA"
        if isempty(prm.AllocationIndex)
            allocationIndex = localDefaultAllocationIndex(bandwidthMHz, prm.NumUsers);
        else
            allocationIndex = prm.AllocationIndex;
        end

        cfg = wlanHEMUConfig(allocationIndex);
        cfg.GuardInterval = GI_us;
        cfg.NumTransmitAntennas = numTx;

        allocInfo = ruInfo(cfg);
        numUsersInCfg = allocInfo.NumUsers;

        if ~isempty(prm.NumUsers) && prm.NumUsers ~= numUsersInCfg
            warning(['Requested NumUsers=%d but selected allocation creates %d users. ' ...
                     'Using %d users from the allocation.'], ...
                     prm.NumUsers, numUsersInCfg, numUsersInCfg);
        end

        for u = 1:numUsersInCfg
            cfg.User{u}.MCS = mcsIndex;
            cfg.User{u}.NumSpaceTimeStreams = nSS;
            cfg.User{u}.ChannelCoding = char(coding);

            ruNum   = cfg.User{u}.RUNumber;
            ruSize  = cfg.RU{ruNum}.Size;
            NsdUser = localHEDataSubcarriersFromRUSize(ruSize);

            apepBytes = localEstimateAPEPLengthBytes(numSymbols, NsdUser, bitsPerSubcarrier, ...
                mcsRateNum/mcsRateDen, nSS);

            cfg.User{u}.APEPLength = apepBytes;
        end

        try
            psduLengthBytes = getPSDULength(cfg);
        catch
            psduLengthBytes = zeros(1,numUsersInCfg);
            for u = 1:numUsersInCfg
                psduLengthBytes(u) = cfg.User{u}.APEPLength;
            end
        end

        psdu = cell(1, numUsersInCfg);
        for u = 1:numUsersInCfg
            psdu{u} = randi([0 1], 8*psduLengthBytes(u), 1, 'int8');
        end

    otherwise
        error('ofdmFormat must be ''OFDM'' or ''MU-OFDMA''.');
end

%% -------------------- Generate ideal TX waveform --------------------
waveformTxIdeal = wlanWaveformGenerator(psdu, cfg, ...
    'NumPackets', prm.NumPackets, ...
    'IdleTime', prm.IdleTime, ...
    'OversamplingFactor', prm.OversamplingFactor, ...
    'ScramblerInitialization', prm.ScramblerInitialization);

fs = wlanSampleRate(cfg, 'OversamplingFactor', prm.OversamplingFactor);

%% -------------------- Apply TX noise --------------------
if prm.ApplyTxNoise
    waveformTxNoisy = awgn(waveformTxIdeal, prm.TxSNRdB, 'measured');
else
    waveformTxNoisy = waveformTxIdeal;
end

%% -------------------- Apply RX noise --------------------
if prm.ApplyRxNoise
    waveformRx = awgn(waveformTxNoisy, prm.RxSNRdB, 'measured');
else
    waveformRx = waveformTxNoisy;
end

%% -------------------- PAPR calculation --------------------
papr = struct();

papr.txIdealLinear = localPAPRLinear(waveformTxIdeal(:,1));
papr.txIdealdB     = 10*log10(papr.txIdealLinear);

papr.txNoisyLinear = localPAPRLinear(waveformTxNoisy(:,1));
papr.txNoisydB     = 10*log10(papr.txNoisyLinear);

papr.rxLinear      = localPAPRLinear(waveformRx(:,1));
papr.rxdB          = 10*log10(papr.rxLinear);

if prm.PrintMetrics
    fprintf('PAPR (ideal TX) = %.3f dB\n', papr.txIdealdB);
    fprintf('PAPR (noisy TX) = %.3f dB\n', papr.txNoisydB);
    fprintf('PAPR (RX)       = %.3f dB\n', papr.rxdB);
end

%% -------------------- Derivative metrics from time-domain TX --------------------
xIdeal = waveformTxIdeal(:,1);
xNoisy = waveformTxNoisy(:,1);

envIdeal = abs(xIdeal);
envNoisy = abs(xNoisy);

dEnvIdeal = diff(envIdeal);
dEnvNoisy = diff(envNoisy);

phIdeal = unwrap(angle(xIdeal));
phNoisy = unwrap(angle(xNoisy));

dPhIdeal = diff(phIdeal);
dPhNoisy = diff(phNoisy);

metrics = struct();
metrics.envIdeal  = envIdeal;
metrics.envNoisy  = envNoisy;
metrics.dEnvIdeal = dEnvIdeal;
metrics.dEnvNoisy = dEnvNoisy;
metrics.phIdeal   = phIdeal;
metrics.phNoisy   = phNoisy;
metrics.dPhIdeal  = dPhIdeal;
metrics.dPhNoisy  = dPhNoisy;

if prm.PrintMetrics
    fprintf('Std(d|x|) ideal TX = %.6e\n', std(dEnvIdeal));
    fprintf('Std(d|x|) noisy TX = %.6e\n', std(dEnvNoisy));
    fprintf('Std(dPhase) ideal TX = %.6e rad/sample\n', std(dPhIdeal));
    fprintf('Std(dPhase) noisy TX = %.6e rad/sample\n', std(dPhNoisy));
end

%% -------------------- Only plots: separate histograms --------------------
if prm.PlotDerivativeMetrics
    nbins = prm.HistogramBins;


    % ------------- Ideal TX: envelope --------------
    figure;
    histogram(envIdeal, nbins, 'Normalization', 'pdf');
    grid on;
    xlabel('|x[n]|');
    ylabel('PDF');
    title(sprintf('Envelope Histogram: Ideal TX (%s)', qamStr));
    legend('Ideal TX');
    saveas(gcf, sprintf('%s_envelope_histogram_ideal_tx.svg', qamStr));
    saveas(gcf, sprintf('%s_envelope_histogram_ideal_tx.png', qamStr));

    % -------- Ideal TX: envelope derivative --------
    figure;
    histogram(dEnvIdeal, nbins, 'Normalization', 'pdf');
    grid on;
    xlabel('\Delta|x[n]|');
    ylabel('PDF');
    title(sprintf('Envelope Derivative Histogram: Ideal TX (%s)', qamStr));
    legend('Ideal TX');
    saveas(gcf, sprintf('%s_envelope_derivative_histogram_ideal_tx.svg', qamStr));
    saveas(gcf, sprintf('%s_envelope_derivative_histogram_ideal_tx.png', qamStr));

    % -------- Noisy TX: envelope derivative --------
    % figure;
    % histogram(dEnvNoisy, nbins, 'Normalization', 'pdf');
    % grid on;
    % xlabel('\Delta|x[n]|');
    % ylabel('PDF');
    % title(sprintf('Envelope Derivative Histogram: Noisy TX (%s)', qamStr));
    % legend('Noisy TX');
    % saveas(gcf, sprintf('%s_envelope_derivative_histogram_noisy_tx.svg', qamStr));
    % saveas(gcf, sprintf('%s_envelope_derivative_histogram_noisy_tx.png', qamStr));

    % -------- Ideal TX: phase derivative --------
    figure;
    histogram(dPhIdeal, nbins, 'Normalization', 'pdf');
    grid on;
    xlabel('\Delta\angle x[n] (rad/sample)');
    ylabel('PDF');
    title(sprintf('Phase Derivative Histogram: Ideal TX (%s)', qamStr));
    legend('Ideal TX');
    saveas(gcf, sprintf('%s_phase_derivative_histogram_ideal_tx.svg', qamStr));
    saveas(gcf, sprintf('%s_phase_derivative_histogram_ideal_tx.png', qamStr));


    % ------------- Ideal TX: phase -------------
    figure;
    histogram(phIdeal, nbins, 'Normalization', 'pdf');
    grid on;
    xlabel('\Delta\angle x[n] (rad/sample)');
    ylabel('PDF');
    title(sprintf('Phase Histogram: Ideal TX (%s)', qamStr));
    legend('Ideal TX');
    saveas(gcf, sprintf('%s_phase_histogram_ideal_tx.svg', qamStr));
    saveas(gcf, sprintf('%s_phase_histogram_ideal_tx.png', qamStr));


    % -------- Noisy TX: phase derivative --------
    % figure;
    % histogram(dPhNoisy, nbins, 'Normalization', 'pdf');
    % grid on;
    % xlabel('\Delta\angle x[n] (rad/sample)');
    % ylabel('PDF');
    % title(sprintf('Phase Derivative Histogram: Noisy TX (%s)', qamStr));
    % legend('Noisy TX');
    % saveas(gcf, sprintf('%s_phase_derivative_histogram_noisy_tx.svg', qamStr));
    % saveas(gcf, sprintf('%s_phase_derivative_histogram_noisy_tx.png', qamStr));
end

%% -------------------- Info struct --------------------
info = struct();
info.Format              = char(fmt);
info.ChannelBandwidth    = cbw;
info.GI_us               = GI_us;
info.Coding              = char(coding);
info.NSS                 = nSS;
info.Modulation          = char(mcsMod);
info.MCS                 = mcsIndex;
info.MCSRate             = rateStrExpected;
info.QAMLabel            = qamStr;
info.NumSymbolsRequested = numSymbols;
info.NumTxAntennas       = numTx;
info.SampleRate_Hz       = fs;
info.NumSamplesTxIdeal   = size(waveformTxIdeal,1);
info.NumSamplesTxNoisy   = size(waveformTxNoisy,1);
info.NumSamplesRx        = size(waveformRx,1);
info.ApplyTxNoise        = prm.ApplyTxNoise;
info.TxSNRdB             = prm.TxSNRdB;
info.ApplyRxNoise        = prm.ApplyRxNoise;
info.RxSNRdB             = prm.RxSNRdB;
info.PAPR_TxIdeal_dB     = papr.txIdealdB;
info.PAPR_TxNoisy_dB     = papr.txNoisydB;
info.PAPR_Rx_dB          = papr.rxdB;

if fmt == "MU-OFDMA"
    allocInfo = ruInfo(cfg);
    info.NumUsers        = allocInfo.NumUsers;
    info.NumRUs          = allocInfo.NumRUs;
    info.RUSizes         = allocInfo.RUSizes;
    info.RUIndices       = allocInfo.RUIndices;
    info.AllocationIndex = allocationIndex;
else
    info.NumUsers = 1;
end

%% -------------------- Output struct --------------------
out = struct();
out.waveformTxIdeal = waveformTxIdeal;
out.waveformTxNoisy = waveformTxNoisy;
out.waveformRx      = waveformRx;
out.cfg             = cfg;
out.fs              = fs;
out.psdu            = psdu;
out.derivatives     = metrics;
out.papr            = papr;
out.info            = info;

end

%==========================================================================
function [modulation, rateNum, rateDen, Nbpscs] = localMCSMap(mcs)
switch mcs
    case 0
        modulation = "BPSK";     rateNum = 1; rateDen = 2; Nbpscs = 1;
    case 1
        modulation = "QPSK";     rateNum = 1; rateDen = 2; Nbpscs = 2;
    case 2
        modulation = "QPSK";     rateNum = 3; rateDen = 4; Nbpscs = 2;
    case 3
        modulation = "16QAM";    rateNum = 1; rateDen = 2; Nbpscs = 4;
    case 4
        modulation = "16QAM";    rateNum = 3; rateDen = 4; Nbpscs = 4;
    case 5
        modulation = "64QAM";    rateNum = 2; rateDen = 3; Nbpscs = 6;
    case 6
        modulation = "64QAM";    rateNum = 3; rateDen = 4; Nbpscs = 6;
    case 7
        modulation = "64QAM";    rateNum = 5; rateDen = 6; Nbpscs = 6;
    case 8
        modulation = "256QAM";   rateNum = 3; rateDen = 4; Nbpscs = 8;
    case 9
        modulation = "256QAM";   rateNum = 5; rateDen = 6; Nbpscs = 8;
    case 10
        modulation = "1024QAM";  rateNum = 3; rateDen = 4; Nbpscs = 10;
    case 11
        modulation = "1024QAM";  rateNum = 5; rateDen = 6; Nbpscs = 10;
    otherwise
        error('Unsupported HE MCS index.');
end
end

%==========================================================================
function Nsd = localHEDataSubcarriersFullBand(bwMHz)
switch bwMHz
    case 20
        Nsd = 234;
    case 40
        Nsd = 468;
    case 80
        Nsd = 980;
    case 160
        Nsd = 1960;
    otherwise
        error('Unsupported bandwidth.');
end
end

%==========================================================================
function Nsd = localHEDataSubcarriersFromRUSize(ruSize)
switch ruSize
    case 26
        Nsd = 24;
    case 52
        Nsd = 48;
    case 106
        Nsd = 102;
    case 242
        Nsd = 234;
    case 484
        Nsd = 468;
    case 996
        Nsd = 980;
    case 2*996
        Nsd = 1960;
    otherwise
        error('Unsupported RU size %g.', ruSize);
end
end

%==========================================================================
function apepBytes = localEstimateAPEPLengthBytes(numSymbols, Nsd, Nbpscs, codeRate, nSS)
bitsPerSym = Nsd * Nbpscs * codeRate * nSS;
payloadBits = floor(numSymbols * bitsPerSym);
payloadBits = max(payloadBits - 32, 8);
apepBytes = max(1, floor(payloadBits / 8));
end

%==========================================================================
function allocationIndex = localDefaultAllocationIndex(bwMHz, numUsers)

if isempty(numUsers)
    numUsers = [];
end

switch bwMHz
    case 20
        if isempty(numUsers)
            allocationIndex = 192;
        elseif numUsers == 1
            allocationIndex = 192;
        elseif numUsers == 3
            allocationIndex = 128;
        elseif numUsers == 4
            allocationIndex = 112;
        else
            error(['For 20 MHz auto-allocation, supported NumUsers are 1, 3, or 4. ' ...
                   'Otherwise provide ''AllocationIndex'' manually.']);
        end

    case 40
        allocationIndex = [192 192];

    case 80
        allocationIndex = [192 192 192 192];

    case 160
        allocationIndex = [192 192 192 192 192 192 192 192];

    otherwise
        error('Unsupported bandwidth for auto allocation.');
end
end

%==========================================================================
function M = localMCSOrder(mcsIndex)
switch mcsIndex
    case 0
        M = 2;
    case {1,2}
        M = 4;
    case {3,4}
        M = 16;
    case {5,6,7}
        M = 64;
    case {8,9}
        M = 256;
    case {10,11}
        M = 1024;
    otherwise
        error('Unsupported MCS index.');
end
end

%==========================================================================
function paprLinear = localPAPRLinear(x)
x = x(:);
p = abs(x).^2;
paprLinear = max(p) / mean(p);
end