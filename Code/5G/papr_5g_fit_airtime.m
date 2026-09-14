function fit = papr_5g_fit_airtime(meta, budgetSamples, maxSubframes)
%PAPR_5G_FIT_AIRTIME Longest 5G NR burst that still fits the memory budget.
%   FIT = PAPR_5G_FIT_AIRTIME(META, BUDGETSAMPLES), with META from
%   PAPR_5G_META, decides how much NR signal goes into a BUDGETSAMPLES-sample
%   generator file. It is the NR counterpart of PAPR_FIT_AIRTIME and follows
%   the same rule: the memory budget is the hard limit and the airtime is
%   the negotiable one. A waveform the instrument cannot load is worse than
%   a shorter one, so the burst is shortened rather than the file grown, and
%   the job is never refused while at least one slot fits.
%
%   The 802.11 helper holds one packet's airtime constant and packs as many
%   packets as fit. Here the repeating unit (META.unitLen, one subframe by
%   default or one slot-pattern period) plays the packet: as many whole units
%   as fit are used and the remainder is zero padding, exactly as the WLAN
%   scripts pad after the last packet. When not even one unit fits - a 4 MB
%   file holds a quarter of a 400 MHz subframe at 4x oversampling - the unit
%   is cut at the last whole-slot boundary that fits and FIT.reduced is set,
%   so the caller reports the shorter airtime rather than publishing it
%   silently. Slots are self-contained with zero windowing, so a cut at a
%   slot boundary leaves whole OFDM symbols on both sides.
%
%   FIT = PAPR_5G_FIT_AIRTIME(..., MAXSUBFRAMES) also caps the burst at
%   MAXSUBFRAMES subframes (whole units), for a file that should hold, say,
%   one 10 ms frame and no more. Default Inf: fill the budget.
%
%   FIT has fields:
%     numUnits      - whole units in the burst (0 when reduced)
%     tailSlots     - whole slots of a cut unit that follow them (reduced only)
%     unitsToGen    - units to ask PAPR_5G_GENERATE for (max(numUnits, 1))
%     burstSamples  - samples of NR signal; truncate the generated burst here
%     padSamples    - zeros appended to reach BUDGETSAMPLES
%     subframes     - burst airtime in subframes (fractional when reduced)
%     airtimeUs     - the same in microseconds
%     requestedUs   - airtime of one unit, what the burst was cut below
%     reduced       - true when the unit did not fit and was cut at a slot
%
%   See also PAPR_5G_META, PAPR_5G_GENERATE, PAPR_FIT_AIRTIME.

if nargin < 3 || isempty(maxSubframes)
    maxSubframes = Inf;
end
validateattributes(budgetSamples, {'numeric'}, {'scalar', 'positive', 'finite'}, ...
    mfilename, 'budgetSamples');

unitLen = meta.unitLen;
symbolsPerSlot = numel(meta.symbolStarts) / meta.slotsPerUnit;
samplesPerSubframe = unitLen / meta.subframesPerUnit;
unitUs = meta.subframesPerUnit * 1000;

% End of each slot within the unit, 1-based sample count.
slotEnds = [meta.symbolStarts(symbolsPerSlot+1 : symbolsPerSlot : end), unitLen];

capUnits = floor(maxSubframes / meta.subframesPerUnit);
numUnits = min(floor(budgetSamples / unitLen), capUnits);
tailSlots = 0;
reduced = false;

if numUnits == 0
    % The budget (or the cap) is below one unit: cut at a slot boundary.
    room = min(budgetSamples, maxSubframes * samplesPerSubframe);
    tailSlots = find(slotEnds <= room, 1, 'last');
    if isempty(tailSlots)
        error('papr_5g_fit_airtime:NoRoom', ...
            ['Not even one slot (%d samples) fits the %d-sample budget. ' ...
             'Lower the oversampling factor or raise the memory size.'], ...
            slotEnds(1), budgetSamples);
    end
    reduced = budgetSamples < unitLen;     % a cap below one unit is the caller's choice
    burstSamples = slotEnds(tailSlots);
else
    burstSamples = numUnits * unitLen;
end

fit = struct( ...
    'numUnits',     numUnits, ...
    'tailSlots',    tailSlots, ...
    'unitsToGen',   max(numUnits, 1), ...
    'burstSamples', burstSamples, ...
    'padSamples',   budgetSamples - burstSamples, ...
    'subframes',    burstSamples / samplesPerSubframe, ...
    'airtimeUs',    1000 * burstSamples / samplesPerSubframe, ...
    'requestedUs',  unitUs, ...
    'reduced',      reduced);
end
