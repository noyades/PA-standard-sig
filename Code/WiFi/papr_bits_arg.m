function arg = papr_bits_arg(cfg, bits)
%PAPR_BITS_ARG Wrap PSDU bits the way wlanWaveformGenerator expects.
%   EHT configurations are multi-user objects even when NumUsers is 1, so
%   wlanWaveformGenerator wants a cell array of per-user bit vectors. HT, VHT
%   and HE single-user configurations take the bare vector.
%
%   See also PAPR_PAYLOAD.

if isa(cfg, 'wlanEHTMUConfig') || isa(cfg, 'wlanEHTTBConfig') || isa(cfg, 'wlanHEMUConfig')
    arg = {bits};
else
    arg = bits;
end
end
