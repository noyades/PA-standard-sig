clear;
close all;
clc;

%% ================================================================
% INSTANTANEOUS-POWER REGION ANALYSIS
%
% This version:
% 1) Generates ideal QAM waveform
% 2) Finds best roll-off from minimum PAPR
% 3) Computes instantaneous relative power:
%
%       P_rel_dB[n] = 10*log10(|x[n]|^2 / mean(|x[n]|^2))
%
% 4) Selects samples in regions:
%       0 to +BO_dB
%      -BO_dB to 0
%
% 5) Plots PDFs of:
%       - envelope
%       - phase
%       - derivative of envelope
%       - derivative of phase
%
% This is NOT true power back-off.
%% ================================================================

%% ---------------- USER SETTINGS ----------------
M = 256;
qamStr = sprintf('%dQAM', M);

sps = 4;
filtLen = 12;
numSymbolsPerConstPoint = 2000;
ampScale = 4;
numBins = 200;
rolloffCandidates = [0.15 0.25 0.35 0.45];
regionList_dB = [0.25 0.5 1.0];

shuffleSymbols = true;
printSummary = true;

% Optional mask to avoid unstable phase at very small envelope
useMinEnvelopeMask = true;
minEnvelopeRatio = 0.05;   % keep only samples with env >= 5% of max env

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

%% ---------------- BEST WAVEFORM ----------------
txIdeal = bestTxWave;

env = abs(txIdeal);
phaseWrapped = angle(txIdeal);
phaseUnwrapped = unwrap(phaseWrapped);

dEnv = diff(env);
dPhase = diff(phaseUnwrapped);

P = abs(txIdeal).^2;
Pmean = mean(P);
P_rel_dB = 10*log10(P / Pmean);

if useMinEnvelopeMask
    envMask = env >= minEnvelopeRatio * max(env);
else
    envMask = true(size(env));
end

if printSummary
    fprintf('============================================\n');
    fprintf('INSTANTANEOUS-POWER REGION ANALYSIS\n');
    fprintf('Best roll-off = %.2f\n', bestRolloff);
    fprintf('Best PAPR     = %.4f dB\n', bestPAPR_dB);
    fprintf('Mean power    = %.6f\n', Pmean);
    fprintf('Envelope mask = %d\n', useMinEnvelopeMask);
    if useMinEnvelopeMask
        fprintf('Min env ratio = %.4f of max envelope\n', minEnvelopeRatio);
    end
    fprintf('============================================\n');
end

%% ---------------- FULL PDFs ----------------
figure;
histogram(env, numBins, 'Normalization', 'pdf');
grid on;
xlabel('Envelope');
ylabel('PDF');
title(sprintf('Full Envelope PDF - Ideal %s', qamStr));

figure;
histogram(phaseWrapped(envMask), numBins, 'Normalization', 'pdf');
grid on;
xlabel('Phase (rad)');
ylabel('PDF');
title(sprintf('Full Phase PDF - Ideal %s', qamStr));

figure;
histogram(dEnv, numBins, 'Normalization', 'pdf');
grid on;
xlabel('\Delta Envelope');
ylabel('PDF');
title(sprintf('Full Envelope Derivative PDF - Ideal %s', qamStr));

dPhaseMaskFull = envMask(1:end-1) & envMask(2:end);
figure;
histogram(dPhase(dPhaseMaskFull), numBins, 'Normalization', 'pdf');
grid on;
xlabel('\Delta Phase (rad/sample)');
ylabel('PDF');
title(sprintf('Full Phase Derivative PDF - Ideal %s', qamStr));

