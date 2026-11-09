% Resampling - mean of 2x2 submatrix (downsampling)
function [Rt] = resamp_22(R)
% input: matrix R (n x m)
% output: matrix Rt (n/2 x m/2)

n = size(R, 1) / 2; % row count of Rt
m = size(R, 2) / 2; % column count of Rt
Rt = zeros(n, m); % Rt definition = output

for i = 1:2:n*2
    for j = 1:2:m*2
        cellR = [R(i, j) R(i, j+1); R(i+1, j) R(i+1, j+1)]; % current submatrix
        Rt((i+1)/2, (j+1)/2) = mean(cellR(:)); % adding a mean of the current submatrix to the output matrix
    end
end
end
