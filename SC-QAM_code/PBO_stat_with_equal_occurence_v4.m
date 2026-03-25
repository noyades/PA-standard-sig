clear;
close all;
clc;

%% ================================================================
% TRUE POWER BACK-OFF SCALING
%
% This version:
% 1) Generates ideal QAM waveform
% 2) Finds best roll-off from minimum PAPR
% 3) Applies TRUE power back-off by scaling waveform:
%
%       x_bo = x * 10^(-BO_dB/20)
%
% 4) Compares PDFs of:
%       - envelope
%       - phase
%       - derivative of envelope
%       - derivative of phase
%
% against the original ideal waveform
%% ================================================================

%% ---------------- USER SETTINGS ----------------
M = 256;
qamStr = sprintf('%dQAM', M);

sps = 4;
filtLen = 12;
numSymbolsPerConstPoint = 2000;     % reduce if memory is large
ampScale = 4;
numBins = 200;
rolloffCandidates = [0.15 0.25 0.35 0.45];

% TRUE back-off values in dB
backoffList_dB = [0.25 0.5 1.0];

shuffleSymbols = true;
printSummary = true;

rng('default');

%% ---------------- VALIDATION ----------------
if isscalar(numSymbolsPerConstPoint)
    if numSymbolsPerConstPoint <= 0 || floor(numSymbolsPerConstPoint) ~= numSymbolsPerConstPoint
        error('numSymbolsPerConstPoint must be a positive integer scalar.');
    end
    symbolsPerPointVec = repmat(numSymbolsPerConstPoint, M, 1);
else
    if ~isvector(numSymbolsPerConstPoint) || numel(numSymbolsPerConstPoint) ~= M
        error('If numSymbolsPerConstPoint is not scalar, it must be a vector of length M.');
    end
    symbolsPerPointVec = numSymbolsPerConstPoint(:);
    if any(symbolsPerPointVec <= 0) || any(floor(symbolsPerPointVec) ~= symbolsPerPointVec)
        error('All elements of numSymbolsPerConstPoint must be positive integers.');
    end
end

%% ---------------- GENERATE SYMBOLS ----------------
symIdx = [];
for kk = 0:M-1
    symIdx = [symIdx; repmat(kk, symbolsPerPointVec(kk+1), 1)]; %#ok<AGROW>
end

if shuffleSymbols
    symIdx = symIdx(randperm(numel(symIdx)));
end

Nsym = numel(symIdx);
txSym = qammod(symIdx, M, 'UnitAveragePower', true);

%% ---------------- ROLL-OFF SWEEP ----------------
numR = numel(rolloffCandidates);
paprList_dB = zeros(numR,1);

bestPAPR_dB = inf;
bestRolloff = rolloffCandidates(1);
bestTxWave = [];

for k = 1:numR
    rolloff = rolloffCandidates(k);
    rrcFilter = rcosdesign(rolloff, filtLen, sps);

    zeroPad = zeros(10*filtLen,1);
    zeroPadLen = numel(zeroPad);

    preDelayTX = sps*(filtLen/2) + 1 + sps*zeroPadLen;

    dataModPad = [zeroPad; txSym; zeroPad];
    txFiltSig  = upfirdn(dataModPad, rrcFilter, sps, 1);

    startIdx = preDelayTX;
    stopIdx  = startIdx + numel(txSym)*sps - 1;

    txSlice = txFiltSig(startIdx:stopIdx);
    txSlice = ampScale * txSlice;

    sigPower = abs(txSlice).^2;
    papr_dB = 10*log10(max(sigPower) / mean(sigPower));
    paprList_dB(k) = papr_dB;

    if papr_dB < bestPAPR_dB
        bestPAPR_dB = papr_dB;
        bestRolloff = rolloff;
        bestTxWave = txSlice;
    end
end

%% ---------------- IDEAL WAVEFORM ----------------
txIdeal = bestTxWave;

envIdeal = abs(txIdeal);
phaseIdeal = angle(txIdeal);
phaseIdealUnwrap = unwrap(phaseIdeal);

dEnvIdeal = diff(envIdeal);
dPhaseIdeal = diff(phaseIdealUnwrap);

Pideal = abs(txIdeal).^2;
meanPowerIdeal = mean(Pideal);

