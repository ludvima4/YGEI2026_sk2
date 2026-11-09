function Rt = inverse_zigzag_blocks(V, original_size)
% Return a decoded sequence to its original 8x8 quantized-DCT block layout.
n = original_size(1);
m = original_size(2);
Rt = zeros(n, m);

% The index map uses the ORIGINAL zigzag_scan; no new scan order is needed.
zigzag_indices = zigzag_scan(reshape(1:64, 8, 8));
k = 1;
for i = 1:8:n
    for j = 1:8:m
        block = zeros(8, 8);
        block(zigzag_indices) = V(k:k+63);
        Rt(i:i+7, j:j+7) = block;
        k = k + 64;
    end
end
end