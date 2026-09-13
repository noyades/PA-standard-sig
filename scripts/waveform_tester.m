clear variables;
close all;
clc;
% =====================================================================
%  Simple Waveform Tester
%  ---------------------------------------------------------------------
%  Reads a binary waveform file (interleaved I/Q, single-precision,
%  little-endian, as saved by SCQAM_generation_v12). The saved files
%  contain ONLY the data-symbol chunk (zero padding and filter group
%  delay are already stripped out before saving), so no de-padding is
%  needed here. Reports:
%    - waveform length in symbols
%    - PAPR [dB]
%  Also plots the envelope / phase distributions.
% =====================================================================


%%%%%%%%%%%%%%%%%%%%% User inputs %%%%%%%%%%%%%%%%%%%%%%%%%%%
waveformDir  = 'waveform_directory';
waveformFile = 'waveform_name.bin';
sps = 4;   % oversampling factor used to generate this waveform
%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%

%% Load waveform
fullPath = fullfile(waveformDir, waveformFile);
fid = fopen(fullPath, 'r', 'ieee-le');
if fid == -1
    error('Could not open file: %s', fullPath);
end
raw = fread(fid, Inf, 'single');
fclose(fid);
if mod(numel(raw), 2) ~= 0
    error('File does not contain an even number of floats (I/Q pairs).');
end
reI = raw(1:2:end);
imQ = raw(2:2:end);
x   = complex(reI, imQ);

%% print waveform length and PAPR
totalSamples = numel(x);
waveformSymbols = totalSamples / sps;
sigPower = abs(x).^2;
PAPR_dB  = 10 * log10(max(sigPower) / mean(sigPower));

fprintf('File                  : %s\n', fullPath);
fprintf('Total samples in file : %d\n', totalSamples);
fprintf('Waveform length       : %g symbols\n', waveformSymbols);
fprintf('PAPR                  : %.2f dB\n', PAPR_dB);

%% derivations
env = abs(x);
dEnv = diff(env);

phWrapped   = angle(x);
phUnwrapped = unwrap(phWrapped);
dPh = diff(phUnwrapped);

envThresh  = 0.02 * max(env);
validPhase = env > envThresh;
phWrapped_valid = phWrapped(validPhase);

validDPhase = validPhase(1:end-1) & validPhase(2:end);
dPh_valid   = dPh(validDPhase);

%% plots
figure('Position',[100 100 900 650]);
subplot(2,2,1); plotHist(env,            'Envelope');
subplot(2,2,2); plotHist(dEnv,           '\Delta Envelope');
subplot(2,2,3); plotHist(phWrapped_valid,'Phase (rad)');
subplot(2,2,4); plotHist(dPh_valid,      '\Delta Phase (rad/sample)');

%% functions
function plotHist(data, xlab)
    h = histogram(data, 500, 'Normalization', 'pdf');
    h.FaceColor = [0 0.45 0.74];
    h.FaceAlpha = 1;
    h.EdgeColor = 'none';
    grid on;
    xlabel(xlab);
    ylabel('PDF');
    styleAxes(gca);
end

function styleAxes(ax)
    grid(ax, 'on');
    ax.GridLineStyle = '-';
    ax.GridColorMode = 'manual';
    ax.GridColor     = [0.85 0.85 0.85];
    ax.GridAlpha     = 1;
    ax.LineWidth     = 1.75;
    ax.FontSize      = 12;
    ax.FontName      = 'Arial';
    ax.FontWeight    = 'normal';
    ax.Box           = 'on';
    ax.XColor        = [0 0 0];
end