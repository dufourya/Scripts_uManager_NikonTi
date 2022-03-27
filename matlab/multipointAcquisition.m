function multipointAcquisition(mmc, config)
    % Takes a series of images based on defined beginning and end points
    % for any number of regions.
    % INPUTS:
    % mmc      : mmc object
    % regions  : either the number of regions to image or an array of
    %            structs that contain arrays of x, y, and z.
    % config   :
    %     .channels :an array of structs with information about each channel to 
    %                use in each position of each region:
    %           .name     : the channel name.
    %           .exposure : the exposure time in ms.
    %           .gain     : the gain.
    %     .regions
    %           .x : an array of x positions
    %           .y : an array of y positions
    %           .z : an array of z positions
    %   

    mmc.setTimeoutMs(100000);
    camera = char(mmc.getCameraDevice());
    phase_config = 'Phase_10X';
    metadata = '';
    n_regions = 0;
    regions = config.regions;
    if isnumeric(regions)
        n_regions = regions;
        regions = [];
        for i = 1:n_regions
            fprintf('Defining region %d of %d\n', i, n_regions);
            regions = [regions defineMultipointPositions(mmc, phase_config)];
        end
    else
        n_regions = numel(regions);
    end
    config.regions = regions;
    
    save('multipointAcquisition.mat', 'config');
    for i = 1:n_regions
        
        reg_path = strcat('Region', num2str(i-1));
        mkdir(reg_path);
        region = regions(i);

        for j = 1:numel(region.x)
            pos_path = fullfile(reg_path, strcat('Pos', num2str(j-1)));
            mkdir(pos_path);
            mmc.setXYPosition('XYStage', region.x(j), region.y(j));
            mmc.setPosition('ZStage', region.z(j));
            while (mmc.deviceBusy('XYStage')) mmc.sleep(100); end

            for k = 1:numel(config.channels)
                channel = config.channels(k);
                name = channel.name;
                mmc.setConfig('Channel', name);
                check15Xswitch(mmc);
                if isfield(channel, 'exposure') && ~isempty(channel.exposure)
                    mmc.setExposure(channel.exposure);
                end
                if isfield(channel, 'gain') && ~isempty(channel.gain)
                    mmc.setProperty(camera, 'Gain', num2str(channel.gain));
                end
                
                img_path = fullfile(pos_path, strcat(name, '.tif'));
                meta_path = fullfile(pos_path, strcat(name, '.txt'));
                mmc.waitForImageSynchro();
                mmc.snapImage();
                timg = mmc.getTaggedImage();

                w = mmc.getImageWidth();
                h = mmc.getImageHeight();
                
                img.pix = uint16(rotateFrame(timg.pix,mmc));
                imwrite(img.pix, img_path, 'TIFF');

                img.tags = loadjson(char(timg.tags));
                img.tags.XPositionUm = mmc.getXPosition('XYStage');
                img.tags.YPositionUm = mmc.getYPosition('XYStage');
                img.tags.ZPositionUm = mmc.getPosition('ZStage');
                savejson('',img.tags, meta_path);
            end
        end 
    end
    mmc.setXYPosition('XYStage', regions(1).x(1), regions(1).y(1));
    mmc.setPosition('ZStage', regions(1).z(1));
    while (mmc.deviceBusy('XYStage')) mmc.sleep(100); end
end