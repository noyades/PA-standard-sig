import numpy as np
import matplotlib.pyplot as plt

# =====================================================================
#  Simple Waveform Tester
#  ---------------------------------------------------------------------
#  Reads a binary waveform file (interleaved I/Q, single-precision,
#  little-endian, as saved by SCQAM_generation_v12). The saved files
#  contain ONLY the data-symbol chunk (zero padding and filter group
#  delay are already stripped out before saving), so no de-padding is
#  needed here. Reports:
#    - waveform length in symbols
#    - PAPR [dB]
#  Also plots the envelope / phase distributions.
# =====================================================================

#%%%%%%%%%%%%%%%%%%%%% User inputs %%%%%%%%%%%%%%%%%%%%%%%%%%%
waveformDir  = r'waveform_directory'
waveformFile = 'waveform_name.bin'
sps = 4   # oversampling factor used to generate this waveform
#%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%

#%% Load waveform
import os
fullPath = os.path.join(waveformDir, waveformFile)
raw = np.fromfile(fullPath, dtype='<f4')  # single-precision, little-endian

if raw.size % 2 != 0:
    raise ValueError('File does not contain an even number of floats (I/Q pairs).')

reI = raw[0::2]
imQ = raw[1::2]
x = reI + 1j * imQ

#%% print waveform length and PAPR
totalSamples = x.size
waveformSymbols = totalSamples / sps
sigPower = np.abs(x) ** 2
PAPR_dB = 10 * np.log10(np.max(sigPower) / np.mean(sigPower))
print(f'File                  : {fullPath}')
print(f'Total samples in file : {totalSamples}')
print(f'Waveform length       : {waveformSymbols:g} symbols')
print(f'PAPR                  : {PAPR_dB:.2f} dB')

#%% derivations
env = np.abs(x)
dEnv = np.diff(env)

phWrapped = np.angle(x)
phUnwrapped = np.unwrap(phWrapped)
dPh = np.diff(phUnwrapped)

envThresh = 0.02 * np.max(env)
validPhase = env > envThresh
phWrapped_valid = phWrapped[validPhase]

validDPhase = validPhase[:-1] & validPhase[1:]
dPh_valid = dPh[validDPhase]

#%% plots
def style_axes(ax):
    ax.grid(True)
    ax.set_axisbelow(True)
    ax.grid(color=[0.85, 0.85, 0.85], linewidth=1)
    for spine in ax.spines.values():
        spine.set_color('k')
        spine.set_linewidth(1.75)
    ax.tick_params(colors='k', labelsize=12)

def plot_hist(ax, data, xlab):
    ax.hist(data, bins=500, density=True, color=[0, 0.45, 0.74],
            alpha=1, edgecolor='none')
    ax.set_xlabel(xlab)
    ax.set_ylabel('PDF')
    style_axes(ax)

fig, axs = plt.subplots(2, 2, figsize=(9, 6.5))
plot_hist(axs[0, 0], env,             'Envelope')
plot_hist(axs[0, 1], dEnv,            r'$\Delta$ Envelope')
plot_hist(axs[1, 0], phWrapped_valid, 'Phase (rad)')
plot_hist(axs[1, 1], dPh_valid,       r'$\Delta$ Phase (rad/sample)')

plt.tight_layout()
plt.show()
