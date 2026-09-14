function [tx, cfg] = papr_5g_generate(cfg, meta, nUnits, unitOffset, seed)
%PAPR_5G_GENERATE One chunk of a 5G NR burst with an explicit random payload.
%   TX = PAPR_5G_GENERATE(CFG, META, NUNITS, UNITOFFSET, SEED) generates
%   NUNITS units (see PAPR_5G_META) starting UNITOFFSET units into the
%   burst, so slot and frame numbering - and with it scrambling, DM-RS
%   sequences and the SS burst period - continue across chunks the way one
%   long nrWaveformGenerator call would number them.
%
%   The transport blocks are filled from a payload drawn with RANDI after
%   seeding the generator from SEED and UNITOFFSET, rather than the PN
%   sequence the toolbox defaults to. A PN source restarts identically on
%   every call, so two trials would carry the same bits and the PAPR
%   samples would not be independent draws. SEED plays the part the
%   scrambler seed plays in the 802.11 scripts: one value per trial. Pass
%   [] to leave the random generator alone.
%
%   [TX, CFG] = ... also returns the configuration the chunk was generated
%   with (NumSubframes, InitialNSubframe and DataSource filled in), which
%   the receiver check in the generation scripts needs.
%
%   See also PAPR_5G_META, PAPR_5G_STREAM_PLAN, PAPR_BURST_STREAM_DB.

if nargin < 4 || isempty(unitOffset)
    unitOffset = 0;
end
if nargin < 5
    seed = [];
end

cfg.NumSubframes = nUnits * meta.subframesPerUnit;
cfg.InitialNSubframe = unitOffset * meta.subframesPerUnit;

if ~isempty(seed)
    % Distinct stream per (trial, chunk); 2^32 wrap keeps rng happy for any
    % seed the caller draws.
    rng(mod(double(seed) * 1000003 + unitOffset, 2^32), 'twister');
end
bits = randi([0 1], meta.bitsPerUnit * nUnits, 1);
cfg.(meta.channel){1}.DataSource = bits;

tx = nrWaveformGenerator(cfg);
end
