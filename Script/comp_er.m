% Root mean square error
function [E] = comp_er(c1, c2) % c as component
[m,n] = size(c1);

% Difference between before and after compression
dc = c2 - c1;

% Squares of differences
dc2 = dc .^ 2;

% Root mean square error
E = sqrt(sum(sum(dc2)) / (m*n));
end