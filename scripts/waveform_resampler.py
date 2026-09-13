import numpy as np
from scipy.signal import resample_poly
from scipy.io import loadmat, savemat
from fractions import Fraction
import os

# =====================================================================
#  Waveform Resampler
#  ---------------------------------------------------------------------
#  Takes a data-only SC waveform (.bin, no zero padding) plus its
#  _properties.mat, and resamples it so that, when played at the
#  instrument's fixed sample rate, it produces the desired symbol rate.
#
#  new_sps = instrument_sample_rate / desired_symbol_rate
#  resample ratio = new_sps / current_sps  (applied with resample_poly(),
#  a proper bandlimited FIR resampler -- NOT linear interpolation)
#
#  resample_poly() has its own filter settling transient at the edges so
#  Zero padding is added before resampling and trimmed off after,
#  using padSymbols = 4 * filtLen.
#
#  Outputs are data-only, no zero padding, normalized to [-1,1].
# =====================================================================

#%%%%%%%%%%%%%%%%%%%%% User inputs %%%%%%%%%%%%%%%%%%%%%%%%%%%
waveformDir  = r'waveform_directory'
waveformName = 'waveform_name'   # base name, no extension

current_sps = 4       # oversampling factor the source .bin was generated at
alphaRRC    = 0.15    # RRC roll-off of the source waveform (sanity check vs properties.mat)

desired_symbol_rate    = 2e9   # target symbol rate [Baud]
instrument_sample_rate = 64e9   # AWG sample rate [Sa/s]

outDir = r'output_directory'
#%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%

#%% Load waveform
binPath = os.path.join(waveformDir, waveformName + '.bin')
raw = np.fromfile(binPath, dtype='<f4')
reI = raw[0::2]
imQ = raw[1::2]
x = reI + 1j * imQ

#%% Load waveform properties
propPath = os.path.join(waveformDir, waveformName + '_properties.mat')
src = loadmat(propPath, squeeze_me=True)  # fields: M, rolloff, filtLen, sps, PAPR_dB, rngSeed, randBits

if abs(float(src['rolloff']) - alphaRRC) > 1e-6:
    print(f"Warning: alphaRRC ({alphaRRC:.3f}) does not match source properties.mat rolloff "
          f"({float(src['rolloff']):.3f}). Using properties.mat value for metadata.")
if int(src['sps']) != current_sps:
    print(f"Warning: current_sps ({current_sps}) does not match source properties.mat sps "
          f"({int(src['sps'])}). Using current_sps as specified for resampling.")

#%% Compute new SPS and resample ratio
new_sps        = instrument_sample_rate / desired_symbol_rate
resample_ratio = new_sps / current_sps
frac           = Fraction(resample_ratio).limit_denominator(10**6)
p, q           = frac.numerator, frac.denominator

print(f'Source SPS         : {current_sps}')
print(f'New SPS             : {new_sps:.6f}')
print(f'Resample ratio (p/q): {p}/{q} = {p/q:.6f}')

#%% Pad, resample, trim (avoids resample_poly() edge transients)
# Same convention as the generation script: zeroPadSymbols = 4 * filtLen
filtLen        = int(src['filtLen'])
padSymbols     = 4 * filtLen
padSamplesOrig = padSymbols * current_sps
print(f'Edge padding        : {padSymbols} symbols (4 * filtLen = 4 * {filtLen})')

xPadded = np.concatenate([np.zeros(padSamplesOrig, dtype=complex), x, np.zeros(padSamplesOrig, dtype=complex)])

xResampledPadded = resample_poly(xPadded, p, q)

padSamplesNew = round(padSamplesOrig * p / q)
startIdx = padSamplesNew
stopIdx  = startIdx + round(x.size * p / q)
xResampled = xResampledPadded[startIdx:stopIdx]

#%% Waveform length / PAPR (data only, no zero padding)
origSamples = x.size
newSamples  = xResampled.size
origSymbols = origSamples / current_sps
newSymbols  = newSamples / new_sps

PAPR_dB_orig = 10 * np.log10(np.max(np.abs(x) ** 2) / np.mean(np.abs(x) ** 2))
PAPR_dB_new  = 10 * np.log10(np.max(np.abs(xResampled) ** 2) / np.mean(np.abs(xResampled) ** 2))

print(f'Original waveform   : {origSamples} samples ({origSymbols:.1f} symbols), PAPR = {PAPR_dB_orig:.4f} dB')
print(f'Resampled waveform  : {newSamples} samples ({newSymbols:.1f} symbols), PAPR = {PAPR_dB_new:.4f} dB')

#%% Normalize to [-1, +1] (same convention as generation script)
reI2 = np.real(xResampled)
imQ2 = np.imag(xResampled)
normScale = max(np.max(np.abs(reI2)), np.max(np.abs(imQ2)))
if normScale == 0:
    normScale = 1
reI2 = reI2 / normScale
imQ2 = imQ2 / normScale

#%% Save outputs
os.makedirs(outDir, exist_ok=True)
outBase = waveformName + '_resampled'

# .bin -- interleaved [I0 Q0 I1 Q1 ...], 32-bit float, little-endian
iq = np.empty(reI2.size + imQ2.size, dtype='<f4')
iq[0::2] = reI2
iq[1::2] = imQ2
iq.tofile(os.path.join(outDir, outBase + '.bin'))

# .mat -- full metadata for reproducibility
M          = int(src['M'])
rolloff    = float(src['rolloff'])
rngSeed    = int(src['rngSeed'])
sourceFile = os.path.join(waveformDir, waveformName + '.bin')
savemat(os.path.join(outDir, outBase + '_properties.mat'), {
    'sourceFile': sourceFile,
    'M': M,
    'rolloff': rolloff,
    'filtLen': filtLen,
    'rngSeed': rngSeed,
    'current_sps': current_sps,
    'new_sps': new_sps,
    'desired_symbol_rate': desired_symbol_rate,
    'instrument_sample_rate': instrument_sample_rate,
    'p': p,
    'q': q,
    'padSymbols': padSymbols,
    'PAPR_dB_orig': PAPR_dB_orig,
    'PAPR_dB_new': PAPR_dB_new,
})

# .csv -- human-readable
with open(os.path.join(outDir, outBase + '_properties.csv'), 'w') as fid:
    fid.write(f'Source File,{sourceFile}\n')
    fid.write(f'Modulation Order,{M}\n')
    fid.write(f'RRC Roll-off Factor,{rolloff:f}\n')
    fid.write(f'RRC Filter Length (symbols),{filtLen}\n')
    fid.write(f'Original SPS,{current_sps}\n')
    fid.write(f'New SPS,{new_sps:.6f}\n')
    fid.write(f'Desired Symbol Rate (Baud),{desired_symbol_rate:.6g}\n')
    fid.write(f'Instrument Sample Rate (Sa/s),{instrument_sample_rate:.6g}\n')
    fid.write(f'Resample Ratio p/q,{p}/{q}\n')
    fid.write(f'Resample Edge Padding (symbols),{padSymbols}\n')
    fid.write(f'Original PAPR (dB),{PAPR_dB_orig:.4f}\n')
    fid.write(f'Resampled PAPR (dB),{PAPR_dB_new:.4f}\n')
    fid.write(f'rngSeed (source),{rngSeed}\n')

print(f'\nSaved to: {outDir}')
print(f'  {outBase}.bin')
print(f'  {outBase}_properties.mat')
print(f'  {outBase}_properties.csv')
