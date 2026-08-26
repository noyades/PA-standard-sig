function [cfg, info] = papr_fit_airtime(cfg, osf, idleTimeUs, budgetSamples, targetSymbols)
%PAPR_FIT_AIRTIME Longest packet airtime that still fits the memory budget.
%   [CFG, INFO] = PAPR_FIT_AIRTIME(CFG, OSF, IDLETIMEUS, BUDGETSAMPLES)
%   shortens the payload of CFG until one packet plus its trailing idle gap
%   fits inside BUDGETSAMPLES samples, and returns the updated config.
%
%   [CFG, INFO] = PAPR_FIT_AIRTIME(..., TARGETSYMBOLS) asks for a specific
%   data-symbol count rather than keeping the airtime CFG already carries.
%
%   Constant airtime across MCS is what makes the PAPR figures comparable,
%   so the requested duration is tried first and is never exceeded. It is
%   reduced only when the resulting packet does not fit the memory the
%   caller asked for, because a waveform the signal generator cannot load is
%   worse than a shorter one: the budget is a hard limit, the airtime is not.
%   When that happens INFO.reduced is set so the caller can report it rather
%   than silently publishing a signal of a different duration.
%
%   The search is analytic - wlanFieldIndices already knows how long a
%   packet is - and one real packet is generated at the end to confirm the
%   arithmetic against the waveform generator before the size is trusted.
%
%   INFO has fields:
%     requestedSymbols - data symbol count asked for
%     symbols          - data symbol count actually used
%     requestedUs      - airtime asked for, in microseconds
%     airtimeUs        - airtime actually used, in microseconds
%     octets           - payload length written into CFG
%     samplesPerPacket - packet plus idle gap, at OSF
%     numPackets       - how many of those fit inside BUDGETSAMPLES
%     reduced          - true when the airtime had to be shortened
%
%   See also PAPR_OCTETS_FOR_SYMBOLS, PAPR_FIELD_META, PAPR_PAYLOAD.

if nargin < 3 || isempty(idleTimeUs)
    idleTimeUs = 0;
end
validateattributes(budgetSamples, {'numeric'}, {'scalar', 'positive', 'finite'}, ...
    mfilename, 'budgetSamples');

symUs = papr_symbol_us(cfg);
symLen = round(symUs * 1e-6 * wlanSampleRate(cfg) * osf);

keepPayload = nargin < 5 || isempty(targetSymbols);
if keepPayload
    % No explicit request: keep whatever airtime the caller already set up,
    % payload length included. Re-solving it here would silently move the
    % length the caller just chose and reported.
    meta = papr_field_meta(cfg, osf, idleTimeUs);
    targetSymbols = round(meta.dataLen / symLen);
    octets = payload_octets(cfg);
    nSym = targetSymbols;
else
    targetSymbols = max(1, floor(targetSymbols));
    [octets, nSym] = papr_octets_for_symbols(cfg, targetSymbols, osf);
    cfg = papr_payload(cfg, [], octets);
end
targetSymbols = max(1, floor(targetSymbols));

% The constant-airtime answer, before the memory budget gets a say.
samplesPerPacket = packet_samples(cfg, osf, idleTimeUs);

reduced = false;
if samplesPerPacket > budgetSamples
    [cfg, octets, nSym, samplesPerPacket] = ...
        shrink_to_fit(cfg, osf, idleTimeUs, budgetSamples, nSym);
    reduced = true;
end

% The sample count above comes from wlanFieldIndices. Generate one packet to
% confirm the waveform generator agrees before promising the caller a size;
% if it ever does not, step the airtime down against the real figure.
for guard = 1:4
    measured = probe_samples(cfg, octets, osf, idleTimeUs);
    if measured <= budgetSamples
        samplesPerPacket = measured;
        break;
    end
    if nSym <= 1
        error('papr_fit_airtime:BudgetTooSmall', ...
            ['A single %d MHz packet is %d samples even at one data symbol, ' ...
             'more than the %d sample budget. Raise the memory size or lower ' ...
             'the bandwidth.'], bandwidth_mhz(cfg), measured, budgetSamples);
    end
    [cfg, octets, nSym, samplesPerPacket] = ...
        shrink_to_fit(cfg, osf, idleTimeUs, budgetSamples, nSym - 1);
    reduced = true;
end

info = struct( ...
    'requestedSymbols', targetSymbols, ...
    'symbols',          nSym, ...
    'requestedUs',      targetSymbols * symUs, ...
    'airtimeUs',        nSym * symUs, ...
    'octets',           octets, ...
    'samplesPerPacket', samplesPerPacket, ...
    'numPackets',       floor(budgetSamples / samplesPerPacket), ...
    'reduced',          reduced);
end

function [cfg, octets, nSym, samplesPerPacket] = shrink_to_fit(cfg, osf, idleTimeUs, budgetSamples, hiSymbols)
%SHRINK_TO_FIT Largest symbol count at or below HISYMBOLS whose packet fits.
%   Packet length rises monotonically with symbol count, so a binary search
%   finds the boundary in a handful of wlanFieldIndices calls.
lo = 1;
hi = max(1, hiSymbols);
bestOctets = [];
bestSym = [];
bestSamples = [];
while lo <= hi
    mid = floor((lo + hi) / 2);
    [candOctets, candSym] = papr_octets_for_symbols(cfg, mid, osf);
    candCfg = papr_payload(cfg, [], candOctets);
    candSamples = packet_samples(candCfg, osf, idleTimeUs);
    if candSamples <= budgetSamples
        bestOctets = candOctets;
        bestSym = candSym;
        bestSamples = candSamples;
        lo = mid + 1;
    else
        hi = mid - 1;
    end
end

if isempty(bestOctets)
    shortest = packet_samples(papr_payload(cfg, [], 1), osf, idleTimeUs);
    error('papr_fit_airtime:BudgetTooSmall', ...
        ['The shortest %d MHz packet is %d samples, more than the %d sample ' ...
         'budget. The preamble alone does not fit; raise the memory size or ' ...
         'lower the bandwidth.'], bandwidth_mhz(cfg), shortest, budgetSamples);
end

cfg = papr_payload(cfg, [], bestOctets);
octets = bestOctets;
nSym = bestSym;
samplesPerPacket = bestSamples;
end

function n = packet_samples(cfg, osf, idleTimeUs)
%PACKET_SAMPLES Packet plus its trailing idle gap, in samples at OSF.
meta = papr_field_meta(cfg, osf, idleTimeUs);
n = meta.packetLen + meta.idleLen;
end

function n = probe_samples(cfg, octets, osf, idleTimeUs)
%PROBE_SAMPLES Length of one real packet from the waveform generator.
bits = zeros(8*octets, 1);
tx = wlanWaveformGenerator(papr_bits_arg(cfg, bits), cfg, ...
    'NumPackets', 1, 'IdleTime', idleTimeUs*1e-6, 'OversamplingFactor', osf);
n = size(tx, 1);
end

function bw = bandwidth_mhz(cfg)
%BANDWIDTH_MHZ Channel bandwidth in MHz, for error messages.
bw = str2double(erase(cfg.ChannelBandwidth, 'CBW'));
end

function octets = payload_octets(cfg)
%PAYLOAD_OCTETS Payload length currently set on CFG, whatever it is called.
%   Mirrors the property split PAPR_PAYLOAD writes through.
if isa(cfg, 'wlanHTConfig')
    octets = cfg.PSDULength;
elseif isa(cfg, 'wlanEHTMUConfig') || isa(cfg, 'wlanEHTTBConfig')
    octets = cfg.User{1}.APEPLength;
else
    octets = cfg.APEPLength;
end
end
