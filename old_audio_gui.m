function audio_gui()
% AUDIO_GUI  File player with compressor, saturation, distortion, wet/dry mix
%            and transport controls.
%
% Requires: DSP System Toolbox (dsp.AudioFileReader), Audio Toolbox (audioDeviceWriter)
% Effects:  compress.m, saturate.m and distortion.m must be on the MATLAB path.
%
% Signal chain (in series):  compressor -> saturation -> distortion -> wet/dry mix
%
% Effect interfaces expected by the GUI:
%   [y, state] = compressFcn(x, sustain, attack, release, ratio, fs, state)
%   y = satFcn(x, amount)       amount in [0, 1]
%   y = distortFcn(x, amount)   amount in [0, 1]

    % ---------- Effects (swap these lines to change an effect) ----------
    compressFcn = @compress;
    satFcn      = @saturate;
    distortFcn  = @distortion;

    % ---------- State ----------
    FRAME      = 1024;     % samples per processing block
    reader     = [];       % file -> stream
    writer     = [];       % stream -> sound card
    playing    = false;
    fs         = 96000;    % updated when a file is loaded
    sat        = 0.0;      % saturation amount, 0 to 1
    distort    = 0.0;      % distortion amount, 0 to 1
    sustainAmt = 0.0;      % compressor sustain, 0 to 1 (0 = bypass)
    attackSec  = 0.005;    % compressor attack, seconds
    releaseSec = 0.2;      % compressor release, seconds
    compRatio  = 4;        % compressor ratio (N:1)
    grState    = 0;        % compressor memory carried between blocks
    mix        = 1.0;      % wet/dry, 0 = fully dry, 1 = fully wet

    % ---------- GUI ----------
    fig = uifigure('Name','AudioSynth','Position',[100 100 460 720], ...
                   'CloseRequestFcn',@onClose);
    g = uigridlayout(fig,[7 2]);
    g.RowHeight   = {32, 22, '1x', '1x', '2x', '1x', 36};
    g.ColumnWidth = {'1x', '4x'};

    loadBtn = uibutton(g,'Text','Select audio file...','ButtonPushedFcn',@onLoad);
    loadBtn.Layout.Row = 1;  loadBtn.Layout.Column = [1 2];

    fileLbl = uilabel(g,'Text','No file loaded','HorizontalAlignment','center');
    fileLbl.Layout.Row = 2;  fileLbl.Layout.Column = [1 2];

    % ---- KNOBS ----
    % ---- Saturation ----
    satKnob = uiknob(g,'continuous','Limits',[0 100],'Value',0, ...
                     'MajorTicks',[0 50 100], ...
                     'ValueChangingFcn',@(~,e) satAmount(e.Value), ...
                     'ValueChangedFcn', @(s,~) satAmount(s.Value));
    satKnob.Layout.Row = 3;  satKnob.Layout.Column = 2;
    satLbl = uilabel(g,'Text','Saturation','HorizontalAlignment','center');
    satLbl.Layout.Row = 3;  satLbl.Layout.Column = 1;

    % ---- Distortion ----
    distortKnob = uiknob(g,'continuous','Limits',[0 100],'Value',0, ...
                     'MajorTicks',[0 50 100], ...
                     'ValueChangingFcn',@(~,e) distortAmount(e.Value), ...
                     'ValueChangedFcn', @(s,~) distortAmount(s.Value));
    distortKnob.Layout.Row = 4;  distortKnob.Layout.Column = 2;
    distortLbl = uilabel(g,'Text','Distortion','HorizontalAlignment','center');
    distortLbl.Layout.Row = 4;  distortLbl.Layout.Column = 1;

    % ---- Compressor (panel with four knobs) ----
    compPanel = uipanel(g,'Title','Compressor');
    compPanel.Layout.Row = 5;  compPanel.Layout.Column = [1 2];
    cg = uigridlayout(compPanel,[2 4]);
    cg.RowHeight = {'1x', 22};

    sustainKnob = uiknob(cg,'continuous','Limits',[0 100],'Value',0, ...
                     'MajorTicks',[0 100], ...
                     'ValueChangingFcn',@(~,e) sustainAmount(e.Value), ...
                     'ValueChangedFcn', @(s,~) sustainAmount(s.Value));
    sustainKnob.Layout.Row = 1;  sustainKnob.Layout.Column = 1;
    sustainLbl = uilabel(cg,'Text','Sustain','HorizontalAlignment','center');
    sustainLbl.Layout.Row = 2;  sustainLbl.Layout.Column = 1;

    attackKnob = uiknob(cg,'continuous','Limits',[1 100],'Value',5, ...
                     'MajorTicks',[1 100], ...
                     'ValueChangingFcn',@(~,e) attackAmount(e.Value), ...
                     'ValueChangedFcn', @(s,~) attackAmount(s.Value));
    attackKnob.Layout.Row = 1;  attackKnob.Layout.Column = 2;
    attackLbl = uilabel(cg,'Text','Attack (ms)','HorizontalAlignment','center');
    attackLbl.Layout.Row = 2;  attackLbl.Layout.Column = 2;

    releaseKnob = uiknob(cg,'continuous','Limits',[20 1000],'Value',200, ...
                     'MajorTicks',[20 1000], ...
                     'ValueChangingFcn',@(~,e) releaseAmount(e.Value), ...
                     'ValueChangedFcn', @(s,~) releaseAmount(s.Value));
    releaseKnob.Layout.Row = 1;  releaseKnob.Layout.Column = 3;
    releaseLbl = uilabel(cg,'Text','Release (ms)','HorizontalAlignment','center');
    releaseLbl.Layout.Row = 2;  releaseLbl.Layout.Column = 3;

    ratioKnob = uiknob(cg,'continuous','Limits',[1 20],'Value',4, ...
                     'MajorTicks',[1 10 20], ...
                     'ValueChangingFcn',@(~,e) ratioAmount(e.Value), ...
                     'ValueChangedFcn', @(s,~) ratioAmount(s.Value));
    ratioKnob.Layout.Row = 1;  ratioKnob.Layout.Column = 4;
    ratioLbl = uilabel(cg,'Text','Ratio','HorizontalAlignment','center');
    ratioLbl.Layout.Row = 2;  ratioLbl.Layout.Column = 4;

    % ---- WET/DRY ----
    mixKnob = uiknob(g,'continuous','Limits',[0 100],'Value',100, ...
                     'MajorTicks',[0 50 100],'MajorTickLabels',{'Dry','50','Wet'}, ...
                     'ValueChangingFcn',@(~,e) mixAmount(e.Value), ...
                     'ValueChangedFcn', @(s,~) mixAmount(s.Value));
    mixKnob.Layout.Row = 6;  mixKnob.Layout.Column = 2;
    mixLbl = uilabel(g,'Text','Wet / Dry','HorizontalAlignment','center');
    mixLbl.Layout.Row = 6;  mixLbl.Layout.Column = 1;

    % ---- BUTTONS ----
    btnPanel = uigridlayout(g,[1 3],'Padding',[0 0 0 0]);
    btnPanel.Layout.Row = 7;  btnPanel.Layout.Column = [1 2];
    uibutton(btnPanel,'Text','Play',           'ButtonPushedFcn',@onPlay);
    uibutton(btnPanel,'Text','Pause',          'ButtonPushedFcn',@onPause);
    uibutton(btnPanel,'Text','From beginning', 'ButtonPushedFcn',@onRestart);

    % ---------- Callbacks ----------
    function satAmount(v)
        sat = v/100;
    end
    function distortAmount(v)
        distort = v/100;
    end
    function sustainAmount(v)
        sustainAmt = v/100;
    end
    function attackAmount(v)
        attackSec = v/1000;          % knob is in ms
    end
    function releaseAmount(v)
        releaseSec = v/1000;         % knob is in ms
    end
    function ratioAmount(v)
        compRatio = v;
    end
    function mixAmount(v)
        mix = v/100;
    end

    function onLoad(~,~)
        playing = false;                       % stop any running loop
        [f,p] = uigetfile({'*.wav;*.flac;*.mp3;*.m4a','Audio files'});
        if isequal(f,0), return; end
        releaseAudio();
        reader = dsp.AudioFileReader(fullfile(p,f),'SamplesPerFrame',FRAME);
        writer = audioDeviceWriter('SampleRate',reader.SampleRate);
        fs = reader.SampleRate;
        grState = 0;                           % fresh compressor memory
        fileLbl.Text = sprintf('%s  (%g kHz)', f, fs/1000);
    end

    function onPlay(~,~)
        if isempty(reader) || playing, return; end
        playing = true;
        while playing && isvalid(fig)
            if isDone(reader)                  % reached end of file
                reset(reader);
                grState = 0;
                playing = false;
                break
            end
            x = reader();

            % Effect chain, in series: compressor -> saturation -> distortion
            w = x;
            [w, grState] = compressFcn(w, sustainAmt, attackSec, releaseSec, ...
                                       compRatio, fs, grState);
            w = satFcn(w, sat);
            w = distortFcn(w, distort);

            nUnderrun = writer((1-mix)*x + mix*w);     % blocks at the audio rate
            if nUnderrun > 0
                fprintf('underrun: %d samples\n', nUnderrun);
            end
            drawnow limitrate;                 % lets knobs/buttons be serviced
        end
    end

    function onPause(~,~)
        playing = false;
    end

    function onRestart(~,~)
        if isempty(reader), return; end
        reset(reader);
        grState = 0;
        onPlay();                              % no-op if already playing
    end

    function onClose(~,~)
        playing = false;
        releaseAudio();
        delete(fig);
    end

    function releaseAudio()
        if ~isempty(reader), release(reader); end
        if ~isempty(writer), release(writer); end
    end
end