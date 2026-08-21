function [measureDataFieldOnly, modeTag] = papr_measure_mode(defaultValue)
%PAPR_MEASURE_MODE Resolve the PAPR measurement scope.
%   Set the PAPR_MEASURE_MODE environment variable to 'data' (data field
%   only) or 'full' (whole burst) to override DEFAULTVALUE.
%
%   'data' is the right default for a PAPR-versus-symbol-count study: the
%   preamble is a fixed pedestal that swamps the statistic. Use 'full' only
%   when sizing PA backoff for the whole burst, where the preamble peak is
%   genuinely the constraint.
%
%   See also PAPR_BURST_DB.

modeValue = lower(strtrim(getenv('PAPR_MEASURE_MODE')));
if strcmp(modeValue, 'full')
    measureDataFieldOnly = false;
elseif strcmp(modeValue, 'data')
    measureDataFieldOnly = true;
else
    measureDataFieldOnly = defaultValue;
end

if measureDataFieldOnly
    modeTag = 'data';
else
    modeTag = 'full';
end
end
