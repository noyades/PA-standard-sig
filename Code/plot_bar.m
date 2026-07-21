function fig = plot_bar(xIn, yIn, outFilename, varargin)
% PLOT_BARS  Bar plotting for single or multiple traces (grouped if same x).
% See original function for Name-Value options (kept same).

% Parse inputs (same as before)
p = inputParser;
addRequired(p,'xIn');
addRequired(p,'yIn');
addRequired(p,'outFilename',@(s)ischar(s) || isstring(s));
addParameter(p,'Colormap','jet');
addParameter(p,'FlipMap',true,@islogical);
addParameter(p,'NColors',256,@isnumeric);
addParameter(p,'FontSize',8,@isnumeric);
addParameter(p,'FigureName','',@(s)ischar(s)||isstring(s));
addParameter(p,'FigureSize',[0.5 0.5 2.5 2],@(x)isnumeric(x)&&numel(x)==4);
addParameter(p,'XTick',7.5:0.2:9.5);
addParameter(p,'YTick',logspace(-4,0,5));
addParameter(p,'Markers',{{'+','x','o','^','s','d'}});
addParameter(p,'LineWidth',1,@isnumeric);
addParameter(p,'MarkerSize',3,@isnumeric);
addParameter(p,'Legend',{},@iscell);
addParameter(p,'LegendLocation','SouthWest',@(s)ischar(s)||isstring(s));
addParameter(p,'XLabel','S [dB]',@ischar);
addParameter(p,'YLabel','Pr(PAPR<S)',@ischar);
addParameter(p,'Title','',@(s)ischar(s)||isstring(s));
addParameter(p,'Save',true,@islogical);
parse(p,xIn,yIn,outFilename,varargin{:});
opt = p.Results;

% Convert inputs to cell arrays X and Y of equal length (unchanged)
if iscell(xIn) && iscell(yIn)
    X = xIn;
    Y = yIn;
elseif isnumeric(xIn) && iscell(yIn)
    X = repmat({xIn(:)},1,numel(yIn));
    Y = yIn;
elseif isnumeric(xIn) && isnumeric(yIn)
    xv = xIn(:);
    if isvector(yIn)
        X = {xv};
        Y = {yIn(:)};
    else
        n = size(yIn,2);
        X = repmat({xv},1,n);
        Y = arrayfun(@(k) yIn(:,k), 1:n, 'UniformOutput', false);
    end
else
    error('Unsupported combination of xIn and yIn types.');
end

nLines = numel(Y);
if nLines == 0, error('No traces to plot.'); end

% figure name
if isempty(opt.FigureName)
    try [~, baseName] = fileparts(char(opt.outFilename)); if ~isempty(baseName), figName = baseName; else figName = 'Generic Plot'; end
    catch, figName = 'Generic Plot'; end
else
    figName = char(opt.FigureName);
end

% colormap
if ischar(opt.Colormap) || isstring(opt.Colormap)
    cmap = feval(char(opt.Colormap), opt.NColors);
else
    cmap = opt.Colormap;
end
if opt.FlipMap, cmap = flipud(cmap); end
idx = round(linspace(1, size(cmap,1), nLines));
lineColors = cmap(idx,:);

% create figure
fig = figure('Name',figName,'Color',[1 1 1],'Units','inches','Position',opt.FigureSize,'PaperPosition',opt.FigureSize);
ax = axes('Parent',fig); hold(ax,'on');

% Determine plotting strategy
% Check if all X{k} are identical (same length and values)
sameX = true;
refX = X{1}(:);
for k = 2:nLines
    if numel(X{k})~=numel(refX) || any(abs(X{k}(:)-refX) > eps(max(1,abs(refX))))
        sameX = false; break;
    end
end

h = gobjects(nLines,1);
if sameX
    % Build data matrix for grouped bars: rows = x positions, cols = traces
    centers = refX;
    Ymat = zeros(numel(centers), nLines);
    for k = 1:nLines
        Ymat(:,k) = Y{k}(:);
    end
    % Use grouped bar
    hb = bar(ax, centers, Ymat, 'grouped');
    % Apply colors
    for k = 1:numel(hb)
        set(hb(k),'FaceColor',lineColors(k,:), 'EdgeColor','none');
    end
    % return handles for legend (use first bar object per group)
    for k = 1:nLines, h(k) = hb(k); end
else
    % Different x locations: plot bars for each trace with small horizontal offsets
    % Compute global x-range for offset sizing
    allX = cell2mat(cellfun(@(c)c(:), X, 'UniformOutput', false));
    dx = (max(allX)-min(allX))/100; if dx==0, dx = 0.1; end
    offsets = linspace(-0.4, 0.4, nLines) * dx; % offsets proportional to dx
    for k = 1:nLines
        xk = X{k}(:) + offsets(k);
        yk = Y{k}(:);
        % bar handles accept vector x and heights
        htmp = bar(ax, xk, yk, 'FaceColor', lineColors(k,:), 'EdgeColor','none', 'BarWidth', 0.8/nLines);
        h(k) = htmp; % store last created bar object for legend
    end
end

% Labels, title, styling
xlabel(ax,opt.XLabel,'FontSize',opt.FontSize,'FontWeight','normal','FontName','arial');
ylabel(ax,opt.YLabel,'FontSize',opt.FontSize,'FontWeight','normal','FontName','arial');
if ~isempty(opt.Title)
    title(ax,opt.Title,'FontSize',opt.FontSize,'FontWeight','normal','FontName','arial');
end
grid(ax,'on');
set(ax,'Units','inches','FontSize',opt.FontSize,'FontWeight','normal','FontName','arial',...
    'GridLineStyle','--','XTick',opt.XTick,'YTick',opt.YTick, ...
    'XColor',[0.25 0.25 0.25],'YColor',[0.25 0.25 0.25],'LineWidth',0.5);

% Axis limits: expand slightly to fit bars
try
    xl = xlim(ax); yl = ylim(ax);
    % ensure limits cover XTick range if provided
    if ~isempty(opt.XTick), xl = [min(opt.XTick) max(opt.XTick)]; xlim(ax,xl); end
    if ~isempty(opt.YTick), ylim(ax,[min(opt.YTick) max(opt.YTick)]); end
catch
end

% Tidy axis position (robust)
outer = get(ax,'OuterPosition'); ti = get(ax,'TightInset');
newX = outer(1) + ti(1); newY = outer(2) + ti(2);
newW = outer(3) - ti(1) - ti(3); newH = outer(4) - ti(2) - ti(4);
minDim = 0.01; if newW <= 0, newW = minDim; end; if newH <= 0, newH = minDim; end
plotArea = [newX, newY, newW, newH];
set(ax,'Position',plotArea);

% Legend
if ~isempty(opt.Legend)
    legend(h, opt.Legend, 'Location', opt.LegendLocation, 'FontSize', max(6,opt.FontSize-2));
end

% Save
if opt.Save
    [~,~,ext] = fileparts(outFilename);
    if isempty(ext), error('outFilename must include an extension, e.g. ''myfig.png''.'); end
    fmt = ext(2:end);
    print(fig, ['-d' fmt], '-r300', outFilename);
end
end
