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

%Results: RMSE of R, G, B components and compression ratio
RMSE = zeros(length(files), length(qs), 3);
CR = zeros(length(files), length(qs));

% Process each file
for f = 1:length(files)

    % Read file
    raster = imread(files{f});

    % Show image
    figure('Name', [files{f} ' (DFT)'])
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

        % Reordering of quantisation matrices by DFT frequencies
        % DFT index 0 1 2 3 4 5 6 7 -> frequency 0 1 2 3 4 3 2 1 -> DCT index 0 2 4 6 7 6 4 2
        d = [1 3 5 7 8 7 5 3];
        QY = QY(d, d);
        QC = QC(d, d);

        % DFT + quantisation (values shifted from 0..255 to -128..127)
        Y_t = mydft(Y - 128, QY);
        Cb_t = mydft(Cb2 - 128, QC);
        Cr_t = mydft(Cr2 - 128, QC);

        % ZIGZAG conversion (real part and imaginary part one after another)
        Y_zz = [zigzag_blocks(real(Y_t)); zigzag_blocks(imag(Y_t))];
        Cb_zz = [zigzag_blocks(real(Cb_t)); zigzag_blocks(imag(Cb_t))];
        Cr_zz = [zigzag_blocks(real(Cr_t)); zigzag_blocks(imag(Cr_t))];

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

        % ZIGZAG deconversion (first half = real part, second half = imaginary part)
        Y_t = inverse_zigzag_blocks(Y_zz_dec(1:end/2), size(Y_t)) ...
            + 1i * inverse_zigzag_blocks(Y_zz_dec(end/2+1:end), size(Y_t));
        Cb_t = inverse_zigzag_blocks(Cb_zz_dec(1:end/2), size(Cb_t)) ...
            + 1i * inverse_zigzag_blocks(Cb_zz_dec(end/2+1:end), size(Cb_t));
        Cr_t = inverse_zigzag_blocks(Cr_zz_dec(1:end/2), size(Cr_t)) ...
            + 1i * inverse_zigzag_blocks(Cr_zz_dec(end/2+1:end), size(Cr_t));

        % IDFT + dequantisation (values shifted back to 0..255)
        Y_2 = myidft(Y_t, QY) + 128;
        Cb_2 = myidft(Cb_t, QC) + 128;
        Cr_2 = myidft(Cr_t, QC) + 128;

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
    fprintf('\nq = %d (DFT)\n', qs(iq));
    fprintf('%-16s %8s %8s %8s %8s\n', 'file', 'm_R', 'm_G', 'm_B', 'ratio');
    for f = 1:length(files)
        fprintf('%-16s %8.2f %8.2f %8.2f %8.2f\n', files{f}, ...
            RMSE(f, iq, 1), RMSE(f, iq, 2), RMSE(f, iq, 3), CR(f, iq));
    end
end



% DFT transformation
function [Rt] = mydft(R, Q)
    %DFT of entire raster
    [m, n] = size(R);
    Rt = complex(zeros(m, n));

    %Divide raster to submatrices
    for i = 1:8:m -7
        for j = 1:8:n -7
            %Get submatrix
            R_sub = R(i:i+7, j:j+7);

            %Compute DFT
            R_sub_dft = mydftsub(R_sub);

            %Enforce conjugate symmetry F(8-u, 8-v) = conj(F(u, v))
            %(identical values bit by bit, so rounding cannot break the symmetry)
            r = mod(8 - (0:7), 8) + 1;
            R_sub_dft = (R_sub_dft + conj(R_sub_dft(r, r))) / 2;

            %Quantization of real and imaginary part separately
            R_sub_quant = complex(round(real(R_sub_dft) ./ Q), round(imag(R_sub_dft) ./ Q));

            %Replace submatrix
            Rt(i:i+7, j:j+7) = R_sub_quant;

        end
    end

end

% DFT transformation 8x8
function [Rt] = mydftsub(R)
    % Discrete Fourier transformation for a 8 x 8 matrix (normalised by 1/8)
    Rt = complex(zeros(8, 8));

    %Output raster: rows
    for u = 0:7
        %Output raster: columns
        for v = 0:7

            % Reset sum for this (u,v)
            F = 0;

            %Input raster: rows
            for x = 0:7
                %Input raster: columns
                for y = 0:7
                    F = F + 1/8 * R(x+1, y+1) * exp(-2i*pi*(u*x + v*y)/8);
                end
            end

            % Store DFT coefficient
            Rt(u+1,v+1) = F;

        end
    end
end

% Inverse DFT transformation
function [Rt] = myidft(R, Q)
    %IDFT of entire raster
    [m, n] = size(R);
    Rt = zeros(m, n);

    %Divide raster to submatrices
    for i = 1:8:m -7
        for j = 1:8:n -7
            %Get submatrix
            R_sub = R(i:i+7, j:j+7);

            %Dequantization
            R_sub_dequant = R_sub .* Q;

            %Inverted DFT
            R_sub_idft = myidftsub(R_sub_dequant);

            %Replace submatrix
            Rt(i:i+7, j:j+7) = R_sub_idft;

        end
    end

end

% Inverse DFT transformation 8x8
function [Rt] = myidftsub(R)
    Rt = zeros(8,8);
    for x = 0:7
        for y = 0:7
            F = 0;
            for u = 0:7
                for v = 0:7
                    F = F + 1/8 * R(u+1,v+1) * exp(2i*pi*(u*x + v*y)/8);
                end
            end
            % Store reconstructed pixel (imaginary part is only rounding noise)
            Rt(x+1,y+1) = real(F);
        end
    end
end
