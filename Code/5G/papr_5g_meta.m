function meta = papr_5g_meta(cfg, info)
%PAPR_5G_META Sample map of one repeating unit of a 5G NR burst.
%   META = PAPR_5G_META(CFG, INFO), with CFG and INFO from PAPR_5G_CONFIG,
%   describes the burst in the range form PAPR_BURST_ACCUM accepts, so NR
%   waveforms are measured by exactly the definition the 802.11 scripts use.
%
%   The "unit" is the smallest block of whole subframes over which the data
%   channel's slot pattern repeats: one subframe when every slot carries
%   data (the default), or Period / gcd(Period, slots per subframe)
%   subframes for a TDD-style pattern. A trial of N units is the NR
%   counterpart of an N-packet WLAN burst.
%
%   Data ranges are whole OFDM symbols: the symbols of the PDSCH/PUSCH
%   allocation in each scheduled slot, minus DM-RS symbols when the DM-RS
%   configuration leaves no room for data in them (NumCDMGroupsWithoutData
%   at its maximum for the DM-RS type, which is the toolbox default). Symbol
%   boundaries come from nrOFDMInfo at the waveform's sample rate; they are
%   not uniform - the first symbol of each half-subframe carries a longer
%   cyclic prefix - so the map is built symbol by symbol rather than from a
%   stride. Downlink control (CORESET) sits in symbols the data allocation
%   avoids, so the 'data' measurement mode excludes it the way it excludes
%   the 802.11 preamble. The SS burst does not: it occupies 20 RB of symbols
%   2-5 in one slot every SSB period, with PDSCH rate-matched around it, so
%   a data-mode measurement of the subframe that carries it includes those
%   SSB resource elements. That is once per 20 ms by default and is the
%   realistic gNB signal; pass SSB = false to PAPR_5G_CONFIG to remove it.
%
%   One unit is generated once, at the waveform's sample rate, to read the
%   slot-by-slot resources back from nrWaveformGenerator (DM-RS symbol set,
%   transport block sizes) and to check the analytic unit length against the
%   generator before it is trusted.
%
%   META has fields:
%     unitLen           - samples per unit at INFO.fs
%     dataRanges        - Nx2 0-based [first last] sample offsets within a
%                         unit that count as data
%     subframesPerUnit  - subframes generated per unit
%     slotsPerUnit      - slots per unit
%     dataSymbols       - cell, per slot of the unit, 0-based symbol indices
%                         that count as data (empty for an unscheduled slot)
%     symbolStarts      - 0-based sample offset of every symbol in the unit
%                         (slotsPerUnit * symbolsPerSlot entries)
%     symbolLengths     - length of every symbol in the unit
%     bitsPerUnit       - transport block bits the data channel carries per
%                         unit, for drawing an explicit payload
%     fs, osf, channel  - copied from INFO
%
%   See also PAPR_5G_CONFIG, PAPR_5G_STREAM_PLAN, PAPR_BURST_ACCUM,
%   PAPR_FIELD_META.

channel = info.channel;
ch = cfg.(channel){1};
slotsPerSubframe = info.slotsPerSubframe;
symbolsPerSlot = info.symbolsPerSlot;
fs = info.fs;

subframesPerUnit = ch.Period / gcd(ch.Period, slotsPerSubframe);
slotsPerUnit = subframesPerUnit * slotsPerSubframe;

% Symbol boundaries at the waveform rate. nrOFDMInfo returns one subframe of
% lengths; the unit is that pattern repeated.
carrier = nrCarrierConfig('SubcarrierSpacing', info.scs, 'NSizeGrid', info.nrb);
ofdm = nrOFDMInfo(carrier, 'SampleRate', fs);
if ofdm.SampleRate ~= fs || sum(ofdm.SymbolLengths) ~= fs * 1e-3
    error('papr_5g_meta:SampleRate', ...
        ['nrOFDMInfo at %.6g Hz gives %d samples per subframe, not %d. The ' ...
         'sample rate must be an integer multiple of the nominal IFFT rate.'], ...
        fs, sum(ofdm.SymbolLengths), fs * 1e-3);
end
samplesPerSubframe = sum(ofdm.SymbolLengths);
symbolLengths = repmat(double(ofdm.SymbolLengths(:).'), 1, subframesPerUnit);
symbolStarts = [0 cumsum(symbolLengths(1:end-1))];
unitLen = subframesPerUnit * samplesPerSubframe;

% Probe one unit to read the per-slot resources the generator actually
% scheduled. This is the only place the map depends on the generator, and
% it is also the check that the arithmetic above matches its output.
probe = cfg;
probe.NumSubframes = subframesPerUnit;
probe.InitialNSubframe = 0;
[wave, genInfo] = nrWaveformGenerator(probe);
if size(wave, 1) ~= unitLen
    error('papr_5g_meta:UnitLength', ...
        'Generator produced %d samples for %d subframes; expected %d.', ...
        size(wave, 1), subframesPerUnit, unitLen);
end
clear wave
res = genInfo.WaveformResources.(channel)(1).Resources;

% DM-RS symbols carry data only when a CDM group is left free for it.
dmrs = ch.DMRS;
if dmrs.DMRSConfigurationType == 1
    maxGroups = 2;
else
    maxGroups = 3;
end
dmrsSymbolsAreDataFree = dmrs.NumCDMGroupsWithoutData >= maxGroups;

allocSymbols = ch.SymbolAllocation(1) : ch.SymbolAllocation(1) + ch.SymbolAllocation(2) - 1;
dataSymbols = cell(1, slotsPerUnit);
bitsPerUnit = 0;
for k = 1:numel(res)
    s = double(res(k).NSlot);          % 0-based, relative to the probe start
    if s < 0 || s >= slotsPerUnit
        continue;
    end
    syms = allocSymbols;
    if dmrsSymbolsAreDataFree
        syms = setdiff(syms, double(res(k).DMRSSymbolSet));
    end
    dataSymbols{s+1} = syms;
    bitsPerUnit = bitsPerUnit + sum(double(res(k).TransportBlockSize));
end

% Whole-symbol ranges, adjacent symbols merged, 0-based inclusive offsets.
dataRanges = zeros(0, 2);
for s = 1:slotsPerUnit
    for sym = dataSymbols{s}
        g = (s-1) * symbolsPerSlot + sym + 1;      % index into symbolStarts
        r = [symbolStarts(g), symbolStarts(g) + symbolLengths(g) - 1];
        if ~isempty(dataRanges) && dataRanges(end, 2) + 1 == r(1)
            dataRanges(end, 2) = r(2);
        else
            dataRanges(end+1, :) = r; %#ok<AGROW>
        end
    end
end
if isempty(dataRanges)
    error('papr_5g_meta:NoData', ...
        'No %s symbols were scheduled in a %d-subframe unit.', channel, subframesPerUnit);
end

meta = struct( ...
    'unitLen',          unitLen, ...
    'dataRanges',       dataRanges, ...
    'subframesPerUnit', subframesPerUnit, ...
    'slotsPerUnit',     slotsPerUnit, ...
    'dataSymbols',      {dataSymbols}, ...
    'symbolStarts',     symbolStarts, ...
    'symbolLengths',    symbolLengths, ...
    'bitsPerUnit',      bitsPerUnit, ...
    'fs',               fs, ...
    'osf',              info.osf, ...
    'channel',          channel);
end
