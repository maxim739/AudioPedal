function y = distortion(x, amount)
    % amount: 0 = no effect, 1 = heavy clipping
    if nargin < 2, amount = 0.5; end
    threshold = max(1 - amount, 0.01);     % floor avoids total silence
    y = max(min(x, threshold), -threshold);
end