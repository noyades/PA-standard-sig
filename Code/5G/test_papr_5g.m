%% test_papr_5g - checks for the 5G NR PAPR helpers and the shared accumulator
%  Run from anywhere:  matlab -batch "run('Code/5G/test_papr_5g.m')"
%
%  1. The range-form rewrite of papr_burst_accum reproduces the original
%     stride arithmetic on an 802.11 burst, in both measurement modes.
%  2. papr_5g_meta's data ranges land on whole PDSCH/PUSCH symbols and
%     exclude CORESET and DM-RS symbols.
%  3. The chunked NR stream gives the same PAPR as one measurement over
%     the concatenated chunks.
%  4. Uplink DFT-s-OFDM measures lower than CP-OFDM, and pi/2-BPSK lower
%     still, which is the physics the uplink study exists to show.
%  5. A TDD slot pattern leaves the unscheduled slots silent and the
%     'full' mode ignores them.

clear variables; clc;
scriptDir = fileparts(mfilename('fullpath'));
addpath(scriptDir);
addpath(fullfile(fileparts(scriptDir), 'WiFi'));
addpath(fileparts(scriptDir));
rng(7);
nFail = 0;

%% 1. 802.11 regression against the pre-refactor stride arithmetic
cfgVHT = papr_std_config('vht', 20, 4, 1);
cfgVHT = papr_payload(cfgVHT, 4, 300);
osf = 2; idleUs = 8; nPkts = 3;
meta = papr_field_meta(cfgVHT, osf, idleUs);
bits = randi([0 1], 8*300*nPkts, 1);
tx = wlanWaveformGenerator(papr_bits_arg(cfgVHT, bits), cfgVHT, 'NumPackets', nPkts, ...
    'IdleTime', idleUs*1e-6, 'OversamplingFactor', osf, 'WindowTransitionTime', 0);
pow = abs(tx).^2;
stride = meta.packetLen + meta.idleLen;
sel = false(size(pow));
for p = 1:nPkts
    s1 = 1 + (p-1)*stride + (meta.dataStart - meta.packetStart);
    sel(s1:s1+meta.dataLen-1) = true;
end
refData = 10*log10(max(pow(sel)) / mean(pow(sel)));
act = pow(pow > max(pow)*1e-5);
refFull = 10*log10(max(act) / mean(act));
[gotData, preData] = papr_burst_db(tx, meta, nPkts, true);
[gotFull, preFull] = papr_burst_db(tx, meta, nPkts, false);
[~, mi] = max(pow);
refPre = mod(mi-1, stride) < (meta.dataStart - meta.packetStart);
nFail = nFail + check(abs(gotData - refData) < 1e-12, 'WiFi data mode unchanged (%.4f dB)', gotData);
nFail = nFail + check(abs(gotFull - refFull) < 1e-12, 'WiFi full mode unchanged (%.4f dB)', gotFull);
nFail = nFail + check(~preData && preFull == refPre, 'WiFi maxInPreamble flags unchanged');

%% 2. Downlink sample map
[cfgDL, infoDL] = papr_5g_config('dl', 20, 15, 10, 2);
planDL = papr_5g_stream_plan(cfgDL, infoDL, true);
m = planDL.meta;
fprintf('DL 20 MHz/15 kHz: nrb=%d fs=%.2f MHz unit=%d samples (%d subframe), %d data ranges, %d bits/unit\n', ...
    infoDL.nrb, infoDL.fs/1e6, m.unitLen, m.subframesPerUnit, size(m.dataRanges,1), m.bitsPerUnit);
nFail = nFail + check(infoDL.nrb == 106 && infoDL.fs == 2*30.72e6, 'DL 20 MHz/15 kHz is 106 RB at 2x30.72 MS/s');
nFail = nFail + check(m.subframesPerUnit == 1 && m.unitLen == infoDL.fs*1e-3, 'DL unit is one subframe');
syms = m.dataSymbols{1};
nFail = nFail + check(~any(ismember([0 1], syms)), 'CORESET symbols 0-1 excluded from data');
nFail = nFail + check(~ismember(2, syms) && all(ismember(3:13, syms)), 'DM-RS symbol 2 excluded, 3-13 are data');
tx1 = planDL.generate(1, 0, 1);
nFail = nFail + check(size(tx1,1) == m.unitLen, 'generate(1 unit) length matches unitLen');
% Data-mode PAPR by direct masking must equal the accumulator.
mask = false(m.unitLen, 1);
for r = 1:size(m.dataRanges,1)
    mask(m.dataRanges(r,1)+1 : m.dataRanges(r,2)+1) = true;
end
p1 = abs(tx1).^2;
ref = 10*log10(max(p1(mask)) / mean(p1(mask)));
got = papr_burst_db(tx1, m, 1, true);
nFail = nFail + check(abs(got - ref) < 1e-12, 'DL data-mode PAPR matches direct mask (%.3f dB)', got);
nFail = nFail + check(mean(mask) > 0.7 && mean(mask) < 0.9, 'data mask covers 11/14 of the unit (%.1f%%)', 100*mean(mask));

