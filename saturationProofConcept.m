% --- Import ---
[x, fs] = audioread('greed.wav');   % x = samples (Nx1 or Nx2), fs = 96000

% --- Saturate at 50% of full scale ---
threshold = 0.5;                       % 50% of max amplitude (assuming normalized -1 to 1)
y = x;
y(y > threshold)  = threshold;
y(y < -threshold) = -threshold;

% --- Optional: renormalize so output isn't just quieter ---
% y = y / threshold;

% --- Listen / inspect ---
sound(y, fs);

% --- Plot before/after ---
t = (0:length(x)-1)/fs;
figure;
subplot(2,1,1); plot(t, x); title('Original'); ylim([-1 1]);
subplot(2,1,2); plot(t, y); title('Saturated at 50%'); ylim([-1 1]);
xlabel('Time (s)');

% --- Save result ---
audiowrite('saturated_output.wav', y, fs);