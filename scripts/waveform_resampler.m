clear variables;
close all;
clc;
% =====================================================================
%  Waveform Resampler
%  ---------------------------------------------------------------------
%  Takes a data-only SC waveform (.bin, no zero padding) plus its 
%  _properties.mat, and resamples it so that, when played at the 
%  instrument's fixed sample rate, it produces the desired symbol rate.
%
%  new_sps = instrument_sample_rate / desired_symbol_rate
%  resample ratio = new_sps / current_sps  (applied with resample(), a
%  proper bandlimited FIR resampler -- NOT linear interpolation)
%
%  resample() has its own filter settling transient at the edges so
%  Zero padding is added before resampling and trimmed off after,
%  using padSymbols = 4 * filtLen.
%
%  Outputs are data-only, no zero padding, normalized to [-1,1].
% =====================================================================

%%%%%%%%%%%%%%%%%%%%% User inputs %%%%%%%%%%%%%%%%%%%%%%%%%%%
waveformDir  = 'waveform_directory';
waveformName = 'waveform_name';   % base name, no extension

current_sps = 4;       % oversampling factor the source .bin was generated at
alphaRRC    = 0.15;    % RRC roll-off of the source waveform (sanity check vs properties.mat)

desired_symbol_rate    = 2e9;    % target symbol rate [Baud]
instrument_sample_rate = 64e9;   % AWG sample rate [Sa/s]

outDir = 'output_directory';
%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%

%% Load waveform
binPath = fullfile(waveformDir, [waveformName '.bin']);
fid = fopen(binPath, 'r', 'ieee-le');
if fid == -1
    error('Could not open file: %s', binPath);
end
raw = fread(fid, Inf, 'single');
fclose(fid);
reI = raw(1:2:end);
imQ = raw(2:2:end);
x   = complex(reI, imQ);

%% Load waveform properties
propPath = fullfile(waveformDir, [waveformName '_properties.mat']);
src = load(propPath);   % fields: M, rolloff, filtLen, sps, PAPR_dB, rngSeed, randBits

if abs(src.rolloff - alphaRRC) > 1e-6
    warning('alphaRRC (%.3f) does not match source properties.mat rolloff (%.3f). Using properties.mat value for metadata.', ...
        alphaRRC, src.rolloff);
end
if src.sps ~= current_sps
    warning('current_sps (%d) does not match source properties.mat sps (%d). Using current_sps as specified for resampling.', ...
        current_sps, src.sps);
end

%% Compute new SPS and resample ratio
new_sps        = instrument_sample_rate / desired_symbol_rate;
resample_ratio = new_sps / current_sps;
[p, q]         = rat(resample_ratio, 1e-6);

fprintf('Source SPS         : %d\n', current_sps);
fprintf('New SPS             : %.6f\n', new_sps);
fprintf('Resample ratio (p/q): %d/%d = %.6f\n', p, q, p/q);

%% Pad, resample, trim (avoids resample() edge transients)
% Same convention as the generation script: zeroPadSymbols = 4 * filtLen
padSymbols     = 4 * src.filtLen;
padSamplesOrig = padSymbols * current_sps;
fprintf('Edge padding        : %d symbols (4 * filtLen = 4 * %d)\n', padSymbols, src.filtLen);

xPadded = [zeros(padSamplesOrig, 1); x; zeros(padSamplesOrig, 1)];

xResampledPadded = resample(xPadded, p, q);

padSamplesNew = round(padSamplesOrig * p / q);
startIdx = padSamplesNew + 1;
stopIdx  = startIdx + round(numel(x) * p / q) - 1;
xResampled = xResampledPadded(startIdx:stopIdx);

%% Waveform length / PAPR (data only, no zero padding)
origSamples   = numel(x);
newSamples    = numel(xResampled);
origSymbols   = origSamples / current_sps;
newSymbols    = newSamples / new_sps;

PAPR_dB_orig = 10*log10(max(abs(x).^2)          / mean(abs(x).^2));
PAPR_dB_new  = 10*log10(max(abs(xResampled).^2) / mean(abs(xResampled).^2));

fprintf('Original waveform   : %d samples (%.1f symbols), PAPR = %.4f dB\n', ...
    origSamples, origSymbols, PAPR_dB_orig);
fprintf('Resampled waveform  : %d samples (%.1f symbols), PAPR = %.4f dB\n', ...
    newSamples, newSymbols, PAPR_dB_new);

%% Normalize to [-1, +1] (same convention as generation script)
reI2 = real(xResampled(:));
imQ2 = imag(xResampled(:));
normScale = max([max(abs(reI2)), max(abs(imQ2))]);
if normScale == 0
    normScale = 1;
end
reI2 = reI2 / normScale;
imQ2 = imQ2 / normScale;

%% Save outputs
if ~exist(outDir, 'dir')
    mkdir(outDir);
end
outBase = [waveformName '_resampled'];

% .bin -- interleaved [I0 Q0 I1 Q1 ...], 32-bit float, little-endian
iq = reshape([reI2, imQ2].', [], 1);
fid = fopen(fullfile(outDir, [outBase '.bin']), 'w', 'ieee-le');
fwrite(fid, iq, 'single');
fclose(fid);

% .mat -- full metadata for reproducibility
M               = src.M;
rolloff         = src.rolloff;
filtLen         = src.filtLen;
rngSeed         = src.rngSeed;
sourceFile      = fullfile(waveformDir, [waveformName '.bin']);
save(fullfile(outDir, [outBase '_properties.mat']), ...
    'sourceFile', 'M', 'rolloff', 'filtLen', 'rngSeed', ...
    'current_sps', 'new_sps', 'desired_symbol_rate', 'instrument_sample_rate', ...
    'p', 'q', 'padSymbols', 'PAPR_dB_orig', 'PAPR_dB_new');

% .csv -- human-readable
fid = fopen(fullfile(outDir, [outBase '_properties.csv']), 'w');
fprintf(fid, 'Source File,%s\n', sourceFile);
fprintf(fid, 'Modulation Order,%d\n', M);
fprintf(fid, 'RRC Roll-off Factor,%f\n', rolloff);
fprintf(fid, 'RRC Filter Length (symbols),%d\n', filtLen);
fprintf(fid, 'Original SPS,%d\n', current_sps);
fprintf(fid, 'New SPS,%.6f\n', new_sps);
fprintf(fid, 'Desired Symbol Rate (Baud),%.6g\n', desired_symbol_rate);
fprintf(fid, 'Instrument Sample Rate (Sa/s),%.6g\n', instrument_sample_rate);
fprintf(fid, 'Resample Ratio p/q,%d/%d\n', p, q);
fprintf(fid, 'Resample Edge Padding (symbols),%d\n', padSymbols);
fprintf(fid, 'Original PAPR (dB),%.4f\n', PAPR_dB_orig);
fprintf(fid, 'Resampled PAPR (dB),%.4f\n', PAPR_dB_new);
fprintf(fid, 'rngSeed (source),%d\n', rngSeed);
fclose(fid);

fprintf('\nSaved to: %s\n', outDir);
fprintf('  %s.bin\n', outBase);
fprintf('  %s_properties.mat\n', outBase);
fprintf('  %s_properties.csv\n', outBase);