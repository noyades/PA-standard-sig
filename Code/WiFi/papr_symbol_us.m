function symUs = papr_symbol_us(cfg)
%PAPR_SYMBOL_US OFDM symbol duration in microseconds, guard interval included.
%   HT and VHT use a 3.2 us FFT with a 0.8 us ('Long') or 0.4 us ('Short')
%   guard interval. HE and EHT use a 12.8 us FFT with a numeric guard
%   interval of 0.8, 1.6 or 3.2 us, giving a 16 us symbol at the default 3.2.
%
%   The fourfold difference is why a symbol-count sweep cannot be shared
%   between the older and newer formats: 1000 symbols is 4 ms of HT/VHT data
%   but 16 ms of HE/EHT, well past the 5.484 ms TXOP limit.

gi = cfg.GuardInterval;

if isnumeric(gi)
    symUs = 12.8 + double(gi);        % HE / EHT
elseif strcmpi(gi, 'Short')
    symUs = 3.2 + 0.4;                % HT / VHT short GI
else
    symUs = 3.2 + 0.8;                % HT / VHT long GI
end
end
