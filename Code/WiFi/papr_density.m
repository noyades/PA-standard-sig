function S = papr_density(samples, bins, kernelBw)
%PAPR_DENSITY Kernel density and CDF on a grid derived from the samples.
%   S = PAPR_DENSITY(SAMPLES, BINS, KERNELBW) where SAMPLES is a cell array
%   of sample vectors (one per plotted curve).
%
%   Hard-coding the evaluation grid, the kernel width and the axis ticks is
%   what turned narrow-but-legitimate PAPR distributions into clipped
%   vertical walls: plot_generic and plot_bar both pin the axis limits to the
%   tick vectors, so any curve taller than max(YTick) or outside the XTick
%   span is silently cut off. Deriving all three from the data avoids that
%   for every MCS/BW combination.
%
%   Pass KERNELBW empty (the default) to size the kernel by Silverman's rule,
%   so narrow distributions are not over-smoothed nor wide ones under-smoothed.
%
%   Returns a struct with fields:
%     binCenters  1 x BINS evaluation grid
%     pdf         BINS x numel(SAMPLES) probability density [1/dB]
%     cdf, ccdf   BINS x numel(SAMPLES) cumulative / complementary
%     bandwidth   kernel width actually used [dB]
%     xTick, yTickPdf, yTickCcdf   tick vectors that fully contain the curves
%
%   See also NICE_TICKS, PAPR_BURST_DB.

if nargin < 2 || isempty(bins)
    bins = 50;
end
if nargin < 3
    kernelBw = [];
end
if ~iscell(samples)
    samples = {samples};
end

samples = cellfun(@(v) v(isfinite(v(:))), samples, 'UniformOutput', false);
allPapr = vertcat(samples{:});
if isempty(allPapr)
    error('papr_density:NoSamples', 'All sample vectors were empty or non-finite.');
end

sigma = std(allPapr);
if ~isfinite(sigma) || sigma <= 0
    sigma = 0.05; % fully degenerate sample; keep the grid finite
end
if isempty(kernelBw)
    h = 1.06 * sigma * numel(allPapr)^(-1/5); % Silverman's rule
else
    h = kernelBw;
end

edges = linspace(min(allPapr) - 4*h, max(allPapr) + 4*h, bins + 1);
binCenters = edges(1:end-1) + diff(edges)/2;

n = numel(samples);
pdfVals = zeros(bins, n);
cdfVals = zeros(bins, n);
for k = 1:n
    if isempty(samples{k})
        pdfVals(:, k) = NaN;
        cdfVals(:, k) = NaN;
        continue;
    end
    f = ksdensity(samples{k}, binCenters, 'Bandwidth', h);
    F = ksdensity(samples{k}, binCenters, 'Function', 'cdf', 'Bandwidth', h);
    pdfVals(:, k) = f(:);
    cdfVals(:, k) = min(max(F(:), 0), 1);
end

% Resolve the CCDF floor from the smallest trial count: plotting decades that
% the sample size cannot support would show interpolation, not measurement.
minTrials = min(cellfun(@numel, samples(~cellfun(@isempty, samples))));
decades = max(ceil(log10(2*minTrials)), 2);

S.binCenters = binCenters;
S.pdf        = pdfVals;
S.cdf        = cdfVals;
S.ccdf       = 1 - cdfVals;
S.bandwidth  = h;
S.edges      = edges;
S.xTick      = nice_ticks(edges(1), edges(end), 8);
S.yTickPdf   = nice_ticks(0, max(pdfVals(:)), 5);
S.yTickCcdf  = logspace(-decades, 0, decades + 1);
end
