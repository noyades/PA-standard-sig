function y = papr_loop_resample(x, n)
%PAPR_LOOP_RESAMPLE Resample a band-limited loop to N samples per period.
%   Y = PAPR_LOOP_RESAMPLE(X, N) treats every column of X as one period of
%   a periodic signal and returns the same period sampled N times, by
%   keeping the DFT bins that fit the new rate. For a loop already passed
%   through PAPR_LOOP_FILTER, with its stop edge at or below the new
%   Nyquist frequency, nothing is discarded and the result is exact: no
%   filter transient and nothing new at the wrap.
%
%   See also PAPR_LOOP_FILTER, PAPR_EXPORT_RATE.

m = size(x, 1);
if n == m
    y = x;
    return;
end
k = (0:m-1).' - m * ((0:m-1).' >= ceil(m/2));    % signed bin index
keep = abs(k) < min(m, n) / 2;
X = fft(x);
Y = zeros(n, size(x, 2), 'like', X);
Y(mod(k(keep), n) + 1, :) = X(keep, :);
y = ifft(Y) * (n / m);
end
