function spec = spectrum_view(parent, fs, varargin)
% SPECTRUM_VIEW  Live input/output spectrum display for a UI container.
%
%   spec = spectrum_view(parent, fs)
%   spec = spectrum_view(parent, fs, 'FFTSize',8192, 'UpdateEvery',3, ...
%                        'Smoothing',0.5, 'YLim',[-100 0])
%
%   parent   a uigridlayout (or other uifigure container) to draw the axes in
%   fs       sample rate in Hz
%
% Returns a struct with:
%   spec.axes          the uiaxes, so the caller can set its Layout
%   spec.reset(fs)     rebuild the frequency axis and clear the display
%                      (call when a new file / sample rate is loaded)
%   spec.update(x, out) feed one block of input x and output out
%                      (N-by-C arrays); redraws every UpdateEvery calls
%
% This code never calls drawnow. The caller's loop owns the event queue.
%
% Options:
%   FFTSize      FFT length; bin width is fs/FFTSize        (default 8192)
%   UpdateEvery  redraw once per this many update() calls   (default 3)
%   Smoothing    0 = none, closer to 1 = slower trace       (default 0.5)
%   YLim         level axis limits in dBFS                  (default [-100 0])

    p = inputParser;
    addParameter(p, 'FFTSize',     8192);
    addParameter(p, 'UpdateEvery', 3);
    addParameter(p, 'Smoothing',   0.5);
    addParameter(p, 'YLim',        [-100 0]);
    parse(p, varargin{:});
    specN       = p.Results.FFTSize;
    updateEvery = p.Results.UpdateEvery;
    alpha       = p.Results.Smoothing;
    yLim        = p.Results.YLim;

    % ---------- State ----------
    win        = 0.5 - 0.5*cos(2*pi*(0:specN-1)'/(specN-1));   % Hann window
    winGain    = sum(win)/2;   % scales FFT so a full-scale sine reads 0 dBFS
    freq       = [];           % frequency of each plotted bin
    inBuf      = [];           % rolling buffers of the last specN samples
    outBuf     = [];
    inDb       = [];           % smoothed spectra in dBFS
    outDb      = [];
    blockCount = 0;

    % ---------- Plot ----------
    ax = uiaxes(parent);
    ax.XScale = 'log';
    ax.YLim   = yLim;
    ax.Box    = 'on';
    grid(ax, 'on');
    title(ax,  'Live spectrum');
    xlabel(ax, 'Frequency (Hz)');
    ylabel(ax, 'Level (dBFS)');
    hold(ax, 'on');
    inLine  = plot(ax, nan, nan, 'Color', [0.6 0.6 0.6],    'LineWidth', 1);
    outLine = plot(ax, nan, nan, 'Color', [0.85 0.33 0.10], 'LineWidth', 1.2);
    legend(ax, [inLine outLine], {'Input (dry)', 'Output'}, 'Location', 'northeast');
    resetView(fs);

    % ---------- Public interface ----------
    spec.axes   = ax;
    spec.reset  = @resetView;
    spec.update = @updateView;

    % ---------- Implementation ----------
    function updateView(x, out)
        if ~isvalid(ax), return; end             % window already closed
        inBuf  = pushBlock(inBuf,  mean(x,   2)); % stereo averaged to mono
        outBuf = pushBlock(outBuf, mean(out, 2));
        blockCount = blockCount + 1;
        if mod(blockCount, updateEvery) ~= 0, return; end
        inDb  = alpha*inDb  + (1-alpha)*spectrumDb(inBuf);
        outDb = alpha*outDb + (1-alpha)*spectrumDb(outBuf);
        set(inLine,  'YData', inDb);
        set(outLine, 'YData', outDb);
    end

    function resetView(newFs)
        if nargin > 0, fs = newFs; end
        freq   = (1:specN/2)' * fs/specN;        % skip the DC bin (log axis)
        inBuf  = zeros(specN, 1);
        outBuf = zeros(specN, 1);
        inDb   = -120*ones(specN/2, 1);
        outDb  = inDb;
        blockCount = 0;
        set(inLine,  'XData', freq, 'YData', inDb);
        set(outLine, 'XData', freq, 'YData', outDb);
        ax.XLim = [20 fs/2];
    end

    function buf = pushBlock(buf, blk)
        n = numel(blk);
        if n >= specN
            buf = blk(end-specN+1:end);          % block longer than the buffer
        else
            buf = [buf(n+1:end); blk];           % drop oldest, append newest
        end
    end

    function db = spectrumDb(buf)
        X  = abs(fft(buf .* win));
        X  = X(2:specN/2+1) / winGain;           % amplitude: full-scale sine = 1
        db = 20*log10(max(X, 1e-6));             % floor at -120 dB
    end
end