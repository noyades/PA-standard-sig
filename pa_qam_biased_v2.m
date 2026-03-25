% Not the most robust code ever, you have to tweak a bit 
% the distortion coefficents to get something meaningful, but with the 
% current setting it should give an idea of the BER/EVM versus
% constellation PDF.


% Comments by AI :)

% =========================================================================
%  64-QAM Probabilistic Shaping + PA Nonlinearity BER Simulation
%
%  Description:
%    Simulates a 64-QAM link where the symbol probability mass function
%    (PMF) is shaped via a shaping coefficient (alpha). For each
%    alpha, the script:
%      1. Generates shaped symbols and pulse-shapes them with an RRC filter
%      2. Applies a simplified distortion (AM/AM + AM/PM)
%      3. Passes both the clean and distorted signals through noisy a channel
%      4. Matches-filters and down-samples at the receiver
%      5. Demodulates and computes BER and EVM
%
%  Key parameters to tune:
%    SNR        - Channel signal-to-noise ratio [dB]
%    s          - Rapp model smoothness factor (higher = sharper clipping)
%    OSat       - Saturation power level [same units as signal power]
%    phaseCoeff - Maximum AM/PM phase shift at saturation [degrees]
%    pmf_sweep  - Range of shaping exponents alpha to evaluate
% =========================================================================

clear variables;
close all;
clc;

% =========================================================================
%  System Parameters
% =========================================================================
M        = 64;                              % QAM order
k        = log2(M);                         % Bits per symbol
sps      = 4;                               % Samples per symbol
filtLen  = 12;                              % RRC filter length (in symbols)
rolloff  = 0.35;                            % RRC roll-off factor
Nsym     = 1e5;                             % Number of transmitted symbols
SNR      = 25;                              % Channel SNR [dB]

% Maximum output power reference used to normalize the TX waveform [mW]
refMaxPower = 3;

% =========================================================================
%  Filter definition and zero padding
% =========================================================================
rrcFilter  = rcosdesign(rolloff, filtLen, sps);   % Root-raised cosine filter
zeroPad    = zeros(10 * filtLen, 1);
% Timing offsets to align TX and RX after filtering and up/downsampling
zeroPadLen  = numel(zeroPad);
preDelay    = sps * (filtLen / 2) + 1 + sps * zeroPadLen;   % TX-side offset
preDelayRX  = filtLen + 1 + zeroPadLen;                      % RX-side offset after MF

% =========================================================================
%  Distortion coefficients
% =========================================================================
s          = 1;     % Smoothness factor (higher s = sharper saturation knee)
OSat       = 3;     % Saturation power level [same units as signal power]
phaseCoeff = -20;   % Max phase shift [deg] reached at full compression

% =========================================================================
%  Reference Constellation and Random Symbol Sequence
% =========================================================================
const = qammod(0:M-1, M, 'UnitAveragePower', true);   % All M constellation points
u = rand(Nsym, 1);   % Uniform random draws for inverse-CDF symbol generation

pmf_sweep = [-3 : 1 : 3];
BER_array = zeros(length(pmf_sweep), 2);   % Columns: [BER_linear, BER_distorted]
EVM_array = zeros(1, length(pmf_sweep));

