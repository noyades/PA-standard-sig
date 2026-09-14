function [meanDb, stdDb, n] = papr_5g_target(direction, waveform, mcsTable, mcs, bw, scs, mode)
%PAPR_5G_TARGET Look up the measured PAPR target for one 5G NR combination.
%   [MEANDB, STDDB, N] = PAPR_5G_TARGET(DIRECTION, WAVEFORM, MCSTABLE, MCS,
%   BW, SCS, MODE) with DIRECTION 'dl' or 'ul', WAVEFORM 'cp-ofdm' or
%   'dft-s-ofdm', MCSTABLE '64QAM' or '256QAM', BW in MHz, SCS in kHz and
%   MODE 'data' or 'full'.
%
%   NR needs three more keys than the 802.11 table (direction, waveform
%   type and subcarrier spacing), so the targets live in their own file,
%   papr_5g_targets.csv, produced by GEN_PAPR_5G_TARGETS with the same
%   measurement definition the generation scripts use. Regenerate with:
%     matlab -batch "run('gen_papr_5g_targets.m')"
%
%   See also GEN_PAPR_5G_TARGETS, PAPR_TARGET, PAPR_BURST_DB.

if nargin < 7 || isempty(mode)
    mode = 'data';
end
csvPath = fullfile(fileparts(mfilename('fullpath')), 'papr_5g_targets.csv');
if ~isfile(csvPath)
    error('papr_5g_target:MissingTable', ...
        ['%s not found. Generate it with:\n' ...
         '    matlab -batch "run(''gen_papr_5g_targets.m'')"'], csvPath);
end
T = readtable(csvPath, 'TextType', 'char');
hit = strcmpi(T.direction, direction) & strcmpi(T.waveform, waveform) & ...
      strcmpi(T.mcs_table, mcsTable) & T.mcs == mcs & T.bw == bw & ...
      T.scs == scs & strcmpi(T.mode, mode);
if ~any(hit)
    error('papr_5g_target:NoEntry', ...
        ['No %s %s entry for MCS %d (%s table) at %d MHz / %d kHz in %s mode. ' ...
         'Add that combination to the sweep in gen_papr_5g_targets and regenerate.'], ...
        upper(direction), waveform, mcs, mcsTable, bw, scs, mode);
end
if sum(hit) > 1
    warning('papr_5g_target:DuplicateEntry', ...
        'Multiple rows matched %s %s MCS %d BW %d SCS %d (%s); using the first.', ...
        upper(direction), waveform, mcs, bw, scs, mode);
    hit = find(hit, 1);
end
meanDb = T.mean_db(hit);
stdDb  = T.std_db(hit);
n      = T.trials(hit);
end
