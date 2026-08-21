function nsd = papr_nsd(standard, bw)
%PAPR_NSD Data subcarriers per OFDM symbol, single stream, full bandwidth.
%   NSD = PAPR_NSD(STANDARD, BW) with STANDARD one of 'ht', 'vht', 'he',
%   'eht' and BW in MHz.
%
%   HE and EHT use a 12.8 us FFT rather than the 3.2 us FFT of HT/VHT, giving
%   four times the subcarriers for the same bandwidth. Their OFDM symbol is
%   correspondingly longer: 16 us at the default 3.2 us guard interval,
%   against 4 us for HT/VHT. That matters when choosing a symbol count, since
%   the 5.484 ms TXOP limit caps an HE or EHT packet at 339 data symbols.
%
%   See also PAPR_MCS_LIST.

switch lower(standard)
    case 'ht'
        map = containers.Map([20 40], [52 108]);
    case 'vht'
        map = containers.Map([20 40 80 160], [52 108 234 468]);
    case {'he', 'eht'}
        map = containers.Map([20 40 80 160 320], [234 468 980 1960 3920]);
    otherwise
        error('papr_nsd:UnknownStandard', ...
            'Unknown standard "%s"; expected ht, vht, he or eht.', standard);
end

if ~isKey(map, bw)
    error('papr_nsd:UnsupportedBandwidth', ...
        '%s does not define a %d MHz channel.', upper(standard), bw);
end
nsd = map(bw);
end
