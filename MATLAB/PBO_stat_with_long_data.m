clc;
clear;
close all;

%% ========================================================================
%  M-QAM waveform generation + CCDF/PAPR analysis
%
%  This version plots the PDFs of:
%     1) Envelope
%     2) Phase
%     3) Envelope derivative
%     4) Phase derivative
%
%  for samples whose relative power lies in the range:
%
%     0 dB  <=  relative power  <=  (99.9th percentile PAPR - 1 dB)
%
%% ========================================================================

%% Parameters
M   = 256;
k   = log2(M);
sps = 4;

bitRate = 100e6;              % [bits/s]
symRate = bitRate / k;        % [symbols/s]
Tsym    = 1 / symRate;        % [s]
Fs      = symRate * sps;      % [samples/s]
Ts      = 1 / Fs;             % [s]

mem_mb = 1;                   % increase for smoother PDFs
mem    = 8 * mem_mb * 2^20;   % [bits]
time   = mem / bitRate;       % [s]

filtLen = 12;                 % RRC span in symbols
rolloff = 0.35;
rrcFilter = rcosdesign(rolloff, filtLen, sps);

zeroPad = zeros(10*filtLen,1);
zeroPadLen = numel(zeroPad);

%% Derived sizes
numBits = floor(mem);
numSyms = floor(numBits / k);
numBits = numSyms * k;

fprintf('====================================================\n');
fprintf('Waveform setup\n');
fprintf('====================================================\n');
fprintf('M-QAM order           = %d\n', M);
fprintf('Bits/symbol           = %d\n', k);
fprintf('Samples/symbol        = %d\n', sps);
fprintf('Bit rate              = %.3f Mb/s\n', bitRate/1e6);
fprintf('Symbol rate           = %.3f Msymbol/s\n', symRate/1e6);
fprintf('Sample rate           = %.3f Msample/s\n', Fs/1e6);
fprintf('Memory                = %.3f MB\n', mem_mb);
fprintf('Total bits            = %d\n', numBits);
fprintf('Total symbols         = %d\n', numSyms);
fprintf('Waveform duration     = %.6f s\n', time);
fprintf('RRC rolloff           = %.2f\n', rolloff);
fprintf('RRC span              = %d symbols\n', filtLen);

%% Generate random bit stream
txBits = randi([0 1], numBits, 1);

%% QAM modulation
qamSyms = qammod(txBits, M, ...
    'InputType', 'bit', ...
    'UnitAveragePower', true);

%% Zero padding
txSymsPad = [zeroPad; qamSyms; zeroPad];

%% Pulse shaping
txWave = upfirdn(txSymsPad, rrcFilter, sps, 1);

%% Remove filter transients
grpDelay = filtLen * sps / 2;
trimStart = grpDelay + sps*zeroPadLen + 1;
trimEnd   = length(txWave) - grpDelay - sps*zeroPadLen;
txWaveTrim = txWave(trimStart:trimEnd);

%% Signal quantities
env = abs(txWaveTrim);
ph  = angle(txWaveTrim);
ph_unwrap = unwrap(ph);

%% Derivatives
dEnv = diff(env) / Ts;
dPh  = diff(ph_unwrap) / Ts;

%% Relative power and PAPR statistics
powerInst   = abs(txWaveTrim).^2;
powerAvg    = mean(powerInst);
relPower    = powerInst / powerAvg;
relPower_dB = 10*log10(relPower);

papr_max_dB   = max(relPower_dB);
papr_99_dB    = prctile(relPower_dB, 99);
papr_99_9_dB  = prctile(relPower_dB, 99.9);

fprintf('\n====================================================\n');
fprintf('PAPR statistics\n');
fprintf('====================================================\n');
fprintf('Max PAPR              = %.3f dB\n', papr_max_dB);
fprintf('99%% PAPR              = %.3f dB\n', papr_99_dB);
fprintf('99.9%% PAPR            = %.3f dB\n', papr_99_9_dB);

%% CCDF calculation
paprAxis_dB = 0:0.05:15;
ccdf = zeros(size(paprAxis_dB));

for i = 1:length(paprAxis_dB)
    ccdf(i) = mean(relPower_dB > paprAxis_dB(i));
end

ccdf_percent = 100 * ccdf;

%% Correct selection window
% User requested:
%   samples whose power lies in the band from 0 dB
%   up to 1 dB below the 99.9th-percentile PAPR
lowerBound_dB = min(relPower_dB);
upperBound_dB = papr_99_9_dB - 1;

fprintf('\n====================================================\n');
fprintf('Selected power window\n');
fprintf('====================================================\n');
fprintf('Lower bound            = %.3f dB\n', lowerBound_dB);
fprintf('Upper bound            = %.3f dB\n', upperBound_dB);
fprintf('Window meaning         = [0 dB, 99.9%% PAPR - 1 dB]\n');

if upperBound_dB <= lowerBound_dB
    error('Upper bound is not larger than lower bound. Increase waveform length or inspect the PAPR statistics.');
end

%% Select samples in the requested power window
mask_samples = (relPower_dB >= lowerBound_dB) & (relPower_dB <= upperBound_dB);

