% Inverse resampling - The Nearest Neighbour (upsampling)
function [Rt] = inv_resamp_22(R)
% input: matrix R (n x m)
% output: matrix Rt (2n x 2m)

n = size(R, 1); % row count of R
m = size(R, 2); % column count of R
Rt = zeros(2*n, 2*m); % Rt definition = output

for i = 1:n
    for j = 1:m
        Rt(2*i-1:2*i, 2*j-1:2*j) = R(i, j); % copy the value to the current 2x2 submatrix
    end
end
end