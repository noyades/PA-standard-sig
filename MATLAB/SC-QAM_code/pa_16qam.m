clear variables; close all; clc;

%% ===================== USER SETTINGS =====================
figPath = 'G:\My Drive\PA_signalling\';
if ~exist(figPath, 'dir')
    mkdir(figPath);
end

M   = 64;
k   = log2(M);
sps = 4;

% Interpret 400e6 as bit rate
bitRate = 400e6;              % [bits/s]
symRate = bitRate / k;        % [symbols/s]
Tsym    = 1 / symRate;        % [s]
Fs      = symRate * sps;      % [samples/s]
Ts      = 1 / Fs;             % [s]

mem_mb = 128;
mem    = 8 * mem_mb * 2^20;   % [bits]
time   = mem / bitRate;       % [s]

filtLen = 12;                 % RRC span in symbols
rolloff = 0.35;
rrcFilter = rcosdesign(rolloff, filtLen, sps);

zeroPad = zeros(10*filtLen,1);   % padding for filter transient settling
zeroPadLen = numel(zeroPad);

% Matched timing trim after upfirdn
preDelay = sps*(filtLen/2) + 1 + sps*zeroPadLen;

figureType = 'png';
fontSize   = 8;

%% ===================== LONG-TERM MEAN POWER =====================
% NOTE:
% 1e8*k bits can be very large in memory/runtime. Reduce if needed.
NlongSym = 1e6;  % changed from 1e8 for practicality; increase if your machine allows

