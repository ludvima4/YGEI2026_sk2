clc
clear
format long g

% Test files [128x128 px]
files = {'photo.bmp','gradient.bmp','mono.bmp','vector.bmp'};

% Quantisation matrix: Y (
QY50 = [16 11 10 16 24 40 51 61;
    12 12 14 19 26 58 60 55;
    14 13 16 24 40 57 69 56;
    14 17 22 29 51 87 80 62;
    18 22 37 56 68 109 103 77;
    24 35 55 64 81 104 113 92;
    49 64 78 87 103 121 120 101;
    72 92 95 98 112 100 103 99];

% Quantisation matrix: Cb, Cr 
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
    figure('Name', files{f})
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

        % DCT + quantisation (values shifted from 0..255 to -128..127)
        Y_t = mydct(Y - 128, QY);
        Cb_t = mydct(Cb2 - 128, QC);
        Cr_t = mydct(Cr2 - 128, QC);

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

        % IDCT + dequantisation (values shifted back to 0..255)
        Y_2 = myidct(Y_t, QY) + 128;
        Cb_2 = myidct(Cb_t, QC) + 128;
        Cr_2 = myidct(Cr_t, QC) + 128;

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
    fprintf('\nq = %d\n', qs(iq));
    fprintf('%-16s %8s %8s %8s %8s\n', 'file', 'm_R', 'm_G', 'm_B', 'ratio');
    for f = 1:length(files)
        fprintf('%-16s %8.2f %8.2f %8.2f %8.2f\n', files{f}, ...
            RMSE(f, iq, 1), RMSE(f, iq, 2), RMSE(f, iq, 3), CR(f, iq));
    end
end



% DCT transformation
function [Rt] = mydct(R, Q)
    %DCT of entire raster
    [m, n] = size(R);
    Rt  = R;

    %Divide raster to submatrices
    for i = 1:8:m -7
        for j = 1:8:n -7
            %Get submatrix
            R_sub = R(i:i+7, j:j+7);

            %Compute DCT
            R_sub_dct = mydctsub(R_sub);

            %Quantization
            R_sub_quant = R_sub_dct ./ Q;
            R_sub_quant = round(R_sub_quant);

            %Replace submatrix
            Rt(i:i+7, j:j+7) = R_sub_quant;

        end
    end

end

% DCT transformation 8x8
function [Rt] = mydctsub(R)
    % Discrete cosine transformation for a 8 x 8 matrix
    Rt = R;

    %Output raster: rows
    for u = 0:7

        % Set cu
        if u == 0
            cu = sqrt(2)/2;
        else
            cu = 1;
        end

        %Output raster: columns
        for v = 0:7

            % Set cv
            if v == 0
                cv = sqrt(2)/2;
            else
                cv = 1;
            end

            % Reset sum for this (u,v)
            F = 0;

            %Input raster: rows
            for x = 0:7
                %Input raster: columns
                for y = 0:7
                    F = F + 1/4 * cu * cv * R(x+1, y+1) * cos((2*x+1)*u*pi/16) * cos((2*y+1)*v*pi/16);
                end
            end

            % Store DCT coefficient
            Rt(u+1,v+1) = F;

        end
    end
end




% Inverse DCT transformation
function [Rt] = myidct(R, Q)
    %IDCT of entire raster
    [m, n] = size(R);
    Rt  = R;

    %Divide raster to submatrices
    for i = 1:8:m -7
        for j = 1:8:n -7
            %Get submatrix
            R_sub = R(i:i+7, j:j+7);

            %Dequantization
            R_sub_dequant = R_sub .* Q;

            %Inverted DCT
            R_sub_idct = myidctsub(R_sub_dequant);

            %Replace submatrix
            Rt(i:i+7, j:j+7) = R_sub_idct;

        end
    end

end

% Inverse DCT transformation 8x8
function [Rt] = myidctsub(R)
    Rt = zeros(8,8);
    for x = 0:7
        for y = 0:7
            F = 0;
            for u = 0:7
                if u == 0
                    cu = sqrt(2) / 2;
                else
                    cu = 1;
                end
                for v = 0:7
                    if v == 0
                        cv = sqrt(2) / 2;
                    else
                        cv = 1;
                    end
                    F = F + 1/4 * cu * cv * R(u+1,v+1) ...
                        * cos((2*x+1)*u*pi/16) ...
                        * cos((2*y+1)*v*pi/16);
                end
            end
            % Store reconstructed pixel
            Rt(x+1,y+1) = F;
        end
    end
end