%% 3. Chunked stream equals one measurement over the concatenation
nUnits = 3; seed = 42;
planDL1 = planDL; planDL1.pktsPerChunk = 1;
streamed = papr_burst_stream_db([], [], nUnits, seed, planDL1);
cat3 = [planDL.generate(1, 0, seed); planDL.generate(1, 1, seed); planDL.generate(1, 2, seed)];
whole = papr_burst_db(cat3, m, nUnits, true);
nFail = nFail + check(abs(streamed - whole) < 1e-12, 'streamed == concatenated (%.3f dB)', streamed);
a = planDL.generate(1, 0, 5); b = planDL.generate(1, 0, 6);
nFail = nFail + check(~isequal(a, b), 'different seeds give different payloads');
a2 = planDL.generate(1, 0, 5);
nFail = nFail + check(isequal(a, a2), 'same seed reproduces the chunk');

%% 4. Uplink: CP-OFDM vs DFT-s-OFDM vs pi/2-BPSK
[cfgCP, infoCP] = papr_5g_config('ul', 20, 15, 2, 2);
[cfgTP, infoTP] = papr_5g_config('ul', 20, 15, 2, 2, struct('TransformPrecoding', true));
[cfgBP, infoBP] = papr_5g_config('ul', 20, 15, 0, 2, struct('TransformPrecoding', true, 'Pi2BPSK', true));
nFail = nFail + check(strcmp(infoCP.modulation,'QPSK') && strcmp(infoTP.modulation,'QPSK') && ...
    strcmp(infoBP.modulation,'pi/2-BPSK'), 'UL modulations resolved: %s / %s / %s', ...
    infoCP.modulation, infoTP.modulation, infoBP.modulation);
pCP = papr_5g_stream_plan(cfgCP, infoCP, true);
pTP = papr_5g_stream_plan(cfgTP, infoTP, true);
pBP = papr_5g_stream_plan(cfgBP, infoBP, true);
nTr = 4; v = zeros(nTr, 3);
for t = 1:nTr
    v(t,1) = papr_burst_stream_db([], [], 2, t, pCP);
    v(t,2) = papr_burst_stream_db([], [], 2, t, pTP);
    v(t,3) = papr_burst_stream_db([], [], 2, t, pBP);
end
mv = mean(v);
fprintf('UL 20 MHz QPSK data-field PAPR over %d trials: CP-OFDM %.2f dB, DFT-s-OFDM %.2f dB, pi/2-BPSK %.2f dB\n', ...
    nTr, mv(1), mv(2), mv(3));
nFail = nFail + check(mv(1) - mv(2) > 1.5, 'DFT-s-OFDM is >1.5 dB below CP-OFDM');
nFail = nFail + check(mv(2) - mv(3) > 0.5, 'pi/2-BPSK is >0.5 dB below DFT-s-OFDM QPSK');
sUL = pCP.meta.dataSymbols{1};
nFail = nFail + check(all(ismember([0 1], sUL)) && ~ismember(2, sUL), 'UL data covers symbols 0-1, DM-RS symbol 2 excluded');

%% 5. TDD pattern at 30 kHz: slots 0-3 of a 10-slot period
opts = struct('SlotAllocation', 0:3, 'Period', 10);
[cfgTD, infoTD] = papr_5g_config('ul', 20, 30, 2, 1, opts);
pTD = papr_5g_stream_plan(cfgTD, infoTD, false);
mTD = pTD.meta;
nFail = nFail + check(mTD.subframesPerUnit == 5 && mTD.slotsPerUnit == 10, 'TDD unit is 5 subframes / 10 slots');
sched = ~cellfun(@isempty, mTD.dataSymbols);
nFail = nFail + check(isequal(find(sched)-1, 0:3), 'only slots 0-3 scheduled');
txTD = pTD.generate(1, 0, 3);
slotLen = mTD.unitLen / mTD.slotsPerUnit;
off = abs(txTD(4*slotLen+1:end)).^2;
nFail = nFail + check(max(off) < max(abs(txTD).^2)*1e-10, 'unscheduled slots are silent');
pw = abs(txTD).^2; act = pw(pw > max(pw)*1e-5);
refTD = 10*log10(max(act)/mean(act));
[gotTD, preTD] = papr_burst_db(txTD, mTD, 1, false);
nFail = nFail + check(abs(gotTD - refTD) < 1e-12, 'TDD full mode ignores silent slots (%.3f dB)', gotTD);
maskTD = false(mTD.unitLen, 1);
for r = 1:size(mTD.dataRanges,1)
    maskTD(mTD.dataRanges(r,1)+1 : mTD.dataRanges(r,2)+1) = true;
end
[~, miTD] = max(pw);
where = {'data', 'DM-RS'};
nFail = nFail + check(preTD == ~maskTD(miTD), 'full-mode outside-data flag agrees with the mask (max in %s)', ...
    where{1 + ~maskTD(miTD)});

%% Summary
if nFail == 0
    fprintf('\nALL CHECKS PASSED\n');
else
    fprintf('\n%d CHECK(S) FAILED\n', nFail);
    if batchStartupOptionUsed
        exit(1);
    end
end

function bad = check(ok, fmt, varargin)
if ok
    fprintf('  ok   %s\n', sprintf(fmt, varargin{:}));
    bad = 0;
else
    fprintf('  FAIL %s\n', sprintf(fmt, varargin{:}));
    bad = 1;
end
end
