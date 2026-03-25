clear;
close all;
clc;

%% ================================================================
%  IDEAL QAM ONLY
%
%  This version:
%  1) Generates a waveform containing ideal QAM constellation points
%     with user-controlled number of symbols per constellation point
%  2) Sweeps roll-off factors and selects the one with minimum PAPR
%  3) Uses TRUE POWER BACK-OFF relative to mean power:
%
%        P_rel_dB[n] = 10*log10( |x[n]|^2 / mean(|x[n]|^2) )
%
%  4) Plots PDFs of:
%        - envelope
%        - phase
%        - derivative of envelope
%        - derivative of phase
%
%     separately for:
%        +0.25 dB power back-off region
%        -0.25 dB power back-off region
%        +0.5  dB power back-off region
%        -0.5  dB power back-off region
%        +1.0  dB power back-off region
%        -1.0  dB power back-off region
%
%  IMPORTANT INTERPRETATION:
%  - "+0.5 dB power back-off" here means samples in the band:
%         0   <= P_rel_dB < +0.5
%  - "-0.5 dB power back-off" here means samples in the band:
%        -0.5 <= P_rel_dB < 0
%
%  No phase-validity masking is used.
%  All phase samples are included.
%
%  NEW FEATURE:
%  numSymbolsPerConstPoint can be:
%    1) a scalar  -> same count for all constellation points
%    2) a vector of length M -> custom count for each point
%% ================================================================

%% ========================= USER SETTINGS =========================
M = 256;                        % QAM order
qamStr = sprintf('%dQAM', M);

sps = 4;                        % samples per symbol
filtLen = 12;                   % RRC span in symbols

% -----------------------------------------------------------------
% USER CONTROL OF NUMBER OF SYMBOLS PER CONSTELLATION POINT
%
% Option 1: same number for all points
numSymbolsPerConstPoint = 1e4;
%
% Option 2: uncomment below for custom count per constellation point
% numSymbolsPerConstPoint = 2000 * ones(M,1);
% numSymbolsPerConstPoint(1:16) = 5000;   % example: first 16 points repeated more
% -----------------------------------------------------------------

ampScale = 4;                   % amplitude scaling
numBins = 200;                  % histogram bins

% Candidate roll-off factors
rolloffCandidates = [0.15 0.25 0.35 0.45];

% Back-off magnitudes to analyze
backoffList_dB = [0.25 0.5 1.0];

% Shuffle equal/custom-occurrence sequence
shuffleSymbols = true;

% Print summary
printSummary = true;

rng('default');

%% ========================= VALIDATE USER INPUT =========================
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

%% ========================= GENERATE ALL IDEAL QAM SYMBOLS =========================
% Build symbol index vector according to desired occurrence count
symIdx = [];
for kk = 0:M-1
    symIdx = [symIdx; repmat(kk, symbolsPerPointVec(kk+1), 1)]; %#ok<AGROW>
end

if shuffleSymbols
    symIdx = symIdx(randperm(numel(symIdx)));
end

Nsym = numel(symIdx);

% Ideal QAM symbols
txSym = qammod(symIdx, M, 'UnitAveragePower', true);

% Mean of raw QAM symbols
meanTxSym_complex = mean(txSym);
meanTxSym_abs = abs(meanTxSym_complex);

%% ========================= ROLL-OFF SWEEP =========================
numR = numel(rolloffCandidates);
paprList_dB = zeros(numR,1);
meanPowList = zeros(numR,1);
peakPowList = zeros(numR,1);

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
    peakPower = max(sigPower);
    meanPower = mean(sigPower);
    papr_dB = 10*log10(peakPower / meanPower);

    paprList_dB(k) = papr_dB;
    meanPowList(k) = meanPower;
    peakPowList(k) = peakPower;

    if papr_dB < bestPAPR_dB
        bestPAPR_dB = papr_dB;
        bestRolloff = rolloff;
        bestTxWave = txSlice;
    end
end

%% ========================= BEST WAVEFORM ANALYSIS =========================
txIdeal = bestTxWave;

sigPower = abs(txIdeal).^2;
peakPower = max(sigPower);
meanPower = mean(sigPower);
PAPR_dB = 10*log10(peakPower / meanPower);

