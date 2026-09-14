function [cfg, info] = papr_5g_config(direction, bw, scs, mcs, osf, opts)
%PAPR_5G_CONFIG Single-user, full-bandwidth 5G NR carrier for the PAPR study.
%   [CFG, INFO] = PAPR_5G_CONFIG(DIRECTION, BW, SCS, MCS, OSF) builds an
%   nrDLCarrierConfig ('dl') or nrULCarrierConfig ('ul') with one PDSCH or
%   PUSCH occupying every resource block of a BW MHz channel at SCS kHz
%   subcarrier spacing, single layer, single antenna. It is the NR
%   counterpart of PAPR_STD_CONFIG: one place fixes the choices that make
%   the downlink and uplink numbers comparable with each other and with the
%   802.11 results.
%
%   MCS is a TS 38.214 index; PAPR_5G_MCS turns it into a modulation and a
%   target code rate. OSF multiplies the nominal sample rate through the
%   carrier's SampleRate property, which is how nrWaveformGenerator
%   oversamples (it has no OversamplingFactor argument).
%
%   [...] = PAPR_5G_CONFIG(..., OPTS) takes a struct of overrides. Every
%   field is optional:
%     FrequencyRange     'FR1' or 'FR2'. Default: FR2 when SCS is 120 kHz or
%                        BW exceeds 100 MHz, FR1 otherwise. 50 and 100 MHz at
%                        60 kHz exist in both ranges, so set it when that is
%                        the combination in use.
%     MCSTable           '64QAM' (default) or '256QAM'.
%     TransformPrecoding Uplink only. true selects DFT-s-OFDM; the whole
%                        reason uplink PAPR differs from downlink. Default
%                        false (CP-OFDM).
%     Pi2BPSK            Uplink only, with TransformPrecoding. MCS 0 and 1
%                        become pi/2-BPSK (q = 1). Default false.
%     SSB                Downlink only. Include the SS burst. Default true;
%                        it is what a real gNB transmits, and it is the NR
%                        analogue of the 802.11 preamble question.
%     PDCCH              Downlink only. Include a 2-symbol CORESET/PDCCH in
%                        every slot. Default true. When set, PDSCH starts at
%                        symbol 2, so the two are never in the same symbol.
%     SlotAllocation     Slots carrying the data channel, 0-based within
%                        PERIOD. Default: every slot.
%     Period             Slot allocation period in slots. Default: one
%                        subframe. Setting both gives a TDD-style on/off
%                        pattern, which replaces the 802.11 idle gap.
%     NCellID            Physical cell identity. Default 1.
%     RNTI               Data channel RNTI. Default 1.
%     WindowingPercent   OFDM windowing. Default 0, matching the 802.11
%                        scripts' WindowTransitionTime of 0.
%
%   CFG has NumSubframes = 1; PAPR_5G_STREAM_PLAN and the generation loops
%   set the duration. INFO records what was chosen:
%     direction, frequencyRange, bw, scs, nrb, mcs, mcsTable, modulation,
%     codeRate, transformPrecoding, channel ('PDSCH'/'PUSCH'), osf,
%     fsNominal, fs, slotsPerSubframe, symbolsPerSlot, slotAllocation,
%     period.
%
%   See also PAPR_5G_MCS, PAPR_5G_META, PAPR_5G_STREAM_PLAN, PAPR_STD_CONFIG.

if nargin < 5 || isempty(osf)
    osf = 1;
end
if nargin < 6 || isempty(opts)
    opts = struct();
end
direction = lower(direction);
if ~any(strcmp(direction, {'dl', 'ul'}))
    error('papr_5g_config:BadDirection', ...
        'DIRECTION must be ''dl'' or ''ul'', got "%s".', direction);
end
validateattributes(osf, {'numeric'}, {'scalar', 'integer', 'positive'}, mfilename, 'osf');

isUL = strcmp(direction, 'ul');
fr        = getopt(opts, 'FrequencyRange', '');
mcsTable  = getopt(opts, 'MCSTable', '64QAM');
tp        = logical(getopt(opts, 'TransformPrecoding', false)) && isUL;
pi2bpsk   = logical(getopt(opts, 'Pi2BPSK', false));
withSSB   = logical(getopt(opts, 'SSB', true));
withPDCCH = logical(getopt(opts, 'PDCCH', true));
slotAlloc = getopt(opts, 'SlotAllocation', []);
period    = getopt(opts, 'Period', []);
nCellID   = getopt(opts, 'NCellID', 1);
rnti      = getopt(opts, 'RNTI', 1);
winPct    = getopt(opts, 'WindowingPercent', 0);

if isempty(fr)
    if scs >= 120 || bw > 100
        fr = 'FR2';
    else
        fr = 'FR1';
    end
