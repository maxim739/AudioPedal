function y = hard_saturate(x, amount)
    % amount: 0 = no effect, 1 = heavy clipping
    % At amount = 0.5 the clip threshold is 0.5 (same as before)
    if nargin < 2, amount = 0.5; end
    threshold = max(1 - amount, 0.01);     % floor avoids total silence
    y = max(min(x, threshold), -threshold);
end