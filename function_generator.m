function [y, phase] = function_generator(type, freq, amp, n, fs, phase)
% FUNCTION_GENERATOR  Block-based sine / saw / square oscillator.
%
%   y = function_generator(type, freq, amp, n, fs)
%   [y, phase] = function_generator(type, freq, amp, n, fs, phase)
%
%   type   'sine', 'saw' or 'square' (case-insensitive)
%   freq   frequency in Hz
%   amp    amplitude, 0 (silent) to 1 (full scale). Either a scalar, or a
%          two-element vector [a0 a1] that ramps linearly across the block
%          (use [previousAmp newAmp] to avoid clicks when a knob moves).
%   n      number of samples to generate
%   fs     sample rate in Hz
%   phase  starting phase in cycles, 0 to 1 (optional, default 0)
%
%   y      n-by-1 column vector
%   phase  phase after the last sample. Pass it back in for the next block
%          so the waveform stays continuous across block boundaries.
%
% Saw and square use PolyBLEP correction at their jumps, which removes most
% of the aliasing a naive saw/square would show at high frequencies.

    if nargin < 6 || isempty(phase), phase = 0; end

    freq = min(max(freq, 0), fs/2);          % keep below Nyquist
    amp  = min(max(amp, 0), 1);
    dt   = freq / fs;                        % phase increment per sample (cycles)

    t     = mod(phase + dt*(0:n-1)', 1);     % phase of every sample, in [0, 1)
    phase = mod(phase + dt*n, 1);            % where the next block picks up

    switch lower(type)
        case 'sine'
            y = sin(2*pi*t);
        case 'saw'
            y = 2*t - 1 - polyblep(t, dt);
        case 'square'
            y = (2*(t < 0.5) - 1) + polyblep(t, dt) - polyblep(mod(t + 0.5, 1), dt);
        otherwise
            error('function_generator:badType', ...
                  'Unknown waveform "%s". Use sine, saw or square.', type);
    end

    if isscalar(amp)
        y = amp * y;
    else
        y = linspace(amp(1), amp(2), n)' .* y;   % ramp gain across the block
    end
end

function y = polyblep(t, dt)
% Polynomial band-limited step correction around the jump at t = 0 / 1.
    y = zeros(size(t));
    i = t < dt;                              % just after the jump
    x = t(i) / dt;
    y(i) = x + x - x.*x - 1;
    j = t > 1 - dt;                          % just before the jump
    x = (t(j) - 1) / dt;
    y(j) = x.*x + x + x + 1;
end