end

[modulation, codeRate] = papr_5g_mcs(mcs, mcsTable, tp, pi2bpsk);

% The (FR, BW, SCS) constructor sizes the SCS carrier and bandwidth part to
% the maximum transmission bandwidth for that combination (TS 38.101 Tables
% 5.3.2-1 / 5.3.2-2), which is the full-band allocation this study wants.
if isUL
    cfg = nrULCarrierConfig(fr, bw, scs);
else
    cfg = nrDLCarrierConfig(fr, bw, scs);
end
nrb = cfg.BandwidthParts{1}.NSizeBWP;
slotsPerSubframe = scs / 15;
symbolsPerSlot = 14;

if isempty(period)
    period = slotsPerSubframe;
end
if isempty(slotAlloc)
    slotAlloc = 0:period-1;
end
validateattributes(period, {'numeric'}, {'scalar', 'integer', 'positive'}, mfilename, 'Period');
validateattributes(slotAlloc, {'numeric'}, {'vector', 'integer', 'nonnegative', '<', period}, ...
    mfilename, 'SlotAllocation');

cfg.NCellID = nCellID;
cfg.NumSubframes = 1;
cfg.InitialNSubframe = 0;
cfg.WindowingPercent = winPct;

if isUL
    ch = nrWavegenPUSCHConfig;
    ch.Enable = true;
    ch.BandwidthPartID = cfg.BandwidthParts{1}.BandwidthPartID;
    ch.Modulation = modulation;
    ch.TargetCodeRate = codeRate;
    ch.NumLayers = 1;
    ch.NumAntennaPorts = 1;
    ch.MappingType = 'A';
    ch.SymbolAllocation = [0 symbolsPerSlot];
    ch.PRBSet = 0:nrb-1;
    ch.TransformPrecoding = tp;
    ch.RNTI = rnti;
    ch.SlotAllocation = slotAlloc;
    ch.Period = period;
    cfg.PUSCH = {ch};
    % PUCCH and SRS are off in the toolbox default; state it so a toolbox
    % default change cannot quietly add signals to the burst.
    cfg.PUCCH = {nrWavegenPUCCH0Config('Enable', false)};
    cfg.SRS = {nrWavegenSRSConfig('Enable', false)};
    channel = 'PUSCH';
else
    cfg.SSBurst.Enable = withSSB;
    cfg.PDCCH{1}.Enable = withPDCCH;
    cfg.CSIRS = {nrWavegenCSIRSConfig('Enable', false)};

    ch = nrWavegenPDSCHConfig;
    ch.Enable = true;
    ch.BandwidthPartID = cfg.BandwidthParts{1}.BandwidthPartID;
    ch.Modulation = modulation;
    ch.TargetCodeRate = codeRate;
    ch.NumLayers = 1;
    ch.MappingType = 'A';
    if withPDCCH
        % CORESET occupies symbols 0-1 in every slot (the positional
        % constructor fixes its duration at 2). Keep PDSCH clear of it so the
        % data-field ranges are whole symbols with nothing but PDSCH in them.
        ch.SymbolAllocation = [2 symbolsPerSlot-2];
    else
        ch.SymbolAllocation = [0 symbolsPerSlot];
    end
    ch.PRBSet = 0:nrb-1;
    ch.RNTI = rnti;
    ch.SlotAllocation = slotAlloc;
    ch.Period = period;
    cfg.PDSCH = {ch};
    channel = 'PDSCH';
end

% Nominal rate follows the data carrier: the SSB carrier the DL constructor
% may add at a lower SCS spans only 20 RB and never sets the waveform rate.
fsNominal = nrOFDMInfo(nrCarrierConfig('SubcarrierSpacing', scs, 'NSizeGrid', nrb)).SampleRate;
fs = osf * fsNominal;
cfg.SampleRate = fs;

info = struct( ...
    'direction',          direction, ...
    'frequencyRange',     fr, ...
    'bw',                 bw, ...
    'scs',                scs, ...
    'nrb',                nrb, ...
    'mcs',                mcs, ...
    'mcsTable',           mcsTable, ...
    'modulation',         modulation, ...
    'codeRate',           codeRate, ...
    'transformPrecoding', tp, ...
    'channel',            channel, ...
    'osf',                osf, ...
    'fsNominal',          fsNominal, ...
    'fs',                 fs, ...
    'slotsPerSubframe',   slotsPerSubframe, ...
    'symbolsPerSlot',     symbolsPerSlot, ...
    'slotAllocation',     slotAlloc, ...
    'period',             period);
end

function v = getopt(opts, name, default)
if isfield(opts, name) && ~isempty(opts.(name))
    v = opts.(name);
else
    v = default;
end
end
