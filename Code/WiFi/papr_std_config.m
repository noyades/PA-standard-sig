function cfg = papr_std_config(standard, bw, mcs, numTX)
%PAPR_STD_CONFIG Single-user, full-bandwidth config for any of the four standards.
%   CFG = PAPR_STD_CONFIG(STANDARD, BW, MCS, NUMTX) with STANDARD one of
%   'ht', 'vht', 'he', 'eht'.
%
%   Centralising this keeps the four scripts comparable: same spatial
%   mapping, same stream count, same coding choice. EHT is built through
%   wlanEHTMUConfig because that is the only EHT transmit configuration the
%   toolbox offers for a downlink packet; with the default allocation it is a
%   single user occupying the whole channel.
%
%   See also PAPR_PAYLOAD, PAPR_BITS_ARG, PAPR_NSD.

if nargin < 4 || isempty(numTX)
    numTX = 1;
end
chanBW = sprintf('CBW%d', bw);

switch lower(standard)
    case 'ht'
        cfg = wlanHTConfig('ChannelBandwidth', chanBW);
        cfg.NumTransmitAntennas = numTX;
        cfg.NumSpaceTimeStreams = numTX;
        cfg.SpatialMapping = 'Direct';
        cfg.MCS = mcs;

    case 'vht'
        cfg = wlanVHTConfig('ChannelBandwidth', chanBW);
        cfg.NumTransmitAntennas = numTX;
        cfg.NumSpaceTimeStreams = numTX;
        cfg.SpatialMapping = 'Direct';
        cfg.STBC = false;
        cfg.GuardInterval = 'Long';
        cfg.MCS = mcs;

    case 'he'
        cfg = wlanHESUConfig('ChannelBandwidth', chanBW);
        cfg.NumTransmitAntennas = numTX;
        cfg.NumSpaceTimeStreams = numTX;
        cfg.SpatialMapping = 'Direct';
        cfg.STBC = false;
        cfg.ChannelCoding = 'LDPC';
        cfg.MCS = mcs;

    case 'eht'
        cfg = wlanEHTMUConfig(chanBW);
        cfg.NumTransmitAntennas = numTX;
        cfg.User{1}.NumSpaceTimeStreams = numTX;
        cfg.User{1}.ChannelCoding = 'LDPC';
        cfg.User{1}.MCS = mcs;

    otherwise
        error('papr_std_config:UnknownStandard', ...
            'Unknown standard "%s"; expected ht, vht, he or eht.', standard);
end
end
