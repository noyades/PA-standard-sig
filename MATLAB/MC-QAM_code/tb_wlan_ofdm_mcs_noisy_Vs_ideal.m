clc
clear all
close all

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


% out =  wlan_mcs_waveform_noisy_Vs_ideal( ...
%     20, 0.8, 'BCC', 1, '256QAM', 8, 'OFDM', 100, ...
%     'ApplyTxNoise', true, ...
%     'TxSNRdB', 25, ...
%     'ApplyRxNoise', false, ...
%     'PlotDerivativeMetrics', true, ...
%     'PrintMetrics', true);

% function out = generate_wlan_mcs_waveform2( ...
% bandwidthMHz, GI_us, coding, nSS, modulation, mcsIndex, ...
% ofdmFormat, numSymbols, varargin)

 [out,A] =  wlan_mcs_waveform_noisy_Vs_ideal( ...
    20, 0.8, 'BCC', 1, '64QAM', 7, 'OFDM', 1e8, ...
    'ApplyTxNoise', true, ...
    'TxSNRdB', 200, ...
    'ApplyRxNoise', false, ...
    'PlotDerivativeMetrics', true, ...
    'HistogramBins', 200, ...
    'PrintMetrics', true);


