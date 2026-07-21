function fig = plot_generic(xIn, yIn, outFilename, varargin)
% PLOT_GENERIC  
%
% Syntax:
%   fig = plot_generic(xIn, yIn, outFilename, Name,Value,...)
%
% Inputs:
%   xIn        - common x vector, or cell array of x vectors (1xN)
%   yIn        - MxN matrix (columns are traces), or cell array of y vectors (1xN)
%   outFilename- string: file name or full path (include extension, e.g. 'myfig.png')
%
% Name-Value pairs (most useful / defaults):
%   'LogX'          - If true it will plot on a semilog X axis
%   'LogY'          - If true it will plot on a semilog Y axis
%   'Colormap'      - colormap name or Kx3 matrix (default 'jet')
%   'FlipMap'       - logical (default true)
%   'NColors'       - scalar (default 256)
%   'FontSize'      - scalar (default 8)
%   'FigureSize'    - [left bottom width height] in inches (default [0.5 0.5 2.5 2])
%   'XTick'         - vector (default 7.5:0.2:9.5)
%   'YTick'         - vector (default logspace(-4,0,5))
%   'Markers'       - cell array of markers (default {'+','x','o','^','s','d'})
%   'LineWidth'     - scalar (default 1)
%   'MarkerSize'    - scalar (default 3)
%   'Legend'        - cell array of labels (default {})
%   'LegendLocation'- string (default 'SouthWest')
%   'XLabel'        - string (default 'S [dB]')
%   'YLabel'        - string (default 'Pr(PAPR<S)')
%   'Title'         - string or '' (default '')
%   'Save'          - logical (default true)
%
% Returns:
%   fig - figure handle

% Parse inputs
p = inputParser;
addRequired(p,'xIn');
addRequired(p,'yIn');
addRequired(p,'outFilename',@(s)ischar(s) || isstring(s));
addParameter(p,'LogY',false,@islogical);
addParameter(p,'LogX',false,@islogical);
addParameter(p,'Colormap','jet');
addParameter(p,'FlipMap',true,@islogical);
addParameter(p,'NColors',256,@isnumeric);
addParameter(p,'FontSize',8,@isnumeric);
addParameter(p,'FigureName','',@(s)ischar(s)||isstring(s));
addParameter(p,'FigureSize',[0.5 0.5 2.5 2],@(x)isnumeric(x)&&numel(x)==4);
addParameter(p,'XTick',7.5:0.2:9.5);
addParameter(p,'YTick',logspace(-4,0,5));
addParameter(p,'Markers',{'+','x','o','^','s','d'});
addParameter(p,'Linestyle',{'-' ,'--' ,'-.',':' ,'none'});
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

% Convert inputs to cell arrays X and Y of equal length
if iscell(xIn) && iscell(yIn)
    X = xIn;
    Y = yIn;
elseif isnumeric(xIn) && iscell(yIn)
    % xIn should be a single common x vector; require vector shape
    if isvector(xIn)
        X = repmat({xIn(:)}, 1, numel(yIn));
    else
        error('When yIn is cell and xIn is numeric, xIn must be a vector.');
    end
    Y = yIn;
elseif isnumeric(xIn) && isnumeric(yIn)
    if isvector(yIn)
        % single trace: ensure x and y lengths match
        X = {xIn(:)};
        Y = {yIn(:)};
    else
        n = size(yIn,2);
        % If xIn is a vector -> common x for all columns of yIn
        if isvector(xIn)
            X = repmat({xIn(:)}, 1, n);
        else
            % xIn is a matrix: require same number of columns as yIn,
            % and split into 1-by-n cell array of column vectors
            if size(xIn,2) ~= n
                error('When xIn is a matrix, it must have the same number of columns as yIn.');
            end
            X = mat2cell(xIn, size(xIn,1), ones(1,n));  % 1-by-n cells
        end
        % Split yIn into 1-by-n cells (columns)
        Y = mat2cell(yIn, size(yIn,1), ones(1,n));      % 1-by-n cells
    end
else
    error('Unsupported combination of xIn and yIn types.');
end

% Ensure column vectors inside every cell and 1-by-n shape
X = cellfun(@(c) c(:), X, 'UniformOutput', false);
Y = cellfun(@(c) c(:), Y, 'UniformOutput', false);

nLines = numel(Y);
if nLines == 0
    error('No traces to plot.');
end

% determine default figure name if not provided
if isempty(opt.FigureName)
    try
        [~, baseName] = fileparts(char(opt.outFilename));
        if ~isempty(baseName)
            figName = baseName;
        else
            figName = 'Generic Plot';
        end
    catch
        figName = 'Generic Plot';
    end
else
    figName = char(opt.FigureName);
end

% Prepare colormap
if ischar(opt.Colormap) || isstring(opt.Colormap)
    cmap = feval(char(opt.Colormap), opt.NColors);
else
    cmap = opt.Colormap;
end
if opt.FlipMap, cmap = flipud(cmap); end
idx = round(linspace(1, size(cmap,1), nLines));
lineColors = cmap(idx,:);

