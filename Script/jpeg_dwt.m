clc
clear
format long g

% Test files
files = {'photo.bmp','gradient.bmp','mono.bmp','vector.bmp'};

% Quantisation matrix: Y (base matrix for q = 50)
QY50 = [16 11 10 16 24 40 51 61;
    12 12 14 19 26 58 60 55;
    14 13 16 24 40 57 69 56;
    14 17 22 29 51 87 80 62;
    18 22 37 56 68 109 103 77;
    24 35 55 64 81 104 113 92;
    49 64 78 87 103 121 120 101;
    72 92 95 98 112 100 103 99];

% Quantisation matrix: Cb, Cr (base matrix for q = 50)
QC50 = [17 18 24 47 99 99 99 99;
    18 21 26 66 99 99 99 99;
    24 26 56 99 99 99 99 99;
    47 66 99 99 99 99 99 99;
    99 99 99 99 99 99 99 99;
    99 99 99 99 99 99 99 99;
    99 99 99 99 99 99 99 99;
    99 99 99 99 99 99 99 99];

% Compression factors
qs = [10 50 70];

% Results: RMSE of R, G, B components and compression ratio
RMSE = zeros(length(files), length(qs), 3);
CR = zeros(length(files), length(qs));

% Process each file
for f = 1:length(files)

    % Read file
    raster = imread(files{f});

    % Show image
    figure('Name', [files{f} ' (DWT)'])
    subplot(1, length(qs) + 1, 1)
    imshow(raster)
    title('original')

    % Get components
    if ndims(raster) == 2
        % Grayscale raster: the same values in all components
        R = double(raster);
        G = R;
        B = R;
    else
        R = double(raster(:, :, 1));
        G = double(raster(:, :, 2));
        B = double(raster(:, :, 3));
    end

    % Conversion RGB to YCbCr
    Y = 0.299 * R + 0.587 * G + 0.114 * B;
    Cb = -0.168736 * R - 0.331264 * G + 0.5 * B + 128;
    Cr = 0.5 * R - 0.418688 * G - 0.081312 * B + 128;

    % Resampling: only chrominance components Cb, Cr (4:2:0)
    Cb2 = resamp_22(Cb);
    Cr2 = resamp_22(Cr);

    % Process each compression factor
    for iq = 1:length(qs)
        q = qs(iq);

        % Scaling of quantisation matrices by compression factor
        if q < 50
            S = 50 / q;
        else
            S = 2 - q / 50;
        end
        QY = max(1, round(S * QY50));
        QC = max(1, round(S * QC50));

        % Quantisation matrices for wavelet bands (mean of Q in each band)
        QY = q_bands(QY);
        QC = q_bands(QC);

        % DWT + quantisation (values shifted from 0..255 to -128..127)
        Y_t = mydwt(Y - 128, QY);
        Cb_t = mydwt(Cb2 - 128, QC);
        Cr_t = mydwt(Cr2 - 128, QC);

        % ZIGZAG conversion
        Y_zz = zigzag_blocks(Y_t);
        Cb_zz = zigzag_blocks(Cb_t);
        Cr_zz = zigzag_blocks(Cr_t);

        % Huffman compression
        [Y_compressed, Y_dict] = huffman_compres(Y_zz);
        [Cb_compressed, Cb_dict] = huffman_compres(Cb_zz);
        [Cr_compressed, Cr_dict] = huffman_compres(Cr_zz);

        % Compression ratio (original: 8 bits per pixel and component)
        bits_orig = 8 * 3 * numel(Y);
        bits_comp = length(Y_compressed) + length(Cb_compressed) + length(Cr_compressed);
        CR(f, iq) = bits_orig / bits_comp;

        % Huffman decompression
        Y_zz_dec = huffman_decompress(Y_compressed, Y_dict);
        Cb_zz_dec = huffman_decompress(Cb_compressed, Cb_dict);
        Cr_zz_dec = huffman_decompress(Cr_compressed, Cr_dict);

        % ZIGZAG deconversion
        Y_t = inverse_zigzag_blocks(Y_zz_dec, size(Y_t));
        Cb_t = inverse_zigzag_blocks(Cb_zz_dec, size(Cb_t));
        Cr_t = inverse_zigzag_blocks(Cr_zz_dec, size(Cr_t));

        % IDWT + dequantisation (values shifted back to 0..255)
        Y_2 = myidwt(Y_t, QY) + 128;
        Cb_2 = myidwt(Cb_t, QC) + 128;
        Cr_2 = myidwt(Cr_t, QC) + 128;

        % Inverse resampling of chrominance components Cb, Cr
        Cb_2 = inv_resamp_22(Cb_2);
        Cr_2 = inv_resamp_22(Cr_2);

        % Conversion to RGB
        R2 = Y_2 + 1.402 * (Cr_2 - 128);
        G2 = Y_2 - 0.344136 * (Cb_2 - 128) - 0.714136 * (Cr_2 - 128);
        B2 = Y_2 + 1.772 * (Cb_2 - 128);

        % Assembly raster from RGB components (uint8 rounds and clips to 0..255)
        raster2 = uint8(cat(3, R2, G2, B2));

        % Show raster
        subplot(1, length(qs) + 1, iq + 1)
        imshow(raster2)
        title(sprintf('q = %d', q))

        % Compute error
        RMSE(f, iq, 1) = comp_er(R, double(raster2(:, :, 1)));
        RMSE(f, iq, 2) = comp_er(G, double(raster2(:, :, 2)));
        RMSE(f, iq, 3) = comp_er(B, double(raster2(:, :, 3)));

        % Progress
        fprintf('%s, q = %d done\n', files{f}, q);

    end

