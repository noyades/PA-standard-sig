function warn_if_preamble_pinned(preamblePinned, measureDataFieldOnly)
%WARN_IF_PREAMBLE_PINNED Flag a PAPR statistic that has gone deterministic.
%   PREAMBLEPINNED is the per-group fraction of trials whose burst maximum
%   landed outside the data field. When that fraction is large the PAPR is
%   set by a fixed waveform feature rather than a random data peak, its
%   spread collapses, and the PDF renders as a single narrow spike.

if measureDataFieldOnly || ~any(preamblePinned > 0.05)
    return;
end

warning('pa_wifi:PreamblePinnedPAPR', ...
    ['The burst maximum landed in the preamble for up to %.0f%% of trials. ' ...
     'The resulting PAPR is close to deterministic, so the PDF will look ' ...
     'like a single narrow spike. Set PAPR_MEASURE_MODE=data to ' ...
     'characterise the data field instead.'], 100*max(preamblePinned));
end