% Normalize linestyles -> 1-by-M cell array of strings
if iscell(opt.Linestyle)        % note: keep same name used in addParameter
    linestyles = opt.Linestyle(:).';
elseif isstring(opt.Linestyle)
    linestyles = cellstr(opt.Linestyle).';
elseif ischar(opt.Linestyle)
    linestyles = {opt.Linestyle};
else
    error('Linestyle must be a cell array, string array, or char.');
end
nStyles = numel(linestyles);

% Prepare markers
% Normalize markers to 1-by-M cell array
if iscell(opt.Markers)
    markers = opt.Markers(:).';
elseif isstring(opt.Markers)
    markers = cellstr(opt.Markers).';
elseif ischar(opt.Markers)
    markers = {opt.Markers};
else
    error('Markers must be a cell array, string array, or char.');
end
% markers = opt.Markers{:};
nMarkers = numel(markers);

% Create figure
fig = figure('Name',figName,...
             'Color',[1 1 1],...
             'Units','inches', ...
             'Position',opt.FigureSize,...
             'PaperPosition',opt.FigureSize, ...
             'defaultaxescolororder',cmap);

ax = gca;
if opt.LogY, ax.YScale = 'log'; else ax.YScale = 'linear'; end
if opt.LogX, ax.XScale = 'log'; else ax.XScale = 'linear'; end

hold on
h = gobjects(nLines,1);
for k = 1:nLines
    ls = linestyles{ mod(k-1, nStyles) + 1 };
    xk = X{k}(:);
    yk = Y{k}(:);
    if numel(xk) ~= numel(yk)
        error('Length mismatch between X{%d} and Y{%d}.', k, k);
    end
    if opt.LogY || opt.LogX
        if opt.LogY && ~opt.LogX
            h(k) = semilogy(xk, yk, 'Color', lineColors(k,:), ...
                'LineWidth', opt.LineWidth, ...
                'Marker', markers{mod(k-1,nMarkers)+1}, ...
                'MarkerSize', opt.MarkerSize, ...
                'LineStyle',ls);
        elseif opt.LogX && ~opt.LogY
            h(k) = semilogx(xk, yk, 'Color', lineColors(k,:), ...
                'LineWidth', opt.LineWidth, ...
                'Marker', markers{mod(k-1,nMarkers)+1}, ...
                'MarkerSize', opt.MarkerSize, ...
                'LineStyle',ls);
        else %opt.LogX && opt.LogY
            h(k) = loglog(xk, yk, 'Color', lineColors(k,:), ...
                'LineWidth', opt.LineWidth, ...
                'Marker', markers{mod(k-1,nMarkers)+1}, ...
                'MarkerSize', opt.MarkerSize, ...
                'LineStyle',ls);
        end
    else % Linear Plot
        h(k) = plot(xk, yk, 'Color', lineColors(k,:), ...
            'LineWidth', opt.LineWidth, ...
            'Marker', markers{mod(k-1,nMarkers)+1}, ...
            'MarkerSize', opt.MarkerSize, ...
            'LineStyle',ls);
    end
end
hold off

% Axes labels, title, styling
xlabel(opt.XLabel,'FontSize',opt.FontSize,'FontWeight','normal','FontName','arial');
ylabel(opt.YLabel,'FontSize',opt.FontSize,'FontWeight','normal','FontName','arial');
if ~isempty(opt.Title)
    title(opt.Title,'FontSize',opt.FontSize,'FontWeight','normal','FontName','arial');
end
grid on
ax = gca;
set(ax,'Units','inches','FontSize',opt.FontSize,'FontWeight','normal','FontName','arial',...
    'GridLineStyle','--','XTick',opt.XTick,'YTick',opt.YTick, ...
    'XColor',[0.25 0.25 0.25],'YColor',[0.25 0.25 0.25],'LineWidth',0.5);
axis([min(opt.XTick) max(opt.XTick) min(opt.YTick) max(opt.YTick)]);

% Tidy axis position
% Get outer position and tight inset
outer = get(ax,'OuterPosition');   % [x y w h]
ti    = get(ax,'TightInset');      % [left bottom right top]

% Compute new position so axes fit inside the figure taking tight inset into account
newX = outer(1) + ti(1);
newY = outer(2) + ti(2);
newW = outer(3) - ti(1) - ti(3);
newH = outer(4) - ti(2) - ti(4);

% Prevent invalid sizes (minimum small positive values)
minDim = 0.01;
if newW <= 0, newW = minDim; end
if newH <= 0, newH = minDim; end

plotArea = [newX, newY, newW, newH];
set(ax,'Position',plotArea);

% Legend
if ~isempty(opt.Legend)
    legend(h, opt.Legend, 'Location', opt.LegendLocation, 'FontSize', max(6,opt.FontSize-2));
end

% Save
if opt.Save
    [~,~,ext] = fileparts(outFilename);
    if isempty(ext)
        error('outFilename must include an extension, e.g. ''myfig.png''.');
    end
    % Print with format derived from extension (without dot)
    fmt = ext(2:end);
    print(fig, ['-d' fmt], '-r300', outFilename);
end
end