env_sel = env(mask_samples);
ph_sel  = ph(mask_samples);

%% Select derivative samples whose two endpoints are both in the same window
mask_diff = mask_samples(1:end-1) & mask_samples(2:end);

dEnv_sel = dEnv(mask_diff);
dPh_sel  = dPh(mask_diff);

fprintf('Selected envelope/phase samples     = %d\n', numel(env_sel));
fprintf('Selected derivative samples         = %d\n', numel(dEnv_sel));

if isempty(env_sel)
    error('No samples found in the selected power window. Increase mem_mb.');
end

if isempty(dEnv_sel)
    error('No derivative samples found in the selected power window. Increase mem_mb.');
end

%% Plot 1: CCDF as probability
figure;
semilogy(paprAxis_dB, ccdf, 'LineWidth', 2);
hold on;
xline(papr_99_9_dB, '--', '99.9% PAPR', 'LineWidth', 1.5);
xline(upperBound_dB, '-.', '99.9% - 1 dB', 'LineWidth', 1.5);
xline(lowerBound_dB, ':', '0 dB', 'LineWidth', 1.5);
grid on;
xlabel('Relative Power (dB)');
ylabel('CCDF = Pr(P(t) > Threshold)');
title(sprintf('CCDF of Relative Power for %d-QAM (RRC, rolloff = %.2f)', M, rolloff));
xlim([0 15]);
ylim([1e-5 1]);

%% Plot 2: CCDF as percentage
figure;
semilogy(paprAxis_dB, ccdf_percent, 'LineWidth', 2);
hold on;
xline(papr_99_9_dB, '--', '99.9% PAPR', 'LineWidth', 1.5);
xline(upperBound_dB, '-.', '99.9% - 1 dB', 'LineWidth', 1.5);
xline(lowerBound_dB, ':', '0 dB', 'LineWidth', 1.5);
grid on;
xlabel('Relative Power (dB)');
ylabel('Time Above Level (%)');
title(sprintf('CCDF (Percentage) for %d-QAM (RRC, rolloff = %.2f)', M, rolloff));
xlim([0 15]);
ylim([1e-3 100]);

%% Plot 3: Envelope PDF
figure;
histogram(env_sel, 200, 'Normalization', 'pdf');
grid on;
xlabel('Envelope');
ylabel('PDF');
title(sprintf('Envelope PDF for %.2f dB <= PAPR <= %.2f dB', lowerBound_dB, upperBound_dB));

%% Plot 4: Phase PDF
figure;
histogram(ph_sel, 200, 'Normalization', 'pdf');
grid on;
xlabel('Phase (rad)');
ylabel('PDF');
title(sprintf('Phase PDF for %.2f dB <= PAPR <= %.2f dB', lowerBound_dB, upperBound_dB));

%% Plot 5: Envelope derivative PDF
figure;
histogram(dEnv_sel, 200, 'Normalization', 'pdf');
grid on;
xlabel('d|x(t)|/dt');
ylabel('PDF');
title(sprintf('Envelope Derivative PDF for %.2f dB <= PAPR <= %.2f dB', lowerBound_dB, upperBound_dB));

%% Plot 6: Phase derivative PDF
figure;
histogram(dPh_sel, 200, 'Normalization', 'pdf');
grid on;
xlabel('d\phi(t)/dt (rad/s)');
ylabel('PDF');
title(sprintf('Phase Derivative PDF for %.2f dB <= PAPR <= %.2f dB', lowerBound_dB, upperBound_dB));

%% Combined 2x2 figure
figure;

subplot(2,2,1);
histogram(env_sel, 200, 'Normalization', 'pdf');
grid on;
xlabel('Envelope');
ylabel('PDF');
title('Envelope PDF');

subplot(2,2,2);
histogram(ph_sel, 200, 'Normalization', 'pdf');
grid on;
xlabel('Phase (rad)');
ylabel('PDF');
title('Phase PDF');

subplot(2,2,3);
histogram(dEnv_sel, 200, 'Normalization', 'pdf');
grid on;
xlabel('d|x(t)|/dt');
ylabel('PDF');
title('Envelope Derivative PDF');

subplot(2,2,4);
histogram(dPh_sel, 200, 'Normalization', 'pdf');
grid on;
xlabel('d\phi(t)/dt (rad/s)');
ylabel('PDF');
title('Phase Derivative PDF');

sgtitle(sprintf('PDFs for %.2f dB <= PAPR <= %.2f dB', lowerBound_dB, upperBound_dB));

%% Optional time-domain view of selected samples
selectedIdx = find(mask_samples);

if ~isempty(selectedIdx)
    Nshow = min(1000, numel(selectedIdx));
    idxShow = selectedIdx(1:Nshow);
    tShow = (idxShow - 1) * Ts * 1e9;   % ns

    figure;
    plot(tShow, env(idxShow), '.-');
    grid on;
    xlabel('Time (ns)');
    ylabel('Envelope');
    title('Envelope of Samples in Selected Power Window');

    figure;
    plot(tShow, ph(idxShow), '.-');
    grid on;
    xlabel('Time (ns)');
    ylabel('Phase (rad)');
    title('Phase of Samples in Selected Power Window');
end