clear;
close all;
clc;

%% ================================================================
%  IDEAL QAM ONLY:
%  1) Generate a symbol stream that contains ALL ideal QAM symbols
%     equally often
%  2) Sweep roll-off factors and find the best one based on minimum PAPR
%  3) Compute the mean of the generated QAM waveform
%  4) Plot PDFs of:
%       - envelope
%       - phase
%       - derivative of envelope
%       - derivative of phase
%     for samples within +/-0.25 dB, +/-0.5 dB, +/-1 dB
%     around the MEAN POWER
%
%  IMPORTANT CHANGES:
%  - Phase-validity bias REMOVED:
%       No envelope thresholding for phase or phase derivative.
%       All samples are used.
%  - "All ideal QAM symbols" means:
%       every constellation point is included equally often.
%  - TRUE POWER BACK-OFF is used:
%       P_rel_dB = 10*log10( |x[n]|^2 / mean(|x[n]|^2) )
%
%  NOTES:
%  - No AWGN
%  - No probabilistic shaping
%  - No symbol-selection bias from random omission of constellation points
%  - Phase derivative is computed from unwrapped phase using all samples
%% ================================================================

%% ========================= USER SETTINGS =========================
M = 256;                        % QAM order
qamStr = sprintf('%dQAM', M);

sps = 4;                        % samples per symbol
filtLen = 12;                   % RRC span in symbols
numRepeatsPerSymbol = 2000;     % each constellation point repeated equally often
ampScale = 2;                   % amplitude scaling
numBins = 200;                  % histogram bins

% Candidate roll-off factors to test
rolloffCandidates = [0.05 0.10 0.15 0.20 0.25 0.35 0.50 0.75 1.00];

% Back-off windows around mean POWER (in dB)
backoffList_dB = [0.25 0.5 1.0];

% Shuffle symbol order after building equal-occurrence symbol stream
shuffleSymbols = true;

% Print summary
printSummary = true;

rng('default');

%% ========================= GENERATE ALL IDEAL QAM SYMBOLS =========================
% Build a stream where every ideal QAM constellation point appears equally often
allSymIdxOneSet = (0:M-1).';
symIdx = repmat(allSymIdxOneSet, numRepeatsPerSymbol, 1);

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

    % Root-raised-cosine filter
    rrcFilter = rcosdesign(rolloff, filtLen, sps);

    % Zero padding for transient settling
    zeroPad = zeros(10*filtLen,1);
    zeroPadLen = numel(zeroPad);

    % Indexing to remove filter transient
    preDelayTX = sps*(filtLen/2) + 1 + sps*zeroPadLen;

    % TX pulse shaping
    dataModPad = [zeroPad; txSym; zeroPad];
    txFiltSig  = upfirdn(dataModPad, rrcFilter, sps, 1);

    startIdx = preDelayTX;
    stopIdx  = startIdx + numel(txSym)*sps - 1;

    txSlice = txFiltSig(startIdx:stopIdx);
    txSlice = ampScale * txSlice;

    % Compute PAPR
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

% Core signal metrics
sigPower = abs(txIdeal).^2;
peakPower = max(sigPower);
meanPower = mean(sigPower);
PAPR_dB = 10*log10(peakPower / meanPower);

% Means
meanTx_complex = mean(txIdeal);
meanTx_abs = abs(meanTx_complex);
meanEnv = mean(abs(txIdeal));
meanPhase_wrapped = angle(meanTx_complex);

% Envelope / phase
env = abs(txIdeal);
phaseWrapped = angle(txIdeal);
phaseUnwrapped = unwrap(phaseWrapped);

% Derivatives using ALL samples
dEnv = diff(env);
dPhase = diff(phaseUnwrapped);

% TRUE POWER BACK-OFF
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
    fprintf('Repeats per constellation point    = %d\n', numRepeatsPerSymbol);
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

