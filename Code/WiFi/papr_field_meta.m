function paprMeta = papr_field_meta(cfg, osf, idleTimeUs)
%PAPR_FIELD_META Sample offsets of the preamble/data fields within one packet.
%   PAPRMETA = PAPR_FIELD_META(CFG, OSF, IDLETIMEUS) works for wlanHTConfig
%   (802.11n), wlanVHTConfig (802.11ac), wlanHESUConfig / wlanHEMUConfig
%   (802.11ax) and wlanEHTMUConfig (802.11be), so every script measures PAPR
%   over identically defined sample sets.
%
%   The packet length is taken from the LAST non-empty field, not from the
%   data field. HT and VHT packets do end with their data field, but HE and
%   EHT append a packet-extension field (HEPE / EHTPE) after it. Deriving the
%   stride from the data field alone made it too short for those formats, so
%   the per-packet offsets drifted and every packet after the first was read
%   from the wrong place.
%
%   The returned struct is consumed by PAPR_BURST_DB.
%
%   See also PAPR_BURST_DB.

idx = wlanFieldIndices(cfg, 'OversamplingFactor', osf);

dataFields = {'VHTData', 'HTData', 'HEData', 'EHTData'};
dataIdx = [];
for k = 1:numel(dataFields)
    if isfield(idx, dataFields{k}) && ~isempty(idx.(dataFields{k}))
        dataIdx = double(idx.(dataFields{k}));
        break;
    end
end
if isempty(dataIdx)
    error('papr_field_meta:UnsupportedConfig', ...
        'No recognised data field index found for a %s.', class(cfg));
end

% Packet end = end of the last field that carries samples.
names = fieldnames(idx);
packetEnd = 0;
for k = 1:numel(names)
    v = idx.(names{k});
    if ~isempty(v) && double(v(2)) > packetEnd
        packetEnd = double(v(2));
    end
end

paprMeta.packetStart = double(idx.LSTF(1));
paprMeta.packetLen   = packetEnd - double(idx.LSTF(1)) + 1;
paprMeta.dataStart   = dataIdx(1);
paprMeta.dataLen     = dataIdx(2) - dataIdx(1) + 1;
paprMeta.idleLen     = round(idleTimeUs * 1e-6 * wlanSampleRate(cfg) * osf);
end
