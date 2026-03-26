clear variables;
close all;
clc;

%% ========================= USER SETTINGS =========================
M = 256;
qamStr = sprintf('QAM%d', M);
sps = 4;
filtLen = 12;
rolloff = 0.25;

alpha = 3;              % shaping strength (>0 favors outer constellation points)
Nsym  = 5e5;            % number of QAM symbols
SNRdB = 50;             % AWGN SNR in dB
ampScale = 2;           % output amplitude scaling

showRxPlots = true;     % set false if RX plots are not needed
numScatterPlot = 1e3;   % number of points to show in scatter plot to avoid heavy plotting

%% ========================= FILTER SETUP =========================
rrcFilter = rcosdesign(rolloff, filtLen, sps);
zeroPad   = zeros(10*filtLen, 1);   % allow transients to settle

zeroPadLen = numel(zeroPad);
preDelayTX = sps*(filtLen/2) + 1 + sps*zeroPadLen;

%% ========================= CONSTELLATION / PMF =========================
const = qammod(0:M-1, M, 'UnitAveragePower', true);

% -------- Shaped PMF --------
mag = abs(const);
pmf_shaped = mag.^alpha;
pmf_shaped = pmf_shaped / sum(pmf_shaped);

% -------- Uniform PMF --------
pmf_uniform = ones(size(const)) / M;

% Debug: show transmit probability over constellation
figure;
scatter(real(const), imag(const), 100, pmf_shaped, 'filled');
colorbar;
grid on;
axis equal;
title('Constellation Colored by Transmit Probability');
xlabel('In-Phase');
ylabel('Quadrature');
saveas(gcf,sprintf('%s_QAM_constellation_heatmap.svg',qamStr));
saveas(gcf,sprintf('%s_QAM_constellation_heatmap.png',qamStr));

%% ========================= SYMBOL GENERATION =========================
cdf_shaped  = cumsum(pmf_shaped);
cdf_uniform = cumsum(pmf_uniform);

u1 = rand(Nsym, 1);
u2 = rand(Nsym, 1);

symIdx_shaped  = zeros(Nsym,1,'uint16');
symIdx_uniform = zeros(Nsym,1,'uint16');

for n = 1:Nsym
    symIdx_shaped(n)  = find(cdf_shaped  >= u1(n), 1) - 1;
    symIdx_uniform(n) = find(cdf_uniform >= u2(n), 1) - 1;
end

tx_shaped  = qammod(double(symIdx_shaped),  M, 'UnitAveragePower', true);
tx_uniform = qammod(double(symIdx_uniform), M, 'UnitAveragePower', true);

%% ========================= TX FILTERING =========================
% -------- shaped --------
dataModPad_shaped = [zeroPad; tx_shaped; zeroPad];
txFiltSig_shaped  = upfirdn(dataModPad_shaped, rrcFilter, sps, 1);

startIdx = preDelayTX;
stopIdx1 = startIdx + numel(tx_shaped)*sps - 1;
txSlice_shaped = txFiltSig_shaped(startIdx:stopIdx1);
txSlice_shaped = ampScale * txSlice_shaped;

% -------- uniform --------
dataModPad_uniform = [zeroPad; tx_uniform; zeroPad];
txFiltSig_uniform  = upfirdn(dataModPad_uniform, rrcFilter, sps, 1);

stopIdx2 = startIdx + numel(tx_uniform)*sps - 1;
txSlice_uniform = txFiltSig_uniform(startIdx:stopIdx2);
txSlice_uniform = ampScale * txSlice_uniform;

%% ========================= BASIC POWER / PAPR =========================
sigPower_shaped  = abs(txSlice_shaped).^2;
peakPower_shaped = max(sigPower_shaped);
meanPower_shaped = mean(sigPower_shaped);
PAPR_shaped      = 10*log10(peakPower_shaped / meanPower_shaped);

sigPower_uniform  = abs(txSlice_uniform).^2;
peakPower_uniform = max(sigPower_uniform);
meanPower_uniform = mean(sigPower_uniform);
PAPR_uniform      = 10*log10(peakPower_uniform / meanPower_uniform);

fprintf('=== SHAPED SIGNAL ===\n');
fprintf('Mean power  = %.6f\n', meanPower_shaped);
fprintf('Peak power  = %.6f\n', peakPower_shaped);
fprintf('PAPR        = %.4f dB\n', PAPR_shaped);