%% ========================= BACK-OFF WINDOW ANALYSIS =========================
for ii = 1:numel(backoffList_dB)
    win_dB = backoffList_dB(ii);

    % Select samples within +/- win_dB around mean POWER
    idxWin = abs(P_rel_dB) <= win_dB;

    % For phase: use all samples in the power window
    idxPhaseWin = idxWin;

    % For derivatives: both adjacent samples must be in the power window
    idxDerivWin = idxWin(1:end-1) & idxWin(2:end);

    % No phase-validity masking
    idxDPhaseWin = idxDerivWin;

    % Extract data
    env_win = env(idxWin);
    phase_win = phaseWrapped(idxPhaseWin);
    dEnv_win = dEnv(idxDerivWin);
    dPhase_win = dPhase(idxDPhaseWin);

    % Equivalent envelope limits from power window
    lowerAmp = sqrt(Pmean * 10^(-win_dB/10));
    upperAmp = sqrt(Pmean * 10^( win_dB/10));

    % Safety checks
    if isempty(env_win)
        warning('No envelope samples found for +/- %.2f dB power window.', win_dB);
        continue;
    end
    if isempty(phase_win)
        warning('No phase samples found for +/- %.2f dB power window.', win_dB);
    end
    if isempty(dEnv_win)
        warning('No envelope-derivative samples found for +/- %.2f dB power window.', win_dB);
    end
    if isempty(dPhase_win)
        warning('No phase-derivative samples found for +/- %.2f dB power window.', win_dB);
    end

    % ---------------- Envelope PDF ----------------
    figure;
    histogram(env_win, numBins, 'Normalization', 'pdf');
    grid on;
    xlabel('Envelope');
    ylabel('PDF');
    title(sprintf('Envelope PDF within \\pm%.2f dB of Mean Power - Ideal %s', win_dB, qamStr));

    % ---------------- Phase PDF ----------------
    figure;
    if ~isempty(phase_win)
        histogram(phase_win, numBins, 'Normalization', 'pdf');
    end
    grid on;
    xlabel('Phase (rad)');
    ylabel('PDF');
    title(sprintf('Phase PDF within \\pm%.2f dB of Mean Power - Ideal %s', win_dB, qamStr));

    % ---------------- Envelope Derivative PDF ----------------
    figure;
    if ~isempty(dEnv_win)
        histogram(dEnv_win, numBins, 'Normalization', 'pdf');
    end
    grid on;
    xlabel('\Delta Envelope');
    ylabel('PDF');
    title(sprintf('Envelope Derivative PDF within \\pm%.2f dB of Mean Power - Ideal %s', win_dB, qamStr));

    % ---------------- Phase Derivative PDF ----------------
    figure;
    if ~isempty(dPhase_win)
        histogram(dPhase_win, numBins, 'Normalization', 'pdf');
    end
    grid on;
    xlabel('\Delta Phase (rad/sample)');
    ylabel('PDF');
    title(sprintf('Phase Derivative PDF within \\pm%.2f dB of Mean Power - Ideal %s', win_dB, qamStr));

    % ---------------- Stats ----------------
    fprintf('\n=== WINDOW: +/- %.2f dB around mean POWER ===\n', win_dB);
    fprintf('Envelope samples selected              = %d\n', numel(env_win));
    fprintf('Phase samples selected                 = %d\n', numel(phase_win));
    fprintf('Envelope-derivative samples selected   = %d\n', numel(dEnv_win));
    fprintf('Phase-derivative samples selected      = %d\n', numel(dPhase_win));

    fprintf('Equivalent envelope range              = [%.6f, %.6f]\n', lowerAmp, upperAmp);
    fprintf('Mean envelope in window                = %.6f\n', mean(env_win));

    if ~isempty(phase_win)
        fprintf('Mean phase in window                   = %.6f rad\n', mean(phase_win));
        fprintf('Std phase in window                    = %.6f rad\n', std(phase_win));
    end
    if ~isempty(dEnv_win)
        fprintf('Mean dEnvelope in window               = %.6e\n', mean(dEnv_win));
        fprintf('Std  dEnvelope in window               = %.6e\n', std(dEnv_win));
    end
    if ~isempty(dPhase_win)
        fprintf('Mean dPhase in window                  = %.6e rad/sample\n', mean(dPhase_win));
        fprintf('Std  dPhase in window                  = %.6e rad/sample\n', std(dPhase_win));
    end
end

%% ========================= OPTIONAL TIME-DOMAIN PREVIEW =========================
Nview = min(3000, numel(txIdeal));
n = 1:Nview;

figure;
plot(n, real(txIdeal(n)), 'LineWidth', 1);
hold on;
plot(n, imag(txIdeal(n)), 'LineWidth', 1);
grid on;
xlabel('Sample Index');
ylabel('Amplitude');
title(sprintf('Ideal %s TX Waveform (Best Roll-off = %.2f)', qamStr, bestRolloff));
legend('I', 'Q');

figure;
plot(n, env(n), 'LineWidth', 1.2);
grid on;
xlabel('Sample Index');
ylabel('|x[n]|');
title(sprintf('Envelope of Ideal %s TX Waveform', qamStr));

figure;
plot(n, phaseWrapped(n), 'LineWidth', 1.2);
grid on;
xlabel('Sample Index');
ylabel('Phase (rad)');
title(sprintf('Wrapped Phase of Ideal %s TX Waveform', qamStr));