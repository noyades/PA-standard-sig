function edgeHz = papr_wlan_edge_hz(cfg)
%PAPR_WLAN_EDGE_HZ Outer edge of the occupied band of an 802.11 data field.
%   EDGEHZ = PAPR_WLAN_EDGE_HZ(CFG) returns, in Hz from the carrier, the
%   outermost active data subcarrier plus half a subcarrier spacing, for a
%   wlanHTConfig, wlanVHTConfig, wlanHESUConfig / wlanHEMUConfig or
%   wlanEHTMUConfig. The legacy preamble fields sit inside this edge at
%   every bandwidth, so it bounds the whole packet. It is the passband edge
%   PAPR_LOOP_FILTER keeps flat.
%
%   See also PAPR_LOOP_FILTER.

switch class(cfg)
    case 'wlanHTConfig'
        info = wlanHTOFDMInfo('HT-Data', cfg);
    case 'wlanVHTConfig'
        info = wlanVHTOFDMInfo('VHT-Data', cfg);
    case {'wlanHESUConfig', 'wlanHEMUConfig'}
        info = wlanHEOFDMInfo('HE-Data', cfg);
    case 'wlanEHTMUConfig'
        info = wlanEHTOFDMInfo('EHT-Data', cfg);
    otherwise
        error('papr_wlan_edge_hz:UnsupportedConfig', ...
            'No OFDM info function for a %s.', class(cfg));
end
scs = wlanSampleRate(cfg) / info.FFTLength;
edgeHz = (max(abs(double(info.ActiveFrequencyIndices))) + 0.5) * scs;
end
