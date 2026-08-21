function [cfg, octets] = papr_payload(cfg, mcs, octets)
%PAPR_PAYLOAD Set MCS and payload length on any WLAN config object.
%   [CFG, OCTETS] = PAPR_PAYLOAD(CFG, MCS, OCTETS)
%
%   The four formats do not agree on where these live:
%     wlanHTConfig    cfg.MCS, cfg.PSDULength   (max 65535)
%     wlanVHTConfig   cfg.MCS, cfg.APEPLength   (max 1048575)
%     wlanHESUConfig  cfg.MCS, cfg.APEPLength
%     wlanEHTMUConfig cfg.User{1}.MCS, cfg.User{1}.APEPLength
%
%   EHT keeps per-user settings in a cell array of wlanEHTUser objects, so a
%   plain cfg.MCS assignment silently does the wrong thing (or errors). Route
%   every assignment through here instead.
%
%   Pass MCS empty to change only the length.
%
%   See also PAPR_BITS_ARG, PAPR_NSD, PAPR_OCTETS_FOR_SYMBOLS.

if isa(cfg, 'wlanHTConfig')
    octets = min(max(round(octets), 1), 65535);
    if ~isempty(mcs), cfg.MCS = mcs; end
    cfg.PSDULength = octets;
elseif isa(cfg, 'wlanEHTMUConfig') || isa(cfg, 'wlanEHTTBConfig')
    octets = min(max(round(octets), 1), 6500631);
    if ~isempty(mcs), cfg.User{1}.MCS = mcs; end
    cfg.User{1}.APEPLength = octets;
else   % VHT and HE share the top-level MCS/APEPLength interface
    octets = min(max(round(octets), 1), 1048575);
    if ~isempty(mcs), cfg.MCS = mcs; end
    cfg.APEPLength = octets;
end
end