meanTx_complex = mean(txIdeal);
meanTx_abs = abs(meanTx_complex);
meanEnv = mean(abs(txIdeal));
meanPhase_wrapped = angle(meanTx_complex);

env = abs(txIdeal);
phaseWrapped = angle(txIdeal);
phaseUnwrapped = unwrap(phaseWrapped);

dEnv = diff(env);
dPhase = diff(phaseUnwrapped);

P = abs(txIdeal).^2;
Pmean = mean(P);
P_rel_dB = 10*log10(P / Pmean);

%% ========================= PRINT SUMMARY =========================
if printSummary
    fprintf('========================================================\n');
    fprintf('                IDEAL QAM SUMMARY\n');
    fprintf('========================================================\n');
    fprintf('QAM order M                        = %d\n', M);
    fprintf('Constellation points used          = all %d points\n', M);

    if all(symbolsPerPointVec == symbolsPerPointVec(1))
        fprintf('Symbols per constellation point    = %d (same for all points)\n', symbolsPerPointVec(1));
    else
        fprintf('Symbols per constellation point    = custom vector\n');
        fprintf('Minimum symbols for a point        = %d\n', min(symbolsPerPointVec));
        fprintf('Maximum symbols for a point        = %d\n', max(symbolsPerPointVec));
        fprintf('Average symbols per point          = %.2f\n', mean(symbolsPerPointVec));
    end

    fprintf('Total number of symbols            = %d\n', Nsym);
    fprintf('Samples per symbol                 = %d\n', sps);
    fprintf('Filter span                        = %d symbols\n', filtLen);
    fprintf('\n');
    fprintf('Candidate roll-off factors         = ');
    fprintf('%.2f ', rolloffCandidates);
    fprintf('\n');
    fprintf('Best roll-off factor               = %.2f\n', bestRolloff);
    fprintf('Best PAPR                          = %.4f dB\n', bestPAPR_dB);
    fprintf('\n');
    fprintf('Mean power of waveform             = %.6f\n', meanPower);
    fprintf('Peak power of waveform             = %.6f\n', peakPower);
    fprintf('PAPR of waveform                   = %.4f dB\n', PAPR_dB);
    fprintf('\n');
    fprintf('Mean of raw QAM symbols            = %.6e %+.6ej\n', real(meanTxSym_complex), imag(meanTxSym_complex));
    fprintf('|Mean of raw QAM symbols|          = %.6e\n', meanTxSym_abs);
    fprintf('\n');
    fprintf('Mean of TX waveform                = %.6e %+.6ej\n', real(meanTx_complex), imag(meanTx_complex));
    fprintf('|Mean of TX waveform|              = %.6e\n', meanTx_abs);
    fprintf('Mean envelope                      = %.6f\n', meanEnv);
    fprintf('Mean wrapped phase                 = %.6f rad\n', meanPhase_wrapped);
    fprintf('========================================================\n');
end

%% ========================= PAPR VS ROLL-OFF =========================
figure;
plot(rolloffCandidates, paprList_dB, '-o', 'LineWidth', 1.5, 'MarkerSize', 7);
grid on;
xlabel('Roll-off Factor');
ylabel('PAPR (dB)');
title(sprintf('PAPR vs Roll-off Factor for Ideal %s', qamStr));

%% ========================= FULL PDFs OVER ALL DATA =========================
figure;
histogram(env, numBins, 'Normalization', 'pdf');
grid on;
xlabel('Envelope');
ylabel('PDF');
title(sprintf('Full PDF of Envelope - Ideal %s (Best Roll-off = %.2f)', qamStr, bestRolloff));

figure;
histogram(phaseWrapped, numBins, 'Normalization', 'pdf');
grid on;
xlabel('Phase (rad)');
ylabel('PDF');
title(sprintf('Full PDF of Phase - Ideal %s (All Samples)', qamStr));

figure;
histogram(dEnv, numBins, 'Normalization', 'pdf');
grid on;
xlabel('\Delta Envelope');
ylabel('PDF');
title(sprintf('Full PDF of Envelope Derivative - Ideal %s', qamStr));

