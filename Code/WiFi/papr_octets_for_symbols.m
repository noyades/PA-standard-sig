function [octets, nSym] = papr_octets_for_symbols(cfg, targetSymbols, osf)
%PAPR_OCTETS_FOR_SYMBOLS Payload length that yields a given data symbol count.
%   [OCTETS, NSYM] = PAPR_OCTETS_FOR_SYMBOLS(CFG, TARGETSYMBOLS, OSF)
%
%   Binary-searches the payload length and reads the achieved symbol count
%   back from wlanFieldIndices, so it needs no Nbpscs/coding-rate table. That
%   matters for HE and EHT, whose MCS sets extend to 1024-QAM and 4096-QAM
%   and whose padding rules (pre-FEC and packet extension) do not follow the
%   simple floor((nSym*Ndbps - 22)/8) arithmetic the HT/VHT scripts use.
%
%   NSYM is the count actually achieved, which is the largest attainable
%   value when TARGETSYMBOLS exceeds what the 5.484 ms TXOP limit allows
%   (339 symbols for HE/EHT at the default 3.2 us guard interval).
%
%   See also PAPR_PAYLOAD, PAPR_SYMBOL_US.

if nargin < 3 || isempty(osf)
    osf = 1;
end

symLen = round(papr_symbol_us(cfg) * 1e-6 * wlanSampleRate(cfg) * osf);
if symLen <= 0
    error('papr_octets_for_symbols:BadSymbolLength', ...
        'Computed a non-positive OFDM symbol length.');
end

if isa(cfg, 'wlanHTConfig')
    hiLimit = 65535;
elseif isa(cfg, 'wlanEHTMUConfig') || isa(cfg, 'wlanEHTTBConfig')
    hiLimit = 6500631;
else
    hiLimit = 1048575;
end

% Grow until the target is met or the format refuses a longer packet.
lo = 1;
hi = 1;
while hi < hiLimit
    n = symbols_at(cfg, hi, osf, symLen);
    if isnan(n) || n >= targetSymbols
        break;
    end
    lo = hi;
    hi = min(hi * 2, hiLimit);
end

% Largest length whose symbol count does not exceed the target.
best = lo;
bestN = symbols_at(cfg, lo, osf, symLen);
while lo <= hi
    mid = floor((lo + hi) / 2);
    n = symbols_at(cfg, mid, osf, symLen);
    if isnan(n) || n > targetSymbols
        hi = mid - 1;             % too long, or rejected by the TXOP limit
    else
        best = mid; bestN = n;
        lo = mid + 1;
    end
end

octets = best;
nSym = bestN;
end

function n = symbols_at(cfg, octets, osf, symLen)
%SYMBOLS_AT Data symbol count for a candidate length, NaN if the format
%   rejects it (validateMCSLengthTxTime throws past the TXOP limit).
try
    probe = papr_payload(cfg, [], octets);
    meta = papr_field_meta(probe, osf, 0);
    n = round(meta.dataLen / symLen);
catch
    n = NaN;
end
end
