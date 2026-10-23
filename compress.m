function [y, gr_state] = compress(x, sustain, attack, release, ratio, fs, gr_state)
% COMPRESS  Feed-forward dynamic range compressor, guitar-pedal style.
%
%   y = compress(x, sustain, attack, release, ratio)
%   [y, gr_state] = compress(x, sustain, attack, release, ratio, fs, gr_state)
%
%   x        signal, N-by-C (columns are channels), normalized to [-1, 1]
%   sustain  0 to 1. 0 = bypass. Higher = lower threshold plus more makeup
%            gain, so quiet passages and note tails are lifted more.
%   attack   seconds, how fast gain reduction clamps down (e.g. 0.005)
%   release  seconds, how fast gain recovers (e.g. 0.2)
%   ratio    1 or more, e.g. 4 means 4:1 above the threshold
%   fs       sample rate in Hz (optional, default 96000)
%   gr_state gain-reduction memory from the previous block (optional).
%            Pass the second output back in on the next block when
%            streaming, so the attack/release smoothing carries across
%            block boundaries. Omit it when processing a whole file at once.

    if nargin < 6 || isempty(fs),       fs = 96000; end
    if nargin < 7 || isempty(gr_state), gr_state = 0; end

    sustain = min(max(sustain, 0), 1);
    ratio   = max(ratio, 1);

    % --- Threshold and makeup gain from the sustain control ---
    % sustain 0 -> threshold 0 dBFS (never triggers), sustain 1 -> -40 dBFS.
    % Makeup gain is set so a full-scale input still comes out at full scale.
    T      = -40 * sustain;              % threshold in dBFS
    makeup = -T * (1 - 1/ratio);         % dB

    % --- Level detector (peak across channels, so stereo stays linked) ---
    peak    = max(abs(x), [], 2);                    % N-by-1
    levelDb = 20*log10(max(peak, 1e-6));             % floor avoids log10(0)

    % --- Gain computer: how many dB of reduction the signal calls for ---
    target = max(levelDb - T, 0) * (1 - 1/ratio);    % N-by-1, in dB

    % --- Attack/release smoothing of the gain reduction ---
    aA = exp(-1 / (max(attack,  1e-6) * fs));        % attack coefficient
    aR = exp(-1 / (max(release, 1e-6) * fs));        % release coefficient

    N  = size(x, 1);
    gr = zeros(N, 1);
    g  = gr_state;
    for n = 1:N
        if target(n) > g
            c = aA;                                  % more reduction needed: attack
        else
            c = aR;                                  % less needed: release
        end
        g = c*g + (1 - c)*target(n);
        gr(n) = g;
    end
    gr_state = g;

    % --- Apply gain ---
    gain = 10.^((makeup - gr) / 20);                 % linear
    y = x .* gain;                                   % same gain on every channel
end