for a = 1 : length(pmf_sweep)

    alpha = pmf_sweep(a);

    % ---------------------------------------------------------------------
    %  1. Probabilistic Shaping: compute PMF and draw shaped symbols
    % ---------------------------------------------------------------------
    pow = (abs(const)).^2;     % Per-symbol power
    pmf = pow .^ alpha;        % Power-law shaping
    pmf = pmf / sum(pmf);      % Normalize to a valid probability distribution

    % Visualize the constellation colour-coded by symbol probability
    figure(1);
    scatter(real(const), imag(const), 100, pmf, 'filled');
    colorbar;
    title(['Constellation PMF  (alpha = ', num2str(alpha), ')']);

    % Inverse-CDF sampling: map each uniform draw to a constellation index
    cdf    = cumsum(pmf);
    symIdx = arrayfun(@(x) find(cdf >= x, 1) - 1, u);

    % ---------------------------------------------------------------------
    %  2. Modulation and Pulse Shaping
    % ---------------------------------------------------------------------
    tx         = qammod(symIdx, M, 'UnitAveragePower', true);
    dataModPad = [zeroPad; tx; zeroPad];             % Add guard intervals
    txFiltSig  = upfirdn(dataModPad, rrcFilter, sps, 1);  % Upsample + filter

    % Normalize TX waveform so peak power equals refMaxPower
    txMaxPower      = max(abs(txFiltSig).^2);
    txScalingFactor = sqrt(refMaxPower / txMaxPower);
    txFiltSig       = txFiltSig * txScalingFactor;

    txFiltSig1 = txFiltSig;   % Copy for the distorted path

    % ---------------------------------------------------------------------
    %  3. PA Distortion (Rapp Model + AM/PM Phase Shift)
    % ---------------------------------------------------------------------
    input_power    = abs(txFiltSig1).^2;
    gain           = 1 ./ (1 + (input_power ./ OSat).^(2*s)).^(1 / (2*s));

    % AM/PM: phase shift grows as gain compresses
    phaseShiftDeg  = phaseCoeff * (1 - gain);
    phaseShiftRad  = phaseShiftDeg * (pi / 180);
    gain           = gain .* exp(1i * phaseShiftRad);   % Complex gain

    txFiltSig1 = txFiltSig1 .* gain;

    % ---------------------------------------------------------------------
    %  4. AWGN Channel
    % ---------------------------------------------------------------------
    rxFiltSig  = awgn(txFiltSig,  SNR, 'measured');   % Linear (reference) path
    rxFiltSig1 = awgn(txFiltSig1, SNR, 'measured');   % Distorted path

    % Extract the valid (non-padded) portion of the received waveform
    rxWaveform  = rxFiltSig( preDelay : preDelay + Nsym*sps - 1);
    rxWaveform1 = rxFiltSig1(preDelay : preDelay + Nsym*sps - 1);
    env  = abs(rxWaveform);
    env1 = abs(rxWaveform1);

    % ---------------------------------------------------------------------
    %  5. Matched Filter and Downsampling
    % ---------------------------------------------------------------------
    rxMF  = upfirdn(rxFiltSig,  rrcFilter, 1, sps);
    rxMF1 = upfirdn(rxFiltSig1, rrcFilter, 1, sps);

    % ---------------------------------------------------------------------
    %  6. Power and PAPR Calculations (on the received waveform)
    % ---------------------------------------------------------------------
    p_rx       = abs(rxWaveform).^2;
    avgPow_rx  = mean(p_rx);
    maxPow_rx  = max(p_rx);
    PAPR_rx    = 10*log10(maxPow_rx / avgPow_rx);

    p_rx1      = abs(rxWaveform1).^2;
    avgPow_rx1 = mean(p_rx1);
    maxPow_rx1 = max(p_rx1);
    PAPR_rx1   = 10*log10(maxPow_rx1 / avgPow_rx1);

    % ---------------------------------------------------------------------
    %  7. Symbol Slicing and BER/EVM Computation
    % ---------------------------------------------------------------------
    rxStart = preDelayRX;
    rxStop  = rxStart + Nsym - 1;

    rx  = rxMF( rxStart:rxStop);
    rx1 = rxMF1(rxStart:rxStop);

    % Undo TX scaling so demodulator sees unit-average-power constellation
    rx  = rx  / txScalingFactor;
    rx1 = rx1 / txScalingFactor;

    rxSlice  = qamdemod(rx,  M, 'UnitAveragePower', true);
    rxSlice1 = qamdemod(rx1, M, 'UnitAveragePower', true);

    % Convert symbol indices to bit streams for BER calculation
    txBits  = int2bit(symIdx,  k, true);
    rxBits  = int2bit(rxSlice, k, true);
    rxBits1 = int2bit(rxSlice1, k, true);

    [~, BER]  = biterr(txBits(:), rxBits(:));
    [~, BER1] = biterr(txBits(:), rxBits1(:));

    % EVM: error vector magnitude relative to ideal constellation RMS
    errorVector  = rx1 - tx;
    vErrorRMS    = sqrt(mean(abs(errorVector).^2));
    cRMS         = sqrt(mean(abs(tx).^2));
    EVM_RMS      = db(vErrorRMS / cRMS);
    EVM_array(a) = EVM_RMS;

    % Store BER results for final summary plot
    BER_array(a, 1) = BER;
    BER_array(a, 2) = BER1;

    fprintf('\n ====== alpha = %+d ====== \n', alpha);
    fprintf(' [Linear]    Avg: %5.2f dBm | Max: %5.2f dBm | PAPR: %4.2f dB | BER: %.2e\n', ...
            10*log10(avgPow_rx),  10*log10(maxPow_rx),  PAPR_rx,  BER);
    fprintf(' [Distorted] Avg: %5.2f dBm | Max: %5.2f dBm | PAPR: %4.2f dB | BER: %.2e | EVM_RMS: %.2f dB\n', ...
            10*log10(avgPow_rx1), 10*log10(maxPow_rx1), PAPR_rx1, BER1, EVM_RMS);

    % --- Constellation scatter: linear vs distorted ---
    figure(3);
    subplot(1, 2, 1);
    scatter(real(rx),  imag(rx),  '.'); title('RX – Linear');    axis equal; hold on; grid on;
    subplot(1, 2, 2);
    scatter(real(rx1), imag(rx1), '.'); title('RX – Distorted'); axis equal; hold on; grid on;

    % --- Time-domain waveform comparison ---
    figure(4);
    subplot(length(pmf_sweep), 1, a);
    plot(real(rxWaveform(1:1000)));  hold on;
    plot(real(rxWaveform1(1:1000)));
    title(sprintf('alpha=%+d  |  PAPRin=%.2f dB  |  PAPRout=%.2f dB  |  BER=%.2e  |  BER_dist=%.2e', ...
          alpha, PAPR_rx, PAPR_rx1, BER, BER1));

    % --- Instantaneous power PDF ---
    figure(5);
    set(gcf, 'Position', [100, 100, 600, 950]);
    subplot(length(pmf_sweep), 1, a);
    histogram(env.^2,  400, 'Normalization', 'pdf'); hold on;
    histogram(env1.^2, 400, 'Normalization', 'pdf');
    title(sprintf('Power PDF  |  alpha = %+d', alpha));
    xlim([0 refMaxPower]); ylim([0 2]);
    xlabel('Instantaneous Power |x(t)|^2 [mW]'); ylabel('PDF');
    grid on;

    % --- Instantaneous power CDF ---
    figure(6);
    set(gcf, 'Position', [800, 100, 600, 950]);
    subplot(length(pmf_sweep), 1, a);
    histogram(env.^2,  400, 'Normalization', 'cdf'); hold on;
    histogram(env1.^2, 400, 'Normalization', 'cdf');
    title(sprintf('Power CDF  |  alpha = %+d', alpha));
    xlim([0 refMaxPower]); ylim([0 1]);
    xlabel('Instantaneous Power |x(t)|^2 [mW]'); ylabel('CDF');
    grid on;

    % --- PA AM/AM and AM/PM characteristics ---
    [power_axis, sIdx] = sort(input_power);
    gain_abs = abs(gain(sIdx));
    gain_phs = angle(gain(sIdx)) * (180 / pi);

    figure(8);
    yyaxis left;
    plot(power_axis, 10*log10(gain_abs), 'LineWidth', 2); hold on;
    ylabel('Gain Magnitude [dB]');
    yyaxis right;
    plot(power_axis, gain_phs, 'LineWidth', 2); hold on;
    ylabel('Phase Shift [deg]');
    xlabel('Input Power [mW]');
    title('Compression Characteristic – AM/AM and AM/PM');
    grid on;

end

figure(7);
yyaxis left;
plot(pmf_sweep, BER_array(:, 1), 'LineWidth', 2); hold on;
plot(pmf_sweep, BER_array(:, 2), 'LineWidth', 2);
ylabel('BER');
legend('Linear', 'Distorted', 'Location', 'best');

yyaxis right;
plot(pmf_sweep, EVM_array, 'LineWidth', 2);
ylabel('EVM_{RMS} [dB]');
xlabel('Alpha');
grid on;
