function ticks = nice_ticks(lo, hi, targetCount)
%NICE_TICKS Tick vector spanning [LO, HI] with a human-readable step.
%   plot_generic and plot_bar both pin the axis limits to min/max of the tick
%   vector, so these double as the axis limits. Deriving them from the data
%   is what keeps a tall, narrow curve from being clipped at the top.

if nargin < 3 || isempty(targetCount)
    targetCount = 6;
end
if ~isfinite(lo) || ~isfinite(hi) || hi <= lo
    hi = lo + 1;
end

raw = (hi - lo) / max(targetCount, 2);
mag = 10^floor(log10(raw));
norm = raw / mag;
if norm <= 1
    step = 1.0 * mag;
elseif norm <= 2
    step = 2.0 * mag;
elseif norm <= 2.5
    step = 2.5 * mag;
elseif norm <= 5
    step = 5.0 * mag;
else
    step = 10.0 * mag;
end

ticks = (floor(lo/step)*step) : step : (ceil(hi/step)*step);
end