fprintf('\n=== UNIFORM SIGNAL ===\n');
fprintf('Mean power  = %.6f\n', meanPower_uniform);
fprintf('Peak power  = %.6f\n', peakPower_uniform);
fprintf('PAPR        = %.4f dB\n', PAPR_uniform);

%% ========================= ENVELOPE / PHASE ANALYSIS =========================
% -------- shaped --------
env_shaped = abs(txSlice_shaped);
dEnv_shaped = diff(env_shaped);

phWrapped_shaped = angle(txSlice_shaped);
phUnwrapped_shaped = unwrap(phWrapped_shaped);
dPh_shaped = diff(phUnwrapped_shaped);

envThresh_shaped = 0.02 * max(env_shaped);
validPhase_shaped = env_shaped > envThresh_shaped;
phWrapped_valid_shaped = phWrapped_shaped(validPhase_shaped);

validDPhase_shaped = validPhase_shaped(1:end-1) & validPhase_shaped(2:end);
dPh_valid_shaped   = dPh_shaped(validDPhase_shaped);

% -------- uniform --------
env_uniform = abs(txSlice_uniform);
dEnv_uniform = diff(env_uniform);

phWrapped_uniform = angle(txSlice_uniform);
phUnwrapped_uniform = unwrap(phWrapped_uniform);
dPh_uniform = diff(phUnwrapped_uniform);

envThresh_uniform = 0.02 * max(env_uniform);
validPhase_uniform = env_uniform > envThresh_uniform;
phWrapped_valid_uniform = phWrapped_uniform(validPhase_uniform);

validDPhase_uniform = validPhase_uniform(1:end-1) & validPhase_uniform(2:end);
dPh_valid_uniform   = dPh_uniform(validDPhase_uniform);

%% ========================= HISTOGRAMS =========================
% 1) Envelope histogram
figure;
histogram(env_shaped, 200, 'Normalization', 'pdf');
hold on;
histogram(env_uniform, 200, 'Normalization', 'pdf');
grid on;
title('Histogram of Envelope |x(t)|');
xlabel('Envelope');
ylabel('PDF');
legend('Shaped', 'Uniform');
saveas(gcf,sprintf('%s_QAM_envelop_histogram_overlay.svg',qamStr))
saveas(gcf,sprintf('%s_QAM_envelop_histogram_overlay.png',qamStr))

% 2) Derivative of envelope histogram
figure;
histogram(dEnv_shaped, 200, 'Normalization', 'pdf');
hold on;
histogram(dEnv_uniform, 200, 'Normalization', 'pdf');
grid on;
title('Histogram of Envelope Derivative \Delta|x(t)|');
xlabel('\Delta Envelope');
ylabel('PDF');
legend('Shaped', 'Uniform');
saveas(gcf,sprintf('%s_QAM_Derivative_envelop_histogram_overlay.svg',qamStr))
saveas(gcf,sprintf('%s_QAM_Derivative_envelop_histogram_overlay.png',qamStr))

% 3) Phase histogram
figure;
histogram(phWrapped_valid_shaped, 200, 'Normalization', 'pdf');
hold on;
histogram(phWrapped_valid_uniform, 200, 'Normalization', 'pdf');
grid on;
title('Histogram of Phase \angle x(t)');
xlabel('Phase (rad)');
ylabel('PDF');
legend('Shaped', 'Uniform');
saveas(gcf,sprintf('%s_QAM_phase_histogram_overlay.svg',qamStr))
saveas(gcf,sprintf('%s_QAM_phase_histogram_overlay.png',qamStr))

% 4) Derivative of phase histogram
figure;
histogram(dPh_valid_shaped, 200, 'Normalization', 'pdf');
hold on;
histogram(dPh_valid_uniform, 200, 'Normalization', 'pdf');
grid on;
title('Histogram of Phase Derivative \Delta\phi(t)');
xlabel('\Delta Phase (rad/sample)');
ylabel('PDF');
legend('Shaped', 'Uniform');
saveas(gcf,sprintf('%s_QAM_Derivative_phase_histogram_overlay.svg',qamStr))
saveas(gcf,sprintf('%s_QAM_Derivative_phase_histogram_overlay.png',qamStr))

%% ========================= OPTIONAL GAUSSIAN CHECKS =========================
figure;
histfit(dEnv_shaped, 200, 'normal');
hold on;
histogram(dEnv_uniform, 200, 'Normalization', 'pdf');
grid on;
title('Envelope Derivative with Gaussian Fit');
xlabel('\Delta Envelope');
ylabel('Count');
legend('Shaped fit', 'Shaped hist', 'Uniform hist')

