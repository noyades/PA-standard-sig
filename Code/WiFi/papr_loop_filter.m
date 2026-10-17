function y = papr_loop_filter(x, fs, passHz, stopHz)
%PAPR_LOOP_FILTER Band-limit a waveform that is played back as a loop.
%   Y = PAPR_LOOP_FILTER(X, FS, PASSHZ, STOPHZ) low-pass filters every
%   column of X (sampled at FS) with a raised-cosine frequency mask that is
%   flat out to PASSHZ and zero from STOPHZ on, both measured from the
%   carrier.
%
%   The OFDM generators only window the symbol edges, so their sidelobes
%   run straight into the adjacent channel: a 20 MHz VHT file measured
%   about -35 dBc ACLR before this step, which hides the PA's own
%   regrowth. Sharp spectral masks give long impulse responses, and a
%   linear-convolution filter would then leave a transient at the end of
%   the file and a step where the instrument jumps from the last sample
%   back to the first. Applying the mask in the DFT domain instead filters
%   X as one period of a periodic signal: the output is band-limited
%   across the wrap as well, so the file plays end to end without a glitch.
%   Pass the complete loop, padding included, for that to hold.
%
%   See also PAPR_WLAN_EDGE_HZ.

if stopHz <= passHz
    error('papr_loop_filter:BadEdges', ...
        'stopHz (%.0f) must be above passHz (%.0f).', stopHz, passHz);
end
if stopHz > fs/2
    error('papr_loop_filter:BadEdges', ...
        'stopHz (%.0f) is beyond Nyquist (%.0f).', stopHz, fs/2);
end

n = size(x, 1);
f = abs(((0:n-1).' - n*((0:n-1).' >= ceil(n/2))) * fs / n);   % |frequency| per DFT bin
H = zeros(n, 1);
H(f <= passHz) = 1;
band = f > passHz & f < stopHz;
H(band) = 0.5 * (1 + cos(pi * (f(band) - passHz) / (stopHz - passHz)));

y = ifft(fft(x) .* H);
end