figure;
histogram(dPhase, numBins, 'Normalization', 'pdf');
grid on;
xlabel('\Delta Phase (rad/sample)');
ylabel('PDF');
title(sprintf('Full PDF of Phase Derivative - Ideal %s (All Samples)', qamStr));

%% ========================= SEPARATE +BO / -BO ANALYSIS =========================
for ii = 1:numel(backoffList_dB)
    win_dB = backoffList_dB(ii);

    % ---------------- Positive side: 0 to +win_dB ----------------
    idxPos = (P_rel_dB >= 0) & (P_rel_dB < win_dB);

    % For derivatives, both adjacent samples must be in the same region
    idxPosDeriv = idxPos(1:end-1) & idxPos(2:end);

    env_pos    = env(idxPos);
    phase_pos  = phaseWrapped(idxPos);
    dEnv_pos   = dEnv(idxPosDeriv);
    dPhase_pos = dPhase(idxPosDeriv);

    % Equivalent envelope limits for positive region
    posLowerAmp = sqrt(Pmean * 10^(0/10));
    posUpperAmp = sqrt(Pmean * 10^(win_dB/10));

    if isempty(env_pos)
        warning('No samples found in +%.2f dB power region.', win_dB);
    else
        figure;
        histogram(env_pos, numBins, 'Normalization', 'pdf');
        grid on;
        xlabel('Envelope');
        ylabel('PDF');
        title(sprintf('Envelope PDF for +%.2f dB Power Region (0 to +%.2f dB) - Ideal %s', win_dB, win_dB, qamStr));

        figure;
        histogram(phase_pos, numBins, 'Normalization', 'pdf');
        grid on;
        xlabel('Phase (rad)');
        ylabel('PDF');
        title(sprintf('Phase PDF for +%.2f dB Power Region (0 to +%.2f dB) - Ideal %s', win_dB, win_dB, qamStr));

        figure;
        if ~isempty(dEnv_pos)
            histogram(dEnv_pos, numBins, 'Normalization', 'pdf');
        end
        grid on;
        xlabel('\Delta Envelope');
        ylabel('PDF');
        title(sprintf('Envelope Derivative PDF for +%.2f dB Power Region - Ideal %s', win_dB, qamStr));

        figure;
        if ~isempty(dPhase_pos)
            histogram(dPhase_pos, numBins, 'Normalization', 'pdf');
        end
        grid on;
        xlabel('\Delta Phase (rad/sample)');
        ylabel('PDF');
        title(sprintf('Phase Derivative PDF for +%.2f dB Power Region - Ideal %s', win_dB, qamStr));

        fprintf('\n=== POSITIVE REGION: 0 to +%.2f dB relative to mean power ===\n', win_dB);
        fprintf('Envelope samples selected              = %d\n', numel(env_pos));
        fprintf('Phase samples selected                 = %d\n', numel(phase_pos));
        fprintf('Envelope-derivative samples selected   = %d\n', numel(dEnv_pos));
        fprintf('Phase-derivative samples selected      = %d\n', numel(dPhase_pos));
        fprintf('Equivalent envelope range              = [%.6f, %.6f]\n', posLowerAmp, posUpperAmp);
        fprintf('Mean envelope in region                = %.6f\n', mean(env_pos));
        fprintf('Mean phase in region                   = %.6f rad\n', mean(phase_pos));
        fprintf('Std phase in region                    = %.6f rad\n', std(phase_pos));
        if ~isempty(dEnv_pos)
            fprintf('Mean dEnvelope in region               = %.6e\n', mean(dEnv_pos));
            fprintf('Std  dEnvelope in region               = %.6e\n', std(dEnv_pos));
        end
        if ~isempty(dPhase_pos)
            fprintf('Mean dPhase in region                  = %.6e rad/sample\n', mean(dPhase_pos));
            fprintf('Std  dPhase in region                  = %.6e rad/sample\n', std(dPhase_pos));
        end
    end

    % ---------------- Negative side: -win_dB to 0 ----------------
    idxNeg = (P_rel_dB >= -win_dB) & (P_rel_dB < 0);
    idxNegDeriv = idxNeg(1:end-1) & idxNeg(2:end);

    env_neg    = env(idxNeg);
    phase_neg  = phaseWrapped(idxNeg);
    dEnv_neg   = dEnv(idxNegDeriv);
    dPhase_neg = dPhase(idxNegDeriv);

    % Equivalent envelope limits for negative region
    negLowerAmp = sqrt(Pmean * 10^(-win_dB/10));
    negUpperAmp = sqrt(Pmean * 10^(0/10));

    if isempty(env_neg)
        warning('No samples found in -%.2f dB power region.', win_dB);
    else
        figure;
        histogram(env_neg, numBins, 'Normalization', 'pdf');
        grid on;
        xlabel('Envelope');
        ylabel('PDF');
        title(sprintf('Envelope PDF for -%.2f dB Power Region (-%.2f to 0 dB) - Ideal %s', win_dB, win_dB, qamStr));

        figure;
        histogram(phase_neg, numBins, 'Normalization', 'pdf');
        grid on;
        xlabel('Phase (rad)');
        ylabel('PDF');
        title(sprintf('Phase PDF for -%.2f dB Power Region (-%.2f to 0 dB) - Ideal %s', win_dB, win_dB, qamStr));

        figure;
        if ~isempty(dEnv_neg)
            histogram(dEnv_neg, numBins, 'Normalization', 'pdf');
        end
        grid on;
        xlabel('\Delta Envelope');
        ylabel('PDF');
        title(sprintf('Envelope Derivative PDF for -%.2f dB Power Region - Ideal %s', win_dB, qamStr));

        figure;
        if ~isempty(dPhase_neg)
            histogram(dPhase_neg, numBins, 'Normalization', 'pdf');
        end
        grid on;
        xlabel('\Delta Phase (rad/sample)');
        ylabel('PDF');
        title(sprintf('Phase Derivative PDF for -%.2f dB Power Region - Ideal %s', win_dB, qamStr));

        fprintf('\n=== NEGATIVE REGION: -%.2f dB to 0 relative to mean power ===\n', win_dB);
        fprintf('Envelope samples selected              = %d\n', numel(env_neg));
        fprintf('Phase samples selected                 = %d\n', numel(phase_neg));
        fprintf('Envelope-derivative samples selected   = %d\n', numel(dEnv_neg));
        fprintf('Phase-derivative samples selected      = %d\n', numel(dPhase_neg));
        fprintf('Equivalent envelope range              = [%.6f, %.6f]\n', negLowerAmp, negUpperAmp);
        fprintf('Mean envelope in region                = %.6f\n', mean(env_neg));
        fprintf('Mean phase in region                   = %.6f rad\n', mean(phase_neg));
        fprintf('Std phase in region                    = %.6f rad\n', std(phase_neg));
        if ~isempty(dEnv_neg)
            fprintf('Mean dEnvelope in region               = %.6e\n', mean(dEnv_neg));
            fprintf('Std  dEnvelope in region               = %.6e\n', std(dEnv_neg));
        end
        if ~isempty(dPhase_neg)
            fprintf('Mean dPhase in region                  = %.6e rad/sample\n', mean(dPhase_neg));
            fprintf('Std  dPhase in region                  = %.6e rad/sample\n', std(dPhase_neg));
        end
    end
end

%% ========================= OPTIONAL TIME-DOMAIN PREVIEW =========================
% Nview = min(3000, numel(txIdeal));
% n = 1:Nview;
%
% figure;
% plot(n, real(txIdeal(n)), 'LineWidth', 1);
% hold on;
% plot(n, imag(txIdeal(n)), 'LineWidth', 1);
% grid on;
% xlabel('Sample Index');
% ylabel('Amplitude');
% title(sprintf('Ideal %s TX Waveform (Best Roll-off = %.2f)', qamStr, bestRolloff));
% legend('I', 'Q');
%
% figure;
% plot(n, env(n), 'LineWidth', 1.2);
% grid on;
% xlabel('Sample Index');
% ylabel('|x[n]|');
% title(sprintf('Envelope of Ideal %s TX Waveform', qamStr));
%
% figure;
% plot(n, phaseWrapped(n), 'LineWidth', 1.2);
% grid on;
% xlabel('Sample Index');
% ylabel('Phase (rad)');
% title(sprintf('Wrapped Phase of Ideal %s TX Waveform', qamStr));