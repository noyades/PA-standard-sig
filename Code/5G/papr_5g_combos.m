function combos = papr_5g_combos()
%PAPR_5G_COMBOS Channel coverage of the 5G NR study: (SCS kHz, BW MHz) rows.
%   FR1 at 15 and 30 kHz, FR2 at 120 kHz. One list feeds both the target
%   sweep (gen_papr_5g_targets) and the generation sweep (run_5g_all), so
%   the targets table always covers what the generators ask for.
%
%   See also GEN_PAPR_5G_TARGETS, RUN_5G_ALL, PAPR_5G_CONFIG.

combos = [ 15   5;  15  10;  15  20; ...
           30  20;  30  50;  30 100; ...
          120 100; 120 200; 120 400];
end
