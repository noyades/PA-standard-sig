clear variables;
close all
clc

M = 64;
k = log2(M);
sps = 4;
filtLen = 12;
rolloff = 0.15;
rrcFilter = rcosdesign(rolloff,filtLen,sps);
zeroPad = zeros(10*filtLen,1); % Add zero padding to the signals to allow for filter transients to settle


% Precompute things that do not change
zeroPadLen = numel(zeroPad);
preDelay = sps*(filtLen/2) + 1 + sps*zeroPadLen;

% Get complex constellation in default integer order (0..M-1)
const = qammod(0:M-1, M, 'UnitAveragePower', true); % normalized constellation

% Compute magnitude of constellation points and create a pmf favoring larger magnitudes
mag = abs(const);
alpha = 3;                      % tuning parameter (>0 favors outer points more)
pmf = mag.^alpha;
pmf = pmf / sum(pmf);

% Visualize pmf for debug
figure; scatter(real(const), imag(const), 100, pmf, 'filled'); colorbar;
title('Constellation colored by transmit probability');

% Generate shaped symbol indices by sampling the pmf
Nsym = 1e7;
cdf = cumsum(pmf);
u = rand(Nsym,1);
symIdx = arrayfun(@(x) find(cdf>=x,1)-1, u); % integers 0..M-1

% Modulate using qammod (indices are integers 0..M-1)
tx = qammod(symIdx, M, 'UnitAveragePower', true);

% pad, upsample & filter
dataModPad = [zeroPad; tx; zeroPad];
txFiltSig = upfirdn(dataModPad, rrcFilter, sps, 1);

% extract the symbol-aligned portion
startIdx = preDelay;
stopIdx  = startIdx + numel(tx)*sps - 1;
txSlice = txFiltSig(startIdx:stopIdx);

% optional amplitude scaling (kept as original 2*)
txSlice = 2 * txSlice;

% compute instantaneous power and peak
sigPower = abs(txSlice).^2;
peakPower = max(sigPower);
meanPower = mean(sigPower);

% (Optional) AWGN channel and naive demod (demod ignoring priors)
rxFiltSig = awgn(txFiltSig, 50, 'measured');                % 20 dB SNR example
rx = upfirdn(rxFiltSig, rrcFilter,1,sps);
rxIdx_hard = qamdemod(rx, M, 'UnitAveragePower', true);

% Simple symbol rate comparison (empirical pmf)
empPmf = histcounts(symIdx, -0.5:(M-0.5)) / Nsym;

% Plot transmitted constellation density
figure; 
scatter(real(tx), imag(tx)); 
axis equal;
title('Transmitted symbol scatter (shaped)');


% Plot received constellation density
figure; 
scatter(real(rx), imag(rx)); 
axis equal;
title('Received symbol scatter (shaped)');

% Print top probabilities
[~, order] = sort(pmf, 'descend');
disp('Top 5 symbols by transmit probability (index, prob, point):');
for k=1:5
    i = order(k);
    fprintf('%2d  %8.4f   (%6.3f, %6.3f)\n', i, pmf(i+1), real(const(i+1)), imag(const(i+1)));
end

% compute PAPR in dB (same formula as original)
PAPR_long = 10*log10(peakPower / meanPower) + 3
