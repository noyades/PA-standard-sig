function [modulation, codeRate, Qm] = papr_5g_mcs(mcs, table, transformPrecoding, pi2bpsk)
%PAPR_5G_MCS Modulation and target code rate for a 5G NR MCS index.
%   [MODULATION, CODERATE, QM] = PAPR_5G_MCS(MCS, TABLE) resolves an MCS
%   index the way TS 38.214 does for CP-OFDM. TABLE is '64QAM' (Table
%   5.1.3.1-1, the default) or '256QAM' (Table 5.1.3.1-2). NR has no single
%   MCS-to-rate mapping the way 802.11 does: the table is a separate
%   configuration choice, and the same index means a different rate in each.
%
%   [...] = PAPR_5G_MCS(MCS, TABLE, TRANSFORMPRECODING, PI2BPSK) selects
%   the uplink DFT-s-OFDM tables when TRANSFORMPRECODING is true: Table
%   6.1.4.1-1 for '64QAM', where indices 0 and 1 use pi/2-BPSK when PI2BPSK
%   is set (q = 1) and QPSK otherwise (q = 2), and Table 6.1.4.1-2 for
%   '256QAM', which is identical to the downlink table.
%
%   MODULATION is the string nrWavegenPDSCHConfig / nrWavegenPUSCHConfig
%   expect, CODERATE is the target code rate as a fraction and QM the bits
%   per symbol.
%
%   See also PAPR_5G_CONFIG.

if nargin < 2 || isempty(table)
    table = '64QAM';
end
if nargin < 3 || isempty(transformPrecoding)
    transformPrecoding = false;
end
if nargin < 4 || isempty(pi2bpsk)
    pi2bpsk = false;
end
validateattributes(mcs, {'numeric'}, {'scalar', 'integer', 'nonnegative'}, mfilename, 'mcs');

% Columns: Qm, R*1024. Rows are MCS index 0 upward.
switch lower(table)
    case '64qam'
        if transformPrecoding
            % TS 38.214 Table 6.1.4.1-1. The first two rows are q, 240/q and
            % q, 314/q; q is filled in below.
            T = [NaN NaN; NaN NaN; 2 193; 2 251; 2 308; 2 379; 2 449; 2 526; ...
                 2 602; 2 679; 4 340; 4 378; 4 434; 4 490; 4 553; 4 616; ...
                 4 658; 6 466; 6 517; 6 567; 6 616; 6 666; 6 719; 6 772; ...
                 6 822; 6 873; 6 910; 6 948];
            q = 2 - double(pi2bpsk);
            T(1, :) = [q, 240/q];
            T(2, :) = [q, 314/q];
        else
            % TS 38.214 Table 5.1.3.1-1.
            T = [2 120; 2 157; 2 193; 2 251; 2 308; 2 379; 2 449; 2 526; ...
                 2 602; 2 679; 4 340; 4 378; 4 434; 4 490; 4 553; 4 616; ...
                 4 658; 6 438; 6 466; 6 517; 6 567; 6 616; 6 666; 6 719; ...
                 6 772; 6 822; 6 873; 6 910; 6 948];
        end
    case '256qam'
        % TS 38.214 Table 5.1.3.1-2; Table 6.1.4.1-2 is the same list.
        T = [2 120; 2 193; 2 308; 2 449; 2 602; 4 378; 4 434; 4 490; ...
             4 553; 4 616; 4 658; 6 466; 6 517; 6 567; 6 616; 6 666; ...
             6 719; 6 772; 6 822; 6 873; 8 682.5; 8 711; 8 754; 8 797; ...
             8 841; 8 885; 8 916.5; 8 948];
    otherwise
        error('papr_5g_mcs:UnknownTable', ...
            'Unknown MCS table "%s"; expected 64QAM or 256QAM.', table);
end

if mcs + 1 > size(T, 1)
    error('papr_5g_mcs:Reserved', ...
        'MCS %d is reserved in the %s table (valid range 0..%d).', ...
        mcs, upper(table), size(T, 1) - 1);
end
Qm = T(mcs + 1, 1);
codeRate = T(mcs + 1, 2) / 1024;

switch Qm
    case 1, modulation = 'pi/2-BPSK';
    case 2, modulation = 'QPSK';
    case 4, modulation = '16QAM';
    case 6, modulation = '64QAM';
    case 8, modulation = '256QAM';
end
end
