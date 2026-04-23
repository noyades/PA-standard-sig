%% ========================= USER SETTINGS =========================
M = 64;
sps = 4;
filtLen = 12;
rolloff = 0.25 ;

alpha = 3;              % shaping strength (>0 favors outer constellation points)
Nsym  = 5e7;            % number of QAM symbols
SNRdB = 50;             % AWGN SNR in dB
ampScale = 2;           % output amplitude scaling

showRxPlots = true;     % set false if RX plots are not needed
numScatterPlot = 1e5;   % number of points to show in scatter plot to avoid heavy plotting