end

% Results tables for each compression factor
for iq = 1:length(qs)
    fprintf('\nq = %d (DWT)\n', qs(iq));
    fprintf('%-16s %8s %8s %8s %8s\n', 'file', 'm_R', 'm_G', 'm_B', 'ratio');
    for f = 1:length(files)
        fprintf('%-16s %8.2f %8.2f %8.2f %8.2f\n', files{f}, ...
            RMSE(f, iq, 1), RMSE(f, iq, 2), RMSE(f, iq, 3), CR(f, iq));
    end
end



% Quantisation matrix for wavelet bands
function [Qt] = q_bands(Q)
    % Bands in each axis: LL3 | level 3 | level 2 | level 1 (finest details)
    % Wavelet band positions correspond to DCT frequencies 0 | 1 | 2-3 | 4-7
    bands = {1, 2, 3:4, 5:8};
    Qt = zeros(8, 8);

    for a = 1:4
        for b = 1:4
            % Mean of Q values in the current band
            Q_sub = Q(bands{a}, bands{b});
            Qt(bands{a}, bands{b}) = round(mean(Q_sub(:)));
        end
    end
end

% DWT transformation
function [Rt] = mydwt(R, Q)
    %DWT of entire raster
    [m, n] = size(R);
    Rt  = R;

    %Divide raster to submatrices
    for i = 1:8:m -7
        for j = 1:8:n -7
            %Get submatrix
            R_sub = R(i:i+7, j:j+7);

            %Compute DWT
            R_sub_dwt = mydwtsub(R_sub);

            %Quantization
            R_sub_quant = R_sub_dwt ./ Q;
            R_sub_quant = round(R_sub_quant);

            %Replace submatrix
            Rt(i:i+7, j:j+7) = R_sub_quant;

        end
    end

end

% DWT transformation 8x8
function [Rt] = mydwtsub(R)
    % Haar wavelet transformation for a 8 x 8 matrix (3 levels)
    Rt = R;
    L = 8; % size of the processed top-left submatrix
    s = 1 / sqrt(2);

    while L >= 2
        % Haar matrix L x L: first half of rows = means, second half = differences
        H = zeros(L, L);
        for k = 1:L/2
            H(k, 2*k-1) = s;
            H(k, 2*k) = s;
            H(L/2+k, 2*k-1) = s;
            H(L/2+k, 2*k) = -s;
        end

        % One level on the top-left L x L submatrix (columns, then rows)
        Rt(1:L, 1:L) = H * Rt(1:L, 1:L) * H';

        % Next level only on the LL band
        L = L / 2;
    end
end

% Inverse DWT transformation
function [Rt] = myidwt(R, Q)
    %IDWT of entire raster
    [m, n] = size(R);
    Rt  = R;

    %Divide raster to submatrices
    for i = 1:8:m -7
        for j = 1:8:n -7
            %Get submatrix
            R_sub = R(i:i+7, j:j+7);

            %Dequantization
            R_sub_dequant = R_sub .* Q;

            %Inverted DWT
            R_sub_idwt = myidwtsub(R_sub_dequant);

            %Replace submatrix
            Rt(i:i+7, j:j+7) = R_sub_idwt;

        end
    end

end

% Inverse DWT transformation 8x8
function [Rt] = myidwtsub(R)
    % Inverse Haar wavelet transformation for a 8 x 8 matrix (3 levels)
    Rt = R;
    L = 2; % start with the coarsest level
    s = 1 / sqrt(2);

    while L <= 8
        % Haar matrix L x L (the same as in mydwtsub)
        H = zeros(L, L);
        for k = 1:L/2
            H(k, 2*k-1) = s;
            H(k, 2*k) = s;
            H(L/2+k, 2*k-1) = s;
            H(L/2+k, 2*k) = -s;
        end

        % Inverse of one level (H is orthogonal: inv(H) = H')
        Rt(1:L, 1:L) = H' * Rt(1:L, 1:L) * H;

        % Next finer level
        L = L * 2;
    end
end