if printSummary
    fprintf('============================================\n');
    fprintf('TRUE POWER BACK-OFF VERSION\n');
    fprintf('Best roll-off = %.2f\n', bestRolloff);
    fprintf('Best PAPR     = %.4f dB\n', bestPAPR_dB);
    fprintf('Mean power    = %.6f\n', meanPowerIdeal);
    fprintf('============================================\n');
end

%% ---------------- IDEAL FULL PDFs ----------------
figure;
histogram(envIdeal, numBins, 'Normalization', 'pdf');
grid on;
xlabel('Envelope');
ylabel('PDF');
title(sprintf('Ideal Envelope PDF - %s', qamStr));

figure;
histogram(phaseIdeal, numBins, 'Normalization', 'pdf');
grid on;
xlabel('Phase (rad)');
ylabel('PDF');
title(sprintf('Ideal Phase PDF - %s', qamStr));

figure;
histogram(dEnvIdeal, numBins, 'Normalization', 'pdf');
grid on;
xlabel('\Delta Envelope');
ylabel('PDF');
title(sprintf('Ideal Envelope Derivative PDF - %s', qamStr));

figure;
histogram(dPhaseIdeal, numBins, 'Normalization', 'pdf');
grid on;
xlabel('\Delta Phase (rad/sample)');
ylabel('PDF');
title(sprintf('Ideal Phase Derivative PDF - %s', qamStr));

%% ---------------- TRUE BACK-OFF ANALYSIS ----------------
for ii = 1:numel(backoffList_dB)
    BO_dB = backoffList_dB(ii);

    % True power back-off
    scale = 10^(-BO_dB/20);
    txBO = txIdeal * scale;

    envBO = abs(txBO);
    phaseBO = angle(txBO);
    dEnvBO = diff(envBO);
    dPhaseBO = diff(unwrap(phaseBO));

    fprintf('\n=== TRUE POWER BACK-OFF = %.2f dB ===\n', BO_dB);
    fprintf('Amplitude scale factor = %.6f\n', scale);
    fprintf('Mean power before      = %.6f\n', mean(abs(txIdeal).^2));
    fprintf('Mean power after       = %.6f\n', mean(abs(txBO).^2));
    fprintf('Expected power ratio   = %.6f\n', 10^(-BO_dB/10));

    figure;
    histogram(envIdeal, numBins, 'Normalization', 'pdf');
    hold on;
    histogram(envBO, numBins, 'Normalization', 'pdf');
    grid on;
    xlabel('Envelope');
    ylabel('PDF');
    title(sprintf('Envelope PDF: Ideal vs %.2f dB Back-Off', BO_dB));
    legend('Ideal', 'Back-Off');

    figure;
    histogram(phaseIdeal, numBins, 'Normalization', 'pdf');
    hold on;
    histogram(phaseBO, numBins, 'Normalization', 'pdf');
    grid on;
    xlabel('Phase (rad)');
    ylabel('PDF');
    title(sprintf('Phase PDF: Ideal vs %.2f dB Back-Off', BO_dB));
    legend('Ideal', 'Back-Off');

    figure;
    histogram(dEnvIdeal, numBins, 'Normalization', 'pdf');
    hold on;
    histogram(dEnvBO, numBins, 'Normalization', 'pdf');
    grid on;
    xlabel('\Delta Envelope');
    ylabel('PDF');
    title(sprintf('Envelope Derivative PDF: Ideal vs %.2f dB Back-Off', BO_dB));
    legend('Ideal', 'Back-Off');

    figure;
    histogram(dPhaseIdeal, numBins, 'Normalization', 'pdf');
    hold on;
    histogram(dPhaseBO, numBins, 'Normalization', 'pdf');
    grid on;
    xlabel('\Delta Phase (rad/sample)');
    ylabel('PDF');
    title(sprintf('Phase Derivative PDF: Ideal vs %.2f dB Back-Off', BO_dB));
    legend('Ideal', 'Back-Off');
end

%% ---------------- PAPR VS ROLL-OFF ----------------
figure;
plot(rolloffCandidates, paprList_dB, '-o', 'LineWidth', 1.5, 'MarkerSize', 7);
grid on;
xlabel('Roll-off Factor');
ylabel('PAPR (dB)');
title(sprintf('PAPR vs Roll-off Factor for Ideal %s', qamStr));