figure;
histfit(dPh_valid_shaped, 200);
hold on;
histogram(dPh_valid_uniform, 200, 'Normalization', 'pdf');
grid on;
title('Phase Derivative with Fitted Distribution');
xlabel('\Delta Phase (rad/sample)');
ylabel('Count');
legend('Shaped fit', 'Shaped hist', 'Uniform hist')

%% ========================= OPTIONAL TIME-DOMAIN PREVIEW =========================
Nview = min([3000, numel(txSlice_shaped), numel(txSlice_uniform)]);
n = 1:Nview;

figure;
plot(n, real(txSlice_shaped(n)), 'LineWidth', 1); 
hold on;
plot(n, imag(txSlice_shaped(n)), 'LineWidth', 1);
grid on;
title('Real and Imaginary Parts of Shaped TX Waveform');
xlabel('Sample Index');
ylabel('Amplitude');
legend('I', 'Q');

figure;
plot(n, env_shaped(n), 'LineWidth', 1); 
hold on;
plot(n, env_uniform(n), 'LineWidth', 1);
grid on;
title('Envelope of TX Waveform');
xlabel('Sample Index');
ylabel('|x(t)|');
legend('Shaped', 'Uniform');

figure;
plot(n, phWrapped_shaped(n), 'LineWidth', 1); 
hold on;
plot(n, phWrapped_uniform(n), 'LineWidth', 1);
grid on;
title('Wrapped Phase of TX Waveform');
xlabel('Sample Index');
ylabel('Phase (rad)');
legend('Shaped', 'Uniform');

figure;
plot(1:min(3000,numel(dEnv_shaped)), dEnv_shaped(1:min(3000,numel(dEnv_shaped))), 'LineWidth', 1); 
hold on;
plot(1:min(3000,numel(dEnv_uniform)), dEnv_uniform(1:min(3000,numel(dEnv_uniform))), 'LineWidth', 1);
grid on;
title('Envelope Derivative of TX Waveform');
xlabel('Sample Index');
ylabel('\Delta|x(t)|');
legend('Shaped', 'Uniform');

figure;
plot(1:min(3000,numel(dPh_shaped)), dPh_shaped(1:min(3000,numel(dPh_shaped))), 'LineWidth', 1); 
hold on;
plot(1:min(3000,numel(dPh_uniform)), dPh_uniform(1:min(3000,numel(dPh_uniform))), 'LineWidth', 1);
grid on;
title('Phase Derivative of TX Waveform');
xlabel('Sample Index');
ylabel('\Delta\phi(t)');
legend('Shaped', 'Uniform');

%% ========================= OPTIONAL SUMMARY =========================
fprintf('\n=== SHAPED SUMMARY ===\n');
fprintf('Envelope mean                = %.6f\n', mean(env_shaped));
fprintf('Envelope std                 = %.6f\n', std(env_shaped));
fprintf('Envelope derivative mean     = %.6e\n', mean(dEnv_shaped));
fprintf('Envelope derivative std      = %.6e\n', std(dEnv_shaped));
fprintf('Phase mean (wrapped, valid)  = %.6f rad\n', mean(phWrapped_valid_shaped));
fprintf('Phase std  (wrapped, valid)  = %.6f rad\n', std(phWrapped_valid_shaped));
fprintf('Phase derivative mean        = %.6e rad/sample\n', mean(dPh_valid_shaped));
fprintf('Phase derivative std         = %.6e rad/sample\n', std(dPh_valid_shaped));

fprintf('\n=== UNIFORM SUMMARY ===\n');
fprintf('Envelope mean                = %.6f\n', mean(env_uniform));
fprintf('Envelope std                 = %.6f\n', std(env_uniform));
fprintf('Envelope derivative mean     = %.6e\n', mean(dEnv_uniform));
fprintf('Envelope derivative std      = %.6e\n', std(dEnv_uniform));
fprintf('Phase mean (wrapped, valid)  = %.6f rad\n', mean(phWrapped_valid_uniform));
fprintf('Phase std  (wrapped, valid)  = %.6f rad\n', std(phWrapped_valid_uniform));
fprintf('Phase derivative mean        = %.6e rad/sample\n', mean(dPh_valid_uniform));
fprintf('Phase derivative std         = %.6e rad/sample\n', std(dPh_valid_uniform));