longdataBits    = randi([0 1], NlongSym*k, 1);
longdataSymbols = bi2de(reshape(longdataBits, k, []).', 'left-msb');
longdataMod     = qammod(longdataSymbols, M, 'bin');

longdataModPad  = [zeroPad; longdataMod; zeroPad];
longtxFiltSig   = upfirdn(longdataModPad, rrcFilter, sps, 1);

startIdx = preDelay;
stopIdx  = startIdx + length(longdataMod)*sps - 1;
longtxFiltSig = 2 * longtxFiltSig(startIdx:stopIdx);

longsigPower  = abs(longtxFiltSig).^2;
longpeakPower = max(longsigPower);
longmeanPower = mean(longsigPower);

fprintf('Long-term mean power = %.6f\n', longmeanPower);
fprintf('Long-term peak power = %.6f\n', longpeakPower);

%% ===================== PAPR DISTRIBUTION VS SYMBOL LENGTH =====================
% n = number of symbols in each burst
n    = [1e3, 1e4, 1e5, 1e6];
list = 10 * [1000, 1000, 1000, 1000];   % trials per burst length
bins = 200;

countsPAPR = zeros(bins, numel(n));
binsPAPR   = zeros(bins, numel(n));
cdfPAPR    = zeros(bins, numel(n));
maxPAPR    = zeros(1, numel(n));

% Keep this if intentional; otherwise use longmeanPower below
constNormFactor = 10;

for ib = 1:numel(n)
    Nb = n(ib);
    trials = list(ib);
    peakPower = zeros(trials,1);

    for t = 1:trials
        rng(t + 1000*ib, 'twister');

        dataBits    = randi([0 1], Nb*k, 1);
        dataSymbols = bi2de(reshape(dataBits, k, []).', 'left-msb');
        dataMod     = qammod(dataSymbols, M, 'bin');

        dataModPad = [zeroPad; dataMod; zeroPad];
        txFiltSig  = upfirdn(dataModPad, rrcFilter, sps, 1);

        startIdx = preDelay;
        stopIdx  = startIdx + numel(dataMod)*sps - 1;
        txSlice  = txFiltSig(startIdx:stopIdx);

        txSlice = 2 * txSlice;
        sigPower = abs(txSlice).^2;
        peakPower(t) = max(sigPower);
    end

    % Original normalization preserved
    PAPR_long = 10*log10(peakPower ./ constNormFactor);
    maxPAPR(ib) = max(PAPR_long);

    [counts, edges] = histcounts(PAPR_long, 'NumBins', bins);
    countsPAPR(:,ib) = counts(:);
    binsPAPR(:,ib)   = ((edges(1:end-1) + edges(2:end))/2).';
    cdfPAPR(:,ib)    = cumsum(counts(:)) / sum(counts);
end

figure(1);
plot(binsPAPR, 100*countsPAPR./list, 'LineWidth', 1);
xlabel('PAPR [dB]');
ylabel('Occurrences [%]');
grid on;

figure(2);
semilogy(binsPAPR, cdfPAPR, 'LineWidth', 1);
xlabel('PMEPR [dB]');
ylabel('F(PMEPR)');
legend(compose('%g', n), 'Location', 'SouthWest');
grid on;

%% ===================== PLOT PDF OF PAPR =====================
cmap = flipud(jet(256));
figureSize = [0.5 0.5 2.5 2];

xtick = 7.5:0.2:9.5;
ytick = 0:0.2:1.6;

figure3 = figure('Name','PAPR vs. Symbol Length', ...
    'Color',[1 1 1], ...
    'Units','inches', ...
    'Position',figureSize, ...
    'PaperPosition',figureSize);

plot1 = plot(binsPAPR+3, 100*smoothdata(countsPAPR,1)./list, 'LineWidth', 1);
xlabel('PAPR [dB]','fontsize',fontSize,'fontweight','normal','fontname','arial');
ylabel('Occurrences [%]','fontsize',fontSize,'fontweight','normal','fontname','arial');
grid on;

set(gca,'units','inches','fontSize',fontSize,'fontWeight','normal','fontName','arial');
set(gca,'gridlinestyle','--');
set(gca,'xtick',xtick);
set(gca,'ytick',ytick);
set(gca,'XColor',[0.25 0.25 0.25]);
set(gca,'YColor',[0.25 0.25 0.25]);
set(gca,'LineWidth',0.5);
axis([min(xtick) max(xtick) min(ytick) max(ytick)]);

set(plot1(1),'Linestyle','-','Marker','+','MarkerSize',3,'Color',cmap(1,:));
set(plot1(2),'Linestyle','-','Marker','x','MarkerSize',3,'Color',cmap(86,:));
set(plot1(3),'Linestyle','-','Marker','o','MarkerSize',3,'Color',cmap(171,:));
set(plot1(4),'Linestyle','-','Marker','^','MarkerSize',3,'Color',cmap(256,:));

legend(plot1, {'N=10^3','N=10^4','N=10^5','N=10^6'}, ...
    'Location','NorthWest','fontSize',6);

figurePath = fullfile(figPath, ['PAPRPDFvsNumSymbols.' figureType]);
print(figure3, '-dpng', '-r300', figurePath);

%% ===================== PLOT CCDF / CDF-STYLE PAPR =====================
figureSize = [0.5 0.5 2.5 2];
xtick = 7.5:0.2:9.5;
ytick = logspace(-4,0,5);

figure4 = figure('Name','PAPR CCDF vs. Symbol Length', ...
    'Color',[1 1 1], ...
    'Units','inches', ...
    'Position',figureSize, ...
    'PaperPosition',figureSize);

plot2 = semilogy(binsPAPR+3, 1-cdfPAPR, 'LineWidth', 1);
xlabel('S [dB]','fontsize',fontSize,'fontweight','normal','fontname','arial');
ylabel('Pr(PAPR > S)','fontsize',fontSize,'fontweight','normal','fontname','arial');
grid on;

set(gca,'units','inches','fontSize',fontSize,'fontWeight','normal','fontName','arial');
set(gca,'gridlinestyle','--');
set(gca,'xtick',xtick);
set(gca,'ytick',ytick);
set(gca,'XColor',[0.25 0.25 0.25]);
set(gca,'YColor',[0.25 0.25 0.25]);
set(gca,'LineWidth',0.5);
axis([min(xtick) max(xtick) min(ytick) max(ytick)]);

set(plot2(1),'Linestyle','-','Marker','+','MarkerSize',3,'Color',cmap(1,:));
set(plot2(2),'Linestyle','-','Marker','x','MarkerSize',3,'Color',cmap(86,:));
set(plot2(3),'Linestyle','-','Marker','o','MarkerSize',3,'Color',cmap(171,:));
set(plot2(4),'Linestyle','-','Marker','^','MarkerSize',3,'Color',cmap(256,:));

legend(plot2, {'N=10^3','N=10^4','N=10^5','N=10^6'}, ...
    'Location','SouthWest','fontSize',6);

figurePath = fullfile(figPath, ['PAPRvsNumSymbols.' figureType]);
print(figure4, '-dpng', '-r300', figurePath);

%% ===================== GENERATE ONE EXAMPLE BURST FOR TIME/CONSTELLATION PLOTS =====================
Nplot = 1000;
rng(1, 'twister');

dataBits    = randi([0 1], Nplot*k, 1);
dataSymbols = bi2de(reshape(dataBits, k, []).', 'left-msb');
dataMod     = qammod(dataSymbols, M, 'bin');

dataModPad = [zeroPad; dataMod; zeroPad];
txFiltSig  = upfirdn(dataModPad, rrcFilter, sps, 1);

startIdx = preDelay;
stopIdx  = startIdx + length(dataMod)*sps - 1;
txFiltSig = 2 * txFiltSig(startIdx:stopIdx);

% -------- FIXED ERROR: define tsym and tsymU --------
tsym  = (0:length(dataMod)-1).'    * Tsym * 1e6;   % [us]
tsymU = (0:length(txFiltSig)-1).'  * Ts   * 1e6;   % [us]

%% ===================== ENVELOPE VS TIME =====================
figureSize = [0.5 0.5 2.4375 2];
xtick = linspace(min(tsymU), max(tsymU), 5);
ytick = 0:1:6;

figure5 = figure('Name','16QAM Env vs. Time', ...
    'Color',[1 1 1], ...
    'Units','inches', ...
    'Position',figureSize, ...
    'PaperPosition',figureSize);

plot3 = plot(tsym, abs(dataMod), tsymU, abs(txFiltSig), 'LineWidth', 1);
xlabel('time [\mus]','fontsize',fontSize,'fontweight','normal','fontname','arial');
ylabel('Signal Envelope [a.u.]','fontsize',fontSize,'fontweight','normal','fontname','arial');
grid on;

set(gca,'units','inches','fontSize',fontSize,'fontWeight','normal','fontName','arial');
set(gca,'gridlinestyle','--');
set(gca,'xtick',xtick);
set(gca,'ytick',ytick);
set(gca,'XColor',[0.5 0.5 0.5]);
set(gca,'YColor',[0.5 0.5 0.5]);
set(gca,'LineWidth',0.5);
axis([min(xtick) max(xtick) min(ytick) max(ytick)]);

set(plot3(1),'Linestyle','-','Color',cmap(128,:));
set(plot3(2),'Linestyle',':','Color',cmap(256,:));

legend(plot3, {'Unfiltered Signal','RRC Filtered Signal'}, ...
    'Location','NorthWest','fontSize',6);

figurePath = fullfile(figPath, ['16QAM_EnvvsTime.' figureType]);
print(figure5, '-dpng', '-r300', figurePath);

%% ===================== CONSTELLATION =====================
xtick = -5:2:5;
ytick = -5:2:5;
figureSize = [0.5 0.5 2 2];

figure6 = figure('Name','16QAM Const.', ...
    'Color',[1 1 1], ...
    'Units','inches', ...
    'Position',figureSize, ...
    'PaperPosition',figureSize);

plot(downsample(txFiltSig, sps), 'LineStyle','none', 'Marker','+', ...
    'MarkerSize',1, 'Color',cmap(256,:));
hold on;
plot(dataMod, 'LineStyle','none', 'Marker','*', ...
    'MarkerSize',6, 'Color',cmap(128,:));
hold off;

xlabel('I','fontsize',fontSize,'fontweight','normal','fontname','arial');
ylabel('Q','fontsize',fontSize,'fontweight','normal','fontname','arial');
grid on;
axis square;

set(gca,'units','inches','fontSize',fontSize,'fontWeight','normal','fontName','arial');
set(gca,'gridlinestyle','--');
set(gca,'xtick',xtick);
set(gca,'ytick',ytick);
set(gca,'XColor',[0.5 0.5 0.5]);
set(gca,'YColor',[0.5 0.5 0.5]);
set(gca,'LineWidth',0.5);
axis([min(xtick) max(xtick) min(ytick) max(ytick)]);

figurePath = fullfile(figPath, ['16QAM_Const.' figureType]);
print(figure6, '-dpng', '-r300', figurePath);

%% ===================== SWEEP ROLLOFF FACTOR =====================
filtLenSweep = 12;
rolloffSweep = 0.1:0.01:1.0;
PAPR_filt = zeros(1, length(rolloffSweep));

for b = 1:length(rolloffSweep)
    rrcFilterTmp = rcosdesign(rolloffSweep(b), filtLenSweep, sps);
    zeroPadTmp   = zeros(5*filtLenSweep,1);

    dataModPad = [zeroPadTmp; dataMod; zeroPadTmp];
    txFiltSigTmp = upfirdn(dataModPad, rrcFilterTmp, sps, 1);

    delayTmp = sps*(filtLenSweep/2) + 1 + sps*length(zeroPadTmp);
    startTmp = delayTmp;
    stopTmp  = startTmp + length(dataMod)*sps - 1;

    txFiltSigTmp = 2 * txFiltSigTmp(startTmp:stopTmp);
    sigPower = abs(txFiltSigTmp).^2;
    PAPR_filt(b) = 10*log10(max(sigPower)/mean(sigPower));
end

xtick = 0.1:0.1:1.0;
ytick = 8.25:0.5:11.75;
figureSize = [0.5 0.5 2.5 2];

figure7 = figure('Name','16QAM PAPR vs. RRC', ...
    'Color',[1 1 1], ...
    'Units','inches', ...
    'Position',figureSize, ...
    'PaperPosition',figureSize);

plot4 = plot(rolloffSweep, PAPR_filt+3, 'LineWidth', 1);
xlabel('Rolloff Factor','fontsize',fontSize,'fontweight','normal','fontname','arial');
ylabel('PAPR [dB]','fontsize',fontSize,'fontweight','normal','fontname','arial');
grid on;

set(gca,'units','inches','fontSize',fontSize,'fontWeight','normal','fontName','arial');
set(gca,'gridlinestyle','--');
set(gca,'xtick',xtick);
set(gca,'ytick',ytick);
set(gca,'XColor',[0.5 0.5 0.5]);
set(gca,'YColor',[0.5 0.5 0.5]);
set(gca,'LineWidth',0.5);
axis([min(xtick) max(xtick) min(ytick) max(ytick)]);

set(plot4(1),'Linestyle','-','Color',cmap(256,:));

figurePath = fullfile(figPath, ['16QAM_PAPRvsRolloff.' figureType]);
print(figure7, '-dpng', '-r300', figurePath);

%% ===================== PAPR VS RANDOM SEED =====================
filtLen = 12;
rolloff = 0.35;
rrcFilter = rcosdesign(rolloff, filtLen, sps);

nSeedSym = 1e5;
seed = 1:3000;

PAPR = zeros(1,length(seed));

for idx = 1:length(seed)
    b = seed(idx);
    rng(b, 'twister');

    dataBits    = randi([0 1], nSeedSym*k, 1);
    dataSymbols = bi2de(reshape(dataBits, k, []).', 'left-msb');
    dataModSeed = qammod(dataSymbols, M, 'bin');

    zeroPadSeed = zeros(5*filtLen,1);
    dataModPad  = [zeroPadSeed; dataModSeed; zeroPadSeed];
    txFiltSig   = upfirdn(dataModPad, rrcFilter, sps, 1);

    delay = sps*(filtLen/2) + 1 + sps*length(zeroPadSeed);
    start = delay;
    stop  = start + length(dataModSeed)*sps - 1;
    txFiltSig = 2 * txFiltSig(start:stop);

    sigPower = abs(txFiltSig).^2;
    PAPR(idx) = 10*log10(max(sigPower)/mean(sigPower));
end

PAPRavg = 20*log10(mean(10.^(PAPR/20)));
fprintf('Average PAPR over seeds = %.4f dB\n', PAPRavg);

figure; 
cdfplot(PAPR);
grid on;
title('CDF of PAPR over RNG seed');

%% ===================== PAPR VS SEED PLOT =====================
cmap = flipud(jet(256));
figureSize = [0.5 0.5 3.5 2];
xtick = 0:500:3000;
ytick = 5.5:0.2:6.5;

figure8 = figure('Name','16QAM PAPR vs. Seed', ...
    'Color',[1 1 1], ...
    'Units','inches', ...
    'Position',figureSize, ...
    'PaperPosition',figureSize);

plot5 = plot(seed, PAPR, 'LineWidth', 1);
xlabel('Random Number Generator Seed','fontsize',fontSize,'fontweight','normal','fontname','arial');
ylabel('16-QAM PAPR [dB]','fontsize',fontSize,'fontweight','normal','fontname','arial');
grid on;

set(gca,'units','inches','fontSize',fontSize,'fontWeight','normal','fontName','arial');
set(gca,'gridlinestyle','--');
set(gca,'xtick',xtick);
set(gca,'ytick',ytick);
set(gca,'XColor',[0.5 0.5 0.5]);
set(gca,'YColor',[0.5 0.5 0.5]);
set(gca,'LineWidth',0.5);
axis([min(xtick) max(xtick) min(ytick) max(ytick)]);

set(plot5(1),'Linestyle','-','Color',cmap(256,:));

figurePath = fullfile(figPath, ['16QAM_PAPRvsSeed.' figureType]);
print(figure8, '-dpng', '-r300', figurePath);