function V = zigzag_blocks(R)
% Call the zigzag_scan on each 8x8 block
[n, m] = size(R);
V = zeros(n*m, 1);
k = 1;
for i = 1:8:n
    for j = 1:8:m
        block_vector = zigzag_scan(R(i:i+7, j:j+7));
        V(k:k+63) = block_vector(:);
        k = k + 64;
    end
end
end