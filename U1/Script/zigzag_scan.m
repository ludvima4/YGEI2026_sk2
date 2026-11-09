% ZIGZAG scanning ... for 8x8 DCT block
function [V] = zigzag_scan(R)
% input: matrix R
% output: vector V

n = size(R,1); % row count
m = size(R,2); % colunm count
V = zeros(1, n*m); % output definition
k = 1; % position index in output vector
for s = 2:n+m % goes through each diagonal indexes
    if mod(s,2) == 0 % if diagonal index is even
        for i = min(n, s-1):-1:max(1, s-m) % moves upwards and to the right
            j = s - i; % column index

            V(k) = R(i, j); % paste the (i,j) index from input to (k) place in output
            k = k+1; % move to the next position index in output
        end
    else % if diagonal index is odd
        for i = max(1, s-m):min(n, s-1) % moves downwards and to the left
            j = s - i; % column index

            V(k) = R(i, j); % paste the (i,j) index from input to (k) place in output
            k = k+1; % move to the next position index in output
        end
    end
end
end