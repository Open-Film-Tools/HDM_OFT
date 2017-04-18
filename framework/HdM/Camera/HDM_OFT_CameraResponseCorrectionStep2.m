function o_correctedCameraResponse = HDM_OFT_CameraResponseCorrectionStep2...
    (i_estimatedCameraResponse, ...
    i_image, ...
    i_SceneIllumination, ...
    i_PatchSet)

HDM_OFT_Utils.OFT_DispTitle('begin camera response correction step 2');

o_correctedCameraResponse = [];

%% get ref rgb

l_imageD = HDM_OFT_ImageExportImport.ImportImage(i_image, []);

if(isa(l_imageD,'uint8'))
    l_imageD = double(l_imageD) .* (1/(2^8 - 1));    
elseif(isa(l_imageD,'uint16'))
   l_imageD = double(l_imageD) .* (1/(2^16 - 1));    
end

[l_pos, l_colours] = CCFind(l_imageD);

l_colours = l_colours';

%% compute current rgb

l_sceneIllumination = HDM_OFT_GetIlluminantSpectrum(i_SceneIllumination);

l_patchReflectance = HDM_OFT_PatchSet.GetPatchSpectra(i_PatchSet);

l_sceneIlluminationMatrix = diag(l_sceneIllumination(2, :));
l_SPD_Scene = l_sceneIlluminationMatrix * l_patchReflectance(2 : end, :)';

l_signalBySensor = (i_estimatedCameraResponse(2 : end, :) * l_SPD_Scene)';

%% check

l_refColoursNormGWhiteAssumedAsMax = l_colours ./ max(l_colours(:));
l_curSignalNormGWhiteAssumedAsMax = l_signalBySensor ./ max(l_signalBySensor(:));
l_ref2cur = [l_refColoursNormGWhiteAssumedAsMax, l_curSignalNormGWhiteAssumedAsMax];


%% estimate error correction

l_sampleRange = i_estimatedCameraResponse(1, :);
l_CoeffsStart = [0.7; 2000.0];

l_shift = 600;
l_step = 1;

l_correction4BStart = l_CoeffsStart(1) + (1/l_CoeffsStart(2)) * l_sampleRange;

HDM_OFT_UI_PlotAndSave...
    ([i_estimatedCameraResponse(1, 1 : l_step : end); ...
    l_correction4BStart], ...
    'Initial Correction for Optimization', 'Wavelength (nm)' , 'Correction Scaling Factor', ...
    []);

%l_patchSelection = [3 5 6 8 13 14 18];%only blue

%l_optimParams = optimset('MaxFunEvals',2 * 2 * 100,'MaxIter',400);

% blue
[l_xB, l_resB] = fminunc(@(l_Coeffs) LSFun ...
    (l_Coeffs, l_colours(:, 3), i_estimatedCameraResponse(4, 1 : l_step : end), ...
    l_SPD_Scene(1 : l_step : end, :), i_estimatedCameraResponse(1, 1 : l_step : end), l_shift), ...
    l_CoeffsStart);

l_a = l_xB(1);
l_b = l_xB(2);

l_correction4B = l_a + (1/l_b) * l_sampleRange;

HDM_OFT_UI_PlotAndSave...
    ([i_estimatedCameraResponse(1, 1 : l_step : end); ...
    l_correction4B], ...
    'Blue Correction after Optimization', 'Wavelength (nm)' , 'Correction Scaling Factor', ...
    []);

l_response4B = l_correction4B .* i_estimatedCameraResponse(4, :);

% green
[l_xG, l_resG] = fminunc(@(l_Coeffs) LSFun ...
    (l_Coeffs, l_colours(:, 2), i_estimatedCameraResponse(3, :), l_SPD_Scene, i_estimatedCameraResponse(3, :), l_shift), ...
    l_CoeffsStart);

l_a = l_xG(1);
l_b = l_xG(2);

l_correction4G = l_a + (1/l_b) * l_sampleRange;

l_index4Center = find(i_estimatedCameraResponse(1, :) == 545);%%green line of osram in center
l_correction4G = l_correction4G ./ l_correction4G(l_index4Center);

HDM_OFT_UI_PlotAndSave...
    ([i_estimatedCameraResponse(1, :); ...
    l_correction4G], ...
    'Green Correction after Optimization', 'Wavelength (nm)' , 'Correction Scaling Factor', ...
    []);

l_response4G = l_correction4G .* i_estimatedCameraResponse(3, :);
l_response4B = l_correction4G .* i_estimatedCameraResponse(4, :);%green correction also applied for blue

% red
[l_xR, l_resR] = fminunc(@(l_Coeffs) LSFun ...
    (l_Coeffs, l_colours(:, 1), i_estimatedCameraResponse(2, :), l_SPD_Scene, i_estimatedCameraResponse(2, :), l_shift), ...
    l_CoeffsStart);

l_a = l_xR(1);
l_b = l_xR(2);

l_correction4R = l_a + (1/l_b) * l_sampleRange;

HDM_OFT_UI_PlotAndSave...
    ([i_estimatedCameraResponse(1, :); ...
    l_correction4R], ...
    'Red Correction after Optimization', 'Wavelength (nm)' , 'Correction Scaling Factor', ...
    []);

%l_response4R = l_correction4R .* i_estimatedCameraResponse(2, :);
l_response4R = l_correction4G .* i_estimatedCameraResponse(2, :);%green correction also applied for red

HDM_OFT_UI_PlotAndSave...
    ([i_estimatedCameraResponse(1, :); ...
    l_correction4R; ...
    l_correction4G; ...
    l_correction4B], ...
    'Correction after Optimization', 'Wavelength (nm)' , 'Correction Scaling Factor', ...
    ['Red' 'Green' 'Blue']);

HDM_OFT_UI_PlotAndSave...
    ([i_estimatedCameraResponse(1, :); ...
    l_response4B ./ max(l_response4G(:)); ...
    l_response4G ./ max(l_response4G(:)); ...
    l_response4R ./ max(l_response4G(:)); ...
    i_estimatedCameraResponse(4, :); ...
    i_estimatedCameraResponse(3, :); ...
    i_estimatedCameraResponse(2, :)], ...
    'Initial And Corrected Response', 'Wavelength (nm)' , 'Green Normalized Response', ...
    {'Corrected Response B' 'Corrected Response G' ...
    'Corrected Response R' 'Initial Response B' 'Initial Response G' ...
    'Initial Response R'});

o_correctedCameraResponse = ...
    [i_estimatedCameraResponse(1, :); ...
    l_response4R ./ max(l_response4G(:)); ...
    l_response4G ./ max(l_response4G(:)); ...
    l_response4B ./ max(l_response4G(:))];

end

function o_out = LSFun(i_Coeffs, i_refVals, i_estimatedCameraResponse4Channel, i_SPD_Scene, i_sampleRange, i_shift)

    l_a = i_Coeffs(1);
	l_b = i_Coeffs(2);
    
    l_curCorrection = l_a + (1/l_b) * i_sampleRange;
    l_curResponse = l_curCorrection .* i_estimatedCameraResponse4Channel;
    
    l_curVals = (l_curResponse * i_SPD_Scene)';

    l_D = ...
        i_refVals - l_curVals;
    
    %% delta per Element

    l_norm = sum(l_D.^2, 1);

    o_out = l_norm;

end
