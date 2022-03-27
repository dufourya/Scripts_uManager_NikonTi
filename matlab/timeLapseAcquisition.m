function timeLapseAcquisition(mmc, strain, totalTime, interval, configPhase, configFluo)
    
    if iscell(strain)
        strain = strjoin(strain,'_');
    end
    
    if regexp(strain,'[^\w()_-]')
        error('Invalid file name!');
    end
    
    mmc.setConfig('System','Startup');
    mmc.waitForSystem();
    
    if nargin < 6 || isempty(configFluo)
        configFluo = [];
        fprintf('No fluorescence acquisition scheduled.\n');
    else
        availableConfigs = string(mmc.getAvailableConfigs('Channel').toArray());
        ind = ~ismember(configFluo,availableConfigs);
        if sum(ind)
            error('Config not available: %s\n', configFluo{ind});
        else
            configData = mmc.getConfigData('Channel',configPhase);
            for i = 1:configData.size()
                property = mmc.getConfigData('Channel',configPhase).getSetting(i-1);
                for k = 1:numel(configFluo)
                    mmc.defineConfig('Channel',sprintf('Phase_%s',configFluo{k}), property.getDeviceLabel(),property.getPropertyName(),property.getPropertyValue());
                end
            end
            block_fluo = cell(numel(configFluo),1);
            for k = 1:numel(configFluo)
                block_fluo{k} = regexp(char(mmc.getConfigData('Channel',configFluo{k}).getVerbose()),'TIFilterBlock1:State=(\d)','tokens');
                block_fluo{k} = block_fluo{k}{1}{1};
                mmc.defineConfig('Channel',sprintf('Phase_%s',configFluo{k}),'TIFilterBlock1','State',block_fluo{k});
            end
            [~, blockorder] = sort(block_fluo);
            configFluo = configFluo(blockorder);
            fprintf('Taking fluorescence pictures in channel: %s\n', configFluo{:});
        end
    end
    
    t = clock;
    file_prefix = sprintf('%02d%02d%02d_%02d%02d',t(1:5));
    username = getenv('USERNAME');
    checkTemperature(mmc);
    
    %% Acquire flat fields
    flats = acquireFlatFields(mmc,16,configPhase,configFluo);
    
    phase_flat = flats.(genvarname(configPhase));
    phase_flat = phase_flat / trimmean(phase_flat(:),0.8);
    
    fluo_flats = cell(numel(configFluo),1);
    for k = 1:numel(configFluo)
        fluo_flats{k} = flats.(genvarname(regexprep(configFluo{k},'_\d+sola','')));
        fluo_flats{k} = fluo_flats{k} / trimmean(fluo_flats{k}(:),0.8);
    end
    %%
    q0 = questdlg('Place SAMPLE slide on stage. Turn off the lights.', 'Warning','OK','Cancel','OK');
    
    if ~strcmp(q0,'OK')
        error('Acquisition aborted');
    end
    
    close all;
    mmc.setOriginXY('XYStage');
    coordinates = Live(mmc,configPhase);
    if isempty(coordinates)
        coordinates = [0 0];
    end
    
    if ~strcmp(mmc.getProperty('TIPFSStatus','State'),'On')
        error('Aborted! PFS needs to be turned ON.');
    end
    
    i=1;
    if exist(strcat('./',strain),'dir')
        existingslides = dir(strain);
        for j = 1:numel(existingslides)
            if existingslides(j).isdir
                i = max(i,1+str2double(strtok(existingslides(j).name,'_')));
            end
        end
        q1 = questdlg('Creating a new slide for the same sample. Do you want to proceed?', 'Warning','OK','Cancel','OK');
        
        if strcmp(q1,'Cancel')
            error('Acquisition aborted');
        end
        mkdir(strain,sprintf('%.3d_slide',i));
    else
        mkdir(strain);
        mkdir(strain,sprintf('%.3d_slide',i));
    end
    
    loci.common.DebugTools.enableLogging('ERROR');
    
    %%   Acquisition
    
    if mmc.getBytesPerPixel == 2
        pixelType = 'uint16';
    else
        pixelType = 'uint8';
    end
    
    screensize = get( groot, 'Screensize' );
    
    startTime = tic;
    nmsg = 0;
    fprintf('Acquiring time lapse for %g minutes.\n', totalTime);
    
    phase_fft_prev = zeros(mmc.getImageWidth(),mmc.getImageHeight(),size(coordinates,1));
    pixelSize = mmc.getPixelSizeUm;
    
    k = 0;
    for pos = 1:size(coordinates,1)
        fig = figure(pos);
        fig.Name = sprintf('Postion #%.3d',pos);
        fig.Position = [ceil(screensize(3)*0.1)+30*pos ceil(screensize(4)*0.1)+30*pos ceil(screensize(3)*0.8) ceil(screensize(4)*0.5)];
        fig.NumberTitle = 'off';
    end
    
    while toc(startTime) < totalTime*60
        
        if toc(startTime) > k*interval*60
            
            k = k+1;
            
            for pos = 1:size(coordinates,1)
                
                figure(pos);
                
                mmc.setXYPosition('XYStage',coordinates(pos,1),coordinates(pos,2));
                fprintf(repmat('\b',1,nmsg));
                msg = sprintf('Image: %04d, %d minutes remaining...Position: %.3d', k, round(totalTime-toc(startTime)/60),pos);
                fprintf(msg);
                nmsg=numel(msg);
                
                ometiff = zeros(mmc.getImageWidth, mmc.getImageHeight, numel(configFluo)+1, 1, 1, 'uint16');
                metadata = createMinimalOMEXMLMetadata(ometiff,'XYCZT');
                
                % Phase
                mmc.setConfig('Channel',configPhase);
                check15Xswitch(mmc);
                mmc.waitForImageSynchro();
                % get dark image
                mmc.setAutoShutter(0);
                mmc.snapImage();
                img_dark = typecast(mmc.getImage(),pixelType);
                img_dark = rotateFrame(img_dark,mmc);
                % get flat image
                mmc.setAutoShutter(1);
                mmc.snapImage();
                img_flat = typecast(mmc.getImage(),pixelType);
                img_flat = rotateFrame(img_flat,mmc);
                phase = img_flat-img_dark;
                phase_fft = fft2(phase);
                
                [row_shift,col_shift] = dftregistermicroscope(phase_fft_prev(:,:,pos),phase_fft,fix(size(phase_fft,1)/10));
                
                if col_shift~=0  || row_shift~=0
                    xPos = mmc.getXPosition('XYStage');
                    yPos = mmc.getYPosition('XYStage');
                    %                 fprintf('Correcting alignment\n');
                    mmc.setXYPosition('XYStage',xPos-col_shift*pixelSize,yPos-row_shift*pixelSize);
                    mmc.waitForImageSynchro();
                    % get dark image
                    mmc.setAutoShutter(0);
                    mmc.snapImage();
                    img_dark = typecast(mmc.getImage(),pixelType);
                    img_dark = rotateFrame(img_dark,mmc);
                    % get flat image
                    mmc.setAutoShutter(1);
                    mmc.snapImage();
                    img_flat = typecast(mmc.getImage(),pixelType);
                    img_flat = rotateFrame(img_flat,mmc);
                    phase = img_flat-img_dark;
                    phase_fft = fft2(phase);
                end
                
                xPos = mmc.getXPosition('XYStage');
                yPos = mmc.getYPosition('XYStage');
                coordinates(pos,1) = xPos;
                coordinates(pos,2) = yPos;
                phase_ref = imref2d(size(phase));
                phase_fft_prev(:,:,pos) = phase_fft;
                metadata.setImageAcquisitionDate(ome.xml.model.primitives.Timestamp(string(org.joda.time.Instant)),0);
                img = uint16(double(phase)./phase_flat);
                ometiff(:,:,1,1,1) = img;
                metadata.setChannelName(configPhase,0,0);
                
                
                subplot(1,numel(configFluo)+1,1);
                imshow(ometiff(:,:,1,1,1),[]);
                title(configPhase,'Interpreter','none');
                xlabel({sprintf('Stage position: %d um, %d um',xPos, yPos),...
                    sprintf('Saturation: %d pixels',sum(img(:) == max(img(:))))});
                drawnow;
                
                %Fluo
                for fi = 1:numel(configFluo)
                    mmc.setConfig('Channel',sprintf('Phase_%s',configFluo{fi}));
                    check15Xswitch(mmc);
                    mmc.waitForImageSynchro();
                    mmc.setAutoShutter(0);
                    mmc.snapImage();
                    img_dark = typecast(mmc.getImage(),pixelType);
                    img_dark = rotateFrame(img_dark,mmc);
                    % get flat image
                    mmc.setAutoShutter(1);
                    mmc.snapImage();
                    img_flat = typecast(mmc.getImage(),pixelType);
                    img_flat = rotateFrame(img_flat,mmc);
                    img_shift = img_flat-img_dark;
                    [row_shift,col_shift] = dftregistermicroscope(phase_fft,fft2(img_shift),10);
                    tform = affine2d();
                    tform.T(3,1) = col_shift;
                    tform.T(3,2) = row_shift;
                    
                    mmc.setConfig('Channel',configFluo{fi});
                    check15Xswitch(mmc);
                    mmc.waitForImageSynchro();
                    % get dark image
                    mmc.setAutoShutter(0);
                    mmc.snapImage();
                    img_dark = typecast(mmc.getImage(),pixelType);
                    img_dark = rotateFrame(img_dark,mmc);
                    % get flat image
                    mmc.setAutoShutter(1);
                    mmc.snapImage();
                    img_flat = typecast(mmc.getImage(),pixelType);
                    img_flat = rotateFrame(img_flat,mmc);
                    img_flat = uint16(double(img_flat-img_dark)./fluo_flats{fi});
                    img_flat = imwarp(img_flat,tform,'OutputView',phase_ref,'FillValue',mode(img_flat(:)));
                    ometiff(:,:,fi+1,1,1) = img_flat;
                    metadata.setChannelName(configFluo{fi},0,fi);
                    
                    subplot(1,numel(configFluo)+1,fi+1),
                    imshow(ometiff(:,:,fi+1,1,1),[]);
                    title(configFluo{fi},'Interpreter','none');
                    xlabel({sprintf('Shift: %d, %d pixels',tform.T(3,1), tform.T(3,2)),...
                        sprintf('Saturation: %d pixels\n',sum(img_flat(:) == max(img_flat(:))))});
                    drawnow;
                end
                
                metadata.setImageDescription(strain, 0);
                metadata.setImageExperimenterRef(username,0);
                metadata.setPlanePositionX(ome.units.quantity.Length(java.lang.Double(xPos), ome.units.UNITS.MICROMETER), 0,0)
                metadata.setPlanePositionY(ome.units.quantity.Length(java.lang.Double(yPos), ome.units.UNITS.MICROMETER), 0,0)
                metadata.setPlanePositionZ(ome.units.quantity.Length(java.lang.Double(mmc.getProperty('TIPFSOffset','Position')),...
                    ome.units.UNITS.MICROMETER), 0,0)
                pixelSizeOme = ome.units.quantity.Length(java.lang.Double(mmc.getPixelSizeUm), ome.units.UNITS.MICROM);
                metadata.setPixelsPhysicalSizeX(pixelSizeOme, 0);
                metadata.setPixelsPhysicalSizeY(pixelSizeOme, 0);
                metadata.setPixelsPhysicalSizeZ(pixelSizeOme, 0);
                bfsave(ometiff,fullfile(strain,sprintf('%.3d_slide',i),sprintf('%s_%s_t%.4dxy%.3d.ome.tiff',file_prefix,strain,k,pos)),...
                    'dimensionOrder', 'XYCZT', 'metadata', metadata, 'Compression', 'LZW');
            end
        end
    end
    
    fprintf('\nDone\n');
end
