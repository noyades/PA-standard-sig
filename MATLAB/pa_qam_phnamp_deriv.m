clear variables;
close all;
clc;

%% ========================= USER SETTINGS =========================
M = 64;
sps = 4;
filtLen = 12;
rolloff = 0.25;

alpha = 3;              % shaping strength (>0 favors outer constellation points)
Nsym  = 1e7;            % number of QAM symbols
SNRdB = 50;             % AWGN SNR in dB
ampScale = 2;           % output amplitude scaling

showRxPlots = true;     % set false if RX plots are not needed
numScatterPlot = 1e5;   % number of points to show in scatter plot to avoid heavy plotting

%% ========================= FILTER SETUP =========================
rrcFilter = rcosdesign(rolloff, filtLen, sps);
zeroPad   = zeros(10*filtLen, 1);   % allow transients to settle

zeroPadLen = numel(zeroPad);
preDelayTX = sps*(filtLen/2) + 1 + sps*zeroPadLen;

%% ========================= CONSTELLATION / PMF =========================
% Default QAM constellation points in integer order 0...M-1
const = qammod(0:M-1, M, 'UnitAveragePower', true);

% Magnitude-based probabilistic shaping
mag = abs(const);
pmf = mag.^alpha;
pmf = pmf / sum(pmf);

% Debug: show transmit probability over constellation
figure;
scatter(real(const), imag(const), 100, pmf, 'filled');
colorbar;
grid on;
axis equal;
title('Constellation Colored by Transmit Probability');
xlabel('In-Phase');
ylabel('Quadrature');

%% ========================= SYMBOL GENERATION =========================
% Generate shaped symbol indices using inverse-CDF sampling
cdf = cumsum(pmf);
u = rand(Nsym, 1);

% Faster than arrayfun for very large Nsym
symIdx = zeros(Nsym,1,'uint16');
for n = 1:Nsym
    symIdx(n) = find(cdf >= u(n), 1) - 1;
end

% QAM modulation
tx = qammod(double(symIdx), M, 'UnitAveragePower', true);

%% ========================= TX FILTERING =========================
dataModPad = [zeroPad; tx; zeroPad];
txFiltSig  = upfirdn(dataModPad, rrcFilter, sps, 1);

% Extract symbol-aligned useful oversampled section
startIdx = preDelayTX;
stopIdx  = startIdx + numel(tx)*sps - 1;
txSlice  = txFiltSig(startIdx:stopIdx);

% Optional output scaling
txSlice = ampScale * txSlice;

%% ========================= BASIC POWER / PAPR =========================
sigPower  = abs(txSlice).^2;
peakPower = max(sigPower);
meanPower = mean(sigPower);
PAPR_long = 10*log10(peakPower / meanPower);

fprintf('Mean power  = %.6f\n', meanPower);
fprintf('Peak power  = %.6f\n', peakPower);
fprintf('PAPR        = %.4f dB\n', PAPR_long);

%% ========================= RX PATH =========================
if showRxPlots
    % Add AWGN to full oversampled waveform
    rxFiltSig = awgn(txFiltSig, SNRdB, 'measured');

    % Matched filter + downsample
    rxMF = upfirdn(rxFiltSig, rrcFilter, 1, sps);

    % Total TX+RX RRC delay in symbol-rate samples:
    % each RRC contributes filtLen/2 symbols
    % plus zeroPad on both sides already accounted by the indexing below
    preDelayRX = filtLen + 1 + zeroPadLen;

    rxStart = preDelayRX;
    rxStop  = rxStart + numel(tx) - 1;

    if rxStop <= numel(rxMF)
        rx = rxMF(rxStart:rxStop);
    else
        warning('RX slice length exceeded available samples. Truncating.');
        rx = rxMF(rxStart:end);
    end

    % Hard decision demod
    rxIdx_hard = qamdemod(rx, M, 'UnitAveragePower', true);
else
    rx = [];
    rxIdx_hard = [];
end

%% ========================= EMPIRICAL PMF =========================
empPmf = histcounts(double(symIdx), -0.5:(M-0.5)) / Nsym;

%% ========================= SCATTER PLOTS =========================
NplotTX = min(numScatterPlot, numel(tx));
idxTX   = randperm(numel(tx), NplotTX);

figure;
scatter(real(tx(idxTX)), imag(tx(idxTX)), 8, '.');
grid on;
axis equal;
title('Transmitted Symbol Scatter (Shaped)');
xlabel('In-Phase');
ylabel('Quadrature');

if showRxPlots && ~isempty(rx)
    NplotRX = min(numScatterPlot, numel(rx));
    idxRX   = randperm(numel(rx), NplotRX);

    figure;
    scatter(real(rx(idxRX)), imag(rx(idxRX)), 8, '.');
    grid on;
    axis equal;
    title(sprintf('Received Symbol Scatter (Shaped), SNR = %.1f dB', SNRdB));
    xlabel('In-Phase');
    ylabel('Quadrature');
