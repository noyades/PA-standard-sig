function ex = papr_export_rate(nativeFs, genFs, budgetSamples)
%PAPR_EXPORT_RATE Sample rate and length a waveform is exported at.
%   EX = PAPR_EXPORT_RATE(NATIVEFS, GENFS, BUDGETSAMPLES) picks the rate a
%   loop generated at GENFS is written out at, and how many samples fit the
%   memory budget at that rate. NATIVEFS is the standard's own rate: the
%   channel bandwidth for 802.11, Nfft x SCS for 5G NR.
%
%   Generation and PAPR matching stay at GENFS (4x), which is what the
%   PAPR target tables were measured at. The export is then resampled
%   down, because a 4x file only plays on generators whose ARB clock goes
%   that high: 320 MHz EHT would need 1.28 GS/s. A signal generator's ARB
%   interpolates to its DAC rate itself, so the file only has to carry the
%   band. The rule is 2x the native rate (PAPR_EXPORT_OSF), capped at the
%   ARB clock limit (PAPR_MAX_FS_MHZ, default 600), and never below 1x.
%
%   PAPR_LOOP_RESAMPLE is exact only when the loop lasts the same time at
%   both rates, i.e. EXPORT samples x GENFS / EXPORTFS is an integer. The
%   export length is therefore rounded down to the nearest length for
%   which that holds; the budget is a ceiling, so a few samples short is
%   fine and over is not.
%
%   EX has fields
%     fs           export sample rate [Hz]
%     osf          fs / nativeFs
%     samples      export length, <= BUDGETSAMPLES
%     genSamples   the same loop's length at GENFS (the budget to generate to)
%
%   See also PAPR_LOOP_RESAMPLE, PAPR_LOOP_FILTER.

osfWanted = env_num('PAPR_EXPORT_OSF', 2);
maxFs     = env_num('PAPR_MAX_FS_MHZ', 600) * 1e6;

fs = round(min(osfWanted * nativeFs, maxFs));
if fs < nativeFs
    error('papr_export_rate:ClockTooLow', ...
        ['A %.2f MS/s ARB clock limit is below the %.2f MS/s this signal ' ...
         'needs. Raise PAPR_MAX_FS_MHZ.'], maxFs/1e6, nativeFs/1e6);
end
fs = min(fs, round(genFs));

% Loop duration must match at both rates: samples * genFs / fs integral.
g = gcd(round(genFs), fs);
step = fs / g;                                   % export length granularity
ex.fs = fs;
ex.osf = fs / nativeFs;
ex.samples = floor(budgetSamples / step) * step;
ex.genSamples = ex.samples * round(genFs) / fs;
end
