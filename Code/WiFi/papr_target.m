function [meanDb, stdDb, n] = papr_target(standard, mcs, bw, mode)
%PAPR_TARGET Look up the measured PAPR target for one MCS/BW combination.
%   [MEANDB, STDDB, N] = PAPR_TARGET(STANDARD, MCS, BW, MODE)
%   STANDARD is 'ht' or 'vht'; MODE is 'data' or 'full'.
%
%   Values come from papr_targets.csv, produced by gen_papr_targets. They
%   replace the switch/case tables that used to be inlined in the runGen
%   sections: those were populated from runs whose burst maximum could be
%   pinned to a deterministic preamble sample, which is why several 80 and
%   160 MHz entries carried impossibly small spreads (CBW160 MCS 2 recorded a
%   variance of 0.007, against ~0.09 for a healthy combination).
%
%   Regenerate with:
%     matlab -batch "run('gen_papr_targets.m')"
%
%   See also GEN_PAPR_TARGETS, PAPR_BURST_DB.

if nargin < 4 || isempty(mode)
    mode = 'data';
end

csvPath = fullfile(fileparts(mfilename('fullpath')), 'papr_targets.csv');
if ~isfile(csvPath)
    error('papr_target:MissingTable', ...
        ['%s not found. Generate it with:\n' ...
         '    matlab -batch "run(''gen_papr_targets.m'')"'], csvPath);
end

T = readtable(csvPath, 'TextType', 'char');
hit = strcmpi(T.standard, standard) & T.mcs == mcs & T.bw == bw & ...
      strcmpi(T.mode, mode);

if ~any(hit)
    error('papr_target:NoEntry', ...
        ['No %s entry for MCS %d at %d MHz in %s mode. Add that combination ' ...
         'to the sweep in gen_papr_targets and regenerate the table.'], ...
        upper(standard), mcs, bw, mode);
end
if sum(hit) > 1
    warning('papr_target:DuplicateEntry', ...
        'Multiple rows matched %s MCS %d BW %d (%s); using the first.', ...
        upper(standard), mcs, bw, mode);
    hit = find(hit, 1);
end

meanDb = T.mean_db(hit);
stdDb  = T.std_db(hit);
n      = T.trials(hit);
end