%% ---------------- REGION ANALYSIS ----------------
for ii = 1:numel(regionList_dB)
    win_dB = regionList_dB(ii);

    % Positive region: 0 to +win_dB
    idxPos = (P_rel_dB >= 0) & (P_rel_dB < win_dB) & envMask;
    idxPosDeriv = idxPos(1:end-1) & idxPos(2:end);

    env_pos = env(idxPos);
    phase_pos = phaseWrapped(idxPos);
    dEnv_pos = dEnv(idxPosDeriv);
    dPhase_pos = dPhase(idxPosDeriv);

    % Negative region: -win_dB to 0
    idxNeg = (P_rel_dB >= -win_dB) & (P_rel_dB < 0) & envMask;
    idxNegDeriv = idxNeg(1:end-1) & idxNeg(2:end);

    env_neg = env(idxNeg);
    phase_neg = phaseWrapped(idxNeg);
    dEnv_neg = dEnv(idxNegDeriv);
    dPhase_neg = dPhase(idxNegDeriv);

    fprintf('\n=========== REGION WIDTH = %.2f dB ===========\n', win_dB);
    fprintf('Positive region samples           = %d\n', numel(env_pos));
    fprintf('Positive dEnv samples             = %d\n', numel(dEnv_pos));
    fprintf('Positive dPhase samples           = %d\n', numel(dPhase_pos));
    fprintf('Negative region samples           = %d\n', numel(env_neg));
    fprintf('Negative dEnv samples             = %d\n', numel(dEnv_neg));
    fprintf('Negative dPhase samples           = %d\n', numel(dPhase_neg));

    if ~isempty(env_pos)
        figure;
        histogram(env_pos, numBins, 'Normalization', 'pdf');
        grid on;
        xlabel('Envelope');
        ylabel('PDF');
        title(sprintf('Envelope PDF: Region 0 to +%.2f dB', win_dB));

        figure;
        histogram(phase_pos, numBins, 'Normalization', 'pdf');
        grid on;
        xlabel('Phase (rad)');
        ylabel('PDF');
        title(sprintf('Phase PDF: Region 0 to +%.2f dB', win_dB));

        figure;
        histogram(dEnv_pos, numBins, 'Normalization', 'pdf');
        grid on;
        xlabel('\Delta Envelope');
        ylabel('PDF');
        title(sprintf('Envelope Derivative PDF: Region 0 to +%.2f dB', win_dB));

        figure;
        histogram(dPhase_pos, numBins, 'Normalization', 'pdf');
        grid on;
        xlabel('\Delta Phase (rad/sample)');
        ylabel('PDF');
        title(sprintf('Phase Derivative PDF: Region 0 to +%.2f dB', win_dB));
    end

    if ~isempty(env_neg)
        figure;
        histogram(env_neg, numBins, 'Normalization', 'pdf');
        grid on;
        xlabel('Envelope');
        ylabel('PDF');
        title(sprintf('Envelope PDF: Region -%.2f dB to 0', win_dB));

        figure;
        histogram(phase_neg, numBins, 'Normalization', 'pdf');
        grid on;
        xlabel('Phase (rad)');
        ylabel('PDF');
        title(sprintf('Phase PDF: Region -%.2f dB to 0', win_dB));

        figure;
        histogram(dEnv_neg, numBins, 'Normalization', 'pdf');
        grid on;
        xlabel('\Delta Envelope');
        ylabel('PDF');
        title(sprintf('Envelope Derivative PDF: Region -%.2f dB to 0', win_dB));

        figure;
        histogram(dPhase_neg, numBins, 'Normalization', 'pdf');
        grid on;
        xlabel('\Delta Phase (rad/sample)');
        ylabel('PDF');
        title(sprintf('Phase Derivative PDF: Region -%.2f dB to 0', win_dB));
    end
end

%% ---------------- PAPR VS ROLL-OFF ----------------
figure;
plot(rolloffCandidates, paprList_dB, '-o', 'LineWidth', 1.5, 'MarkerSize', 7);
grid on;
xlabel('Roll-off Factor');
ylabel('PAPR (dB)');
title(sprintf('PAPR vs Roll-off Factor for Ideal %s', qamStr));