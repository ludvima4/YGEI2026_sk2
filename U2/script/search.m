clc; clear; close all;

% Settings
rasterFile   = "MMC_sk2.jpg";
templateFile = "templates.mat";   %  user templates
outputFile   = "coordinates.csv"; % resulting pixel coordinates
scriptPath   = mfilename('fullpath');    % used by the reset button

nTemplates = 5;      % number of user-selected templates
threshold  = 0.61;   % correlation threshold

% Read raster and compute HSL lightness
raster = imread(rasterFile);
rgb = im2double(raster);
lightness = (max(rgb, [], 3) + min(rgb, [], 3)) / 2;

% Load saved templates or select new ones [AI]
useSaved = false;
if isfile(templateFile)
    saved = load(templateFile);
    if isfield(saved, 'rasterFile') && strcmp(saved.rasterFile, rasterFile) ...
            && numel(saved.crops) == nTemplates
        crops = saved.crops;
        useSaved = true;
        fprintf('Templates loaded from %s\n', templateFile);
    else
        fprintf('Saved templates belong to another raster or count, select new ones.\n');
    end
end

if ~useSaved
    crops = selectTemplates(raster, lightness, nTemplates);
    save(templateFile, 'crops', 'rasterFile');
    fprintf('Templates saved to %s\n', templateFile);
end

% Resize crops to a common size and average them into one template
sizes = cell2mat(cellfun(@size, crops, 'UniformOutput', false)');
tplH = round(median(sizes(:, 1)));
tplW = round(median(sizes(:, 2)));

stack = zeros(tplH, tplW, nTemplates);
for k = 1:nTemplates
    stack(:, :, k) = imresize(crops{k}, [tplH tplW]);
end
template = mean(stack, 3);

figure(2)
for k = 1:nTemplates
    subplot(1, nTemplates + 1, k)
    imshow(stack(:, :, k), [])
    title(sprintf('%d', k))
end
subplot(1, nTemplates + 1, nTemplates + 1)
imshow(template, [])
title('Mean')

% Normalized cross-correlation
c = normxcorr2(template, lightness);

% only positions where the template lies fully inside the raster
valid = false(size(c));
valid(tplH:size(lightness, 1), tplW:size(lightness, 2)) = true;

% Find peaks above threshold
peaks = imregionalmax(c);
idx = find(peaks & c >= threshold & valid);
fprintf('Peaks above threshold: %d\n', numel(idx));

% Remove multiple detections
[~, order] = sort(c(idx), 'descend');
idx = idx(order);
[yPeak, xPeak] = ind2sub(size(c), idx);

keep = true(numel(idx), 1);
for i = 1:numel(idx)
    if ~keep(i) 
        continue 
    end
    near = abs(xPeak - xPeak(i)) < tplW/2 & abs(yPeak - yPeak(i)) < tplH/2;
    near(1:i) = false;
    keep(near) = false;
end
idx   = idx(keep);
xPeak = xPeak(keep);
yPeak = yPeak(keep);
fprintf('found: %d\n', numel(idx));

% Pixel coordinates of churches
xCorner = xPeak - tplW + 1;
yCorner = yPeak - tplH + 1;
xCenter = xCorner + (tplW - 1) / 2;
yCenter = yCorner + (tplH - 1) / 2;
correlation = c(idx);

churches = table((1:numel(idx))', xCenter, yCenter, xCorner, yCorner, correlation, ...
    'VariableNames', {'ID', 'x_center', 'y_center', 'x_corner', 'y_corner', 'correlation'});
disp(churches)
writetable(churches, outputFile);

% Display correlation map
figure(3)
imagesc(c)
axis image
colormap jet
colorbar
title('Template correlation')

% Display results
fig4 = figure(4);
imshow(raster)
hold on
for k = 1:height(churches)
    rectangle('Position', [churches.x_corner(k), churches.y_corner(k), tplW, tplH],'EdgeColor', 'r', 'LineWidth', 2);
    plot(churches.x_center(k), churches.y_center(k), 'r+', 'MarkerSize', 8)
    text(churches.x_corner(k), churches.y_corner(k) - 5,sprintf('%d (%.2f)', churches.ID(k), churches.correlation(k)), ...
        'Color', 'r', 'FontSize', 8, 'FontWeight', 'bold', 'VerticalAlignment', 'bottom');
end
title(sprintf('Churches found: %d', height(churches)))



% reset button
uicontrol(fig4, 'Style', 'pushbutton', 'String', 'Select new templates', ...   % [AI]
    'Units', 'normalized', 'Position', [0.01 0.01 0.18 0.05], ...
    'Callback', @(~,~) resetTemplates(templateFile, scriptPath));




% Functions 
% select teplates
function crops = selectTemplates(raster, lightness, nTemplates) %[AI]
    crops = cell(1, nTemplates);
    fig = figure(1);
    imshow(raster)
    hold on
    btn = uicontrol(fig, 'Style', 'pushbutton', 'String', 'Select symbol', ...
        'Units', 'normalized', 'Position', [0.01 0.01 0.15 0.05], ...
        'Callback', @(~,~) uiresume(fig));
        
        for k = 1:nTemplates
            % phase 1: free zoom / pan
            title(sprintf('Zoom to symbol %d and click "Select symbol"', k))
            zoom(fig, 'on')
            uiwait(fig)
            zoom(fig, 'off')
        
            % phase 2: drag a rectangle
            title(sprintf('Select symbol %d of %d (drag a rectangle)', k, nTemplates))
            roi = drawrectangle('Color', 'g', 'LineWidth', 1.5);
            rect = round(roi.Position);
            crops{k} = imcrop(lightness, rect);
            text(rect(1), rect(2) - 5, num2str(k), 'Color', 'g', 'FontWeight', 'bold')
        end
    
    delete(btn)
    title('Selection finished')
end



function resetTemplates(templateFile, scriptPath) %[AI]
    %RESETTEMPLATES 
    choice = questdlg('Delete saved templates and select new ones?', ...
        'New templates', 'Yes', 'No', 'No');
    if ~strcmp(choice, 'Yes')
        return
    end
    if isfile(templateFile)
        delete(templateFile)
    end
    run(scriptPath)
end