end

%% ========================= TOP PROBABILITIES =========================
[~, order] = sort(pmf, 'descend');
disp('Top 5 symbols by transmit probability (index, prob, point):');
for ii = 1:5
    i = order(ii) - 1; % symbol index
    fprintf('%2d  %8.4f   (%6.3f, %6.3f)\n', ...
        i, pmf(i+1), real(const(i+1)), imag(const(i+1)));
end

%% ========================= ENVELOPE / PHASE ANALYSIS =========================
% These are computed on the oversampled transmit waveform txSlice
% because that is the continuous-time-like shaped signal after pulse shaping.

% Envelope
env = abs(txSlice);

% Derivative of envelope (discrete-time first difference)
dEnv = diff(env);

% Wrapped phase in [-pi, pi]
phWrapped = angle(txSlice);

% Unwrapped phase for derivative computation
phUnwrapped = unwrap(phWrapped);

% Derivative of phase
dPh = diff(phUnwrapped);

% Optional: remove extremely low-envelope samples before phase analysis
% to avoid unstable phase around near-zero crossings
envThresh = 0.02 * max(env);   % threshold as 2% of max envelope
validPhase = env > envThresh;

phWrapped_valid = phWrapped(validPhase);

% For derivative of phase, both adjacent points should be valid
validDPhase = validPhase(1:end-1) & validPhase(2:end);
dPh_valid   = dPh(validDPhase);

%% ========================= HISTOGRAMS =========================
% 1) Envelope histogram
figure;
histogram(env, 200, 'Normalization', 'pdf');
grid on;
title('Histogram of Envelope |x(t)|');
xlabel('Envelope');
ylabel('PDF');

% 2) Derivative of envelope histogram
figure;
histogram(dEnv, 200, 'Normalization', 'pdf');
grid on;
title('Histogram of Envelope Derivative \Delta|x(t)|');
xlabel('\Delta Envelope');
ylabel('PDF');

% 3) Phase histogram
figure;
histogram(phWrapped_valid, 200, 'Normalization', 'pdf');
grid on;
title('Histogram of Phase \angle x(t)');
xlabel('Phase (rad)');
ylabel('PDF');

% 4) Derivative of phase histogram
figure;
histogram(dPh_valid, 200, 'Normalization', 'pdf');
grid on;
title('Histogram of Phase Derivative \Delta\phi(t)');
xlabel('\Delta Phase (rad/sample)');
ylabel('PDF');

%% ========================= OPTIONAL GAUSSIAN CHECKS =========================
% These are useful if you want to visually compare with a Gaussian fit.
figure;
histfit(dEnv, 200, 'normal');
grid on;
title('Envelope Derivative with Gaussian Fit');
xlabel('\Delta Envelope');
ylabel('Count');

figure;
histfit(dPh_valid, 200);
grid on;
title('Phase Derivative with Fitted Distribution');
xlabel('\Delta Phase (rad/sample)');
ylabel('Count');

%% ========================= OPTIONAL TIME-DOMAIN PREVIEW =========================
Nview = min(3000, numel(txSlice));
n = 1:Nview;

figure;
plot(n, real(txSlice(n)), 'LineWidth', 1); hold on;
plot(n, imag(txSlice(n)), 'LineWidth', 1);
grid on;
title('Real and Imaginary Parts of Shaped TX Waveform');
xlabel('Sample Index');
ylabel('Amplitude');
legend('I', 'Q');

figure;
plot(n, env(n), 'LineWidth', 1);
grid on;
title('Envelope of Shaped TX Waveform');
xlabel('Sample Index');
ylabel('|x(t)|');

figure;
plot(n, phWrapped(n), 'LineWidth', 1);
grid on;
title('Wrapped Phase of Shaped TX Waveform');
xlabel('Sample Index');
ylabel('Phase (rad)');

%% ========================= OPTIONAL SUMMARY =========================
fprintf('\n=== Distribution Summary ===\n');
fprintf('Envelope mean                = %.6f\n', mean(env));
fprintf('Envelope std                 = %.6f\n', std(env));
fprintf('Envelope derivative mean     = %.6e\n', mean(dEnv));
fprintf('Envelope derivative std      = %.6e\n', std(dEnv));
fprintf('Phase mean (wrapped, valid)  = %.6f rad\n', mean(phWrapped_valid));
fprintf('Phase std  (wrapped, valid)  = %.6f rad\n', std(phWrapped_valid));
fprintf('Phase derivative mean        = %.6e rad/sample\n', mean(dPh_valid));
fprintf('Phase derivative std         = %.6e rad/sample\n', std(dPh_valid));