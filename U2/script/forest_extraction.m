clc; clear; close all;

% Parameters
fileName   = "TM25_sk2_.jpg";
outputFile = "forest_pixels.mat";

% k-means segmentation
nClusters  = 8;         % clusters 
stdWindow  = 5;         % STD filter window (px)
stdWeight  = 0.5;       % weight 

% automatic clusters
paperMaxChroma = 20;    % paper candidates: low saturation
forestDeltaA   = 8;     % a* lower than paper by this = forest (greener)
waterDeltaB    = 15;    % b* lower than paper by this = water (bluer)
inkDeltaL      = 15;    % L* lower than paper by this = ink (darker)

% forest reconstruction
inkDilate     = 1;      % grow ink 
winSize       = 15;     % odd window size (px) for local forest fraction
fracThresh    = 0.5;    % 
minPaperFrac  = 0.10;   % ignore windows almost fully covered by ink
closeRadius   = 3;
maxHoleArea   = 50;     % holes larger than this are kept (assignment)
minForestArea = 1500;

% load raster
raster = imread(fileName);
rgb = im2double(raster);
lab = rgb2lab(imgaussfilt(rgb, 0.7));

% Lab colour + STD filter (texture) of lightness
texture  = stdfilt(lab(:,:,1), true(stdWindow));
features = single(cat(3, lab, stdWeight * texture));

% k-means segmentation
rng(1)   % keeps same clusters each time
[clusters, centers] = imsegkmeans(features, nClusters, 'NormalizeInput', false, 'NumAttempts', 3);
centers = double(centers);
cL = centers(:,1);
cA = centers(:,2);
cB = centers(:,3);
chroma = hypot(cA, cB);

% find coresponding clusters to segmentation [AI]
candidates = find(chroma < paperMaxChroma);
if isempty(candidates)
    candidates = (1:nClusters)';
end
[~, i] = max(cL(candidates));
paperIdx = candidates(i);
pL = cL(paperIdx);  pA = cA(paperIdx);  pB = cB(paperIdx);

role = repmat("other", nClusters, 1);
for j = 1:nClusters
    if j == paperIdx
        role(j) = "paper";
    elseif cA(j) < pA - forestDeltaA && cB(j) > 0
        role(j) = "forest";
    elseif cB(j) < pB - waterDeltaB
        role(j) = "water";
    elseif cL(j) < pL - inkDeltaL
        role(j) = "ink";
    elseif abs(cA(j) - pA) < forestDeltaA && abs(cB(j) - pB) < waterDeltaB
        role(j) = "paper";               % another paper shade
    end
    fprintf('Cluster %d  L=%5.1f a=%6.1f b=%6.1f std=%5.1f  -> %s\n', ...
        j, cL(j), cA(j), cB(j), centers(j,4) / stdWeight, role(j));
end

if ~any(role == "forest")
    warning('No forest cluster found - check the cluster table or lower forestDeltaA.');
end

isForestPix = ismember(clusters, find(role == "forest"));
isInkPix    = ismember(clusters, find(role == "ink"));
isPaperPix  = ismember(clusters, find(role == "paper"));


% dilated ink mask
ink   = imdilate(isInkPix, strel('disk', inkDilate));


% Local forest fraction among visible (non-ink) pixels
visible = imboxfilt(double(~ink), winSize);                % non-ink pixels
green   = imboxfilt(double(~ink & isForestPix), winSize);  % green pixels
mask = green > fracThresh * visible & visible > minPaperFrac;

% Close gaps
mask = imclose(mask, strel('disk', closeRadius));
mask = bwareaopen(mask, minForestArea);
mask = imopen(mask, strel('disk', 2));

% Subtract forest clearings 
clearing = imclose(isPaperPix, strel('disk', 1)); % bridge thin lines in clearings
forest   = mask & ~clearing;

% Fill holes up to maxHoleArea, keep larger ones
holes      = imfill(forest, 'holes') & ~forest;
smallHoles = holes & ~bwareaopen(holes, maxHoleArea + 1);
forest     = forest | smallHoles;
forest     = bwareaopen(forest, minForestArea);

% pixel coordinates of forest
[rows, cols] = find(forest);
forestPixels = [cols rows];           
save(outputFile, 'forestPixels', 'forest');
fprintf('Forest pixels: %d, saved to %s\n', size(forestPixels, 1), outputFile);

% Display
clusterColors = min(max(lab2rgb(centers(:,1:3)), 0), 1);
segmented = label2rgb(clusters, clusterColors);

roleColors = containers.Map({'paper', 'forest', 'water', 'ink', 'other'},{[1 1 1], [0.55 0.8 0.4], [0.4 0.6 1], [0.3 0.2 0.1], [0.8 0 0.8]});
roleMap = zeros(nClusters, 3);
    for j = 1:nClusters
        roleMap(j,:) = roleColors(char(role(j)));
    end
roleRGB = label2rgb(clusters, roleMap);

forestOnly = rgb;
forestOnly(repmat(~forest, [1 1 3])) = 1;

figure('Name', 'Forest extraction');
subplot(2,3,1); 
imshow(raster);         
title('Original map');


subplot(2,3,2);
imshow(segmented);
title(sprintf('k-means + STD filter (k = %d)', nClusters));


subplot(2,3,3); 
imshow(roleRGB);        
title('Cluster roles (magenta = other)');


subplot(2,3,4); 
imshow(ink);            
title('Ink mask');


subplot(2,3,5); 
imshow(green ./ max(visible, eps), [0 1]); 
colorbar; title('Local forest fraction');


subplot(2,3,6)
imshow(forestOnly); 
hold on
bounds = bwboundaries(forest);
for k = 1:numel(bounds)
    plot(bounds{k}(:,2), bounds{k}(:,1), 'r', 'LineWidth', 1);
end
title('Extracted forest');


% Forest as a solid green area on white background
forestColor = [0.55 0.8 0.4];
solid = ones(size(rgb));
for c = 1:3
    ch = solid(:,:,c);
    ch(forest) = forestColor(c);
    solid(:,:,c) = ch;
end
figure; imshow(solid); title('Forest (solid)');
% imwrite(solid, "forest_solid.png");