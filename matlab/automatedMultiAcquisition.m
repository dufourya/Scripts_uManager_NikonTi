function automatedMultiAcquisition(mmc)
    close all
    %% meta data
    gradient_folder = fullfile(pwd, 'gradient_pics');
    
    if ~exist(gradient_folder, 'dir')
        mkdir(gradient_folder);
    end

    configPhase = 'Phase_10X_Live';
    configFluo  = 'YFP_1mM';
    
    meta.filestub = 'RP437_no_gradient';
    
    meta.strain = 'RP437';
    meta.buffer = 'M9 salts, 0.1 mM EDTA, 0.01 mM L-methionine, 10 mM DL-lactate, pH 7.4, 0.05% m/v PVP';
    meta.growth = 'M9 salts, 1mg/L Thiamine, 10g/L Glycerol, 0.1% m/v tryptone, 30C, aerobic, OD600 ~0.16';
    %meta.attractant = '1 mM aMeAsp + 1E-5M Fluorescein tracer';
    meta.attractant = 'none';
    meta.temperature = '30C';
    
    meta.movieTime = 60; % seconds
    meta.totalTime = 60*60*3; % seconds
    
	% mm
    meta.channel.width = 1;
    meta.channel.length = 10;
    meta.channel.height = 0.01;
	
    %%
    mmc.setConfig('System','Startup');
    mmc.waitForSystem();
    checkTemperature(mmc);
    
    %% initialize stage
    q0 = questdlg('Ready to align the fields of view?', 'Warning','OK','Cancel','OK');
    
    if strcmp(q0,'OK')
        % align stage with start of channel
        %warndlg('First, align and focus the start of the channel.');
        waitfor(Live(mmc,configPhase));
        
        % set stage origin at 0,0
        mmc.setOriginXY('XYStage');
        meta.startPos.x = mmc.getXPosition('XYStage');
        meta.startPos.y = mmc.getYPosition('XYStage');
        meta.startPos.z = mmc.getPosition('ZStage');
        
        % align stage with end of channel
        %warndlg('Second, align and focus the end of the channel.');
        waitfor(Live(mmc,configPhase));
        
        % get coordinates of end position
        meta.endPos.x = mmc.getXPosition('XYStage');
        meta.endPos.y = mmc.getYPosition('XYStage');
        meta.endPos.z = mmc.getPosition('ZStage');
        
        % determine how many frame are necessary to cover the channel
        totalLength = max(abs(meta.endPos.y - meta.startPos.y), abs(meta.endPos.x - meta.startPos.x));
        nbFrame = ceil(abs(totalLength/mmc.getImageWidth/mmc.getPixelSizeUm));
        
        % calculate coordinates for all frames
        x = round(meta.startPos.x:(meta.endPos.x-meta.startPos.x+0.1)/(nbFrame):meta.endPos.x+0.1);
        y = round(meta.startPos.y:(meta.endPos.y-meta.startPos.y+0.1)/(nbFrame):meta.endPos.y+0.1);
        z = round(meta.startPos.z:(meta.endPos.z-meta.startPos.z+0.1)/(nbFrame):meta.endPos.z+0.1);
        
        
        %% recording movies
        q1 = questdlg('Ready to begin recording?', 'Warning','OK','Cancel','OK');
        if strcmp(q1,'OK')
            
            tic0=tic;
            movienb = 1;
            save = 1;
            no_save = 0;
            no_crop = 0;
            
            while toc(tic0) < meta.totalTime
                for iFrame = 1:numel(x)
                    fprintf(strcat('Acquiring movie nb: ',int2str(movienb),'\n'));
                    image_prefix = strcat(meta.filestub, '_', ...
                                          sprintf('%03d',movienb));
                    gradient_prefix = fullfile(gradient_folder, image_prefix);
                    before_name = strcat(gradient_prefix, FileInfo.gradBeforeExt);
					before_meta_name = strcat(gradient_prefix,'_before', FileInfo.metaExt);
                    after_name = strcat(gradient_prefix, FileInfo.gradAfterExt); 
					after_meta_name = strcat(gradient_prefix, '_after', FileInfo.metaExt);

                    meta.currentPos.x = x(iFrame);
                    meta.currentPos.y = y(iFrame);
                    meta.currentPos.z = z(iFrame);
                    
                    mmc.setXYPosition('XYStage',x(iFrame),y(iFrame));
                    mmc.waitForDevice('XYStage');
                    mmc.setPosition('ZStage',z(iFrame));
                    mmc.waitForDevice('ZStage');
                    mmc.waitForImageSynchro();
                    imgEpi = takePicture(mmc, configFluo, no_crop, save, before_name);                  
                    
                    imgPhase = takePicture(mmc, configPhase, no_crop, no_save);
                    
                    subplot(1,2,1),
                    imshow(imgEpi,[]);
                    subplot(1,2,2),
                    imshow(imgPhase,[]);
                    title(sprintf('movie: %d, x=%d, y=%d, z=%d', movienb, ...
                                  x(iFrame), y(iFrame), z(iFrame)));
                    drawnow;
                    
                    reltime = toc(tic0);
                    movie_metadata = sequenceAcquisition(mmc, image_prefix, ...
                                                         meta.movieTime, ...
                                                         configPhase);
                    
                    imgEpi = takePicture(mmc, configFluo, no_crop, save, after_name);
                    
                    movie_metadata.add('Sample', 'Strain', meta.strain);
                    movie_metadata.add('Sample', 'Buffer', meta.buffer);
                    movie_metadata.add('Sample', 'Growth', meta.growth);
                    movie_metadata.add('Sample', 'Attractant', meta.attractant);
                    movie_metadata.add('Sample', 'Temperature', meta.temperature);
                    movie_metadata.add('Microfluidics', 'Height_um', ...
                                       sprintf('%f', meta.channel.height));
                    movie_metadata.add('Microfluidics', 'Width_um', ...
                                       sprintf('%f', meta.channel.width));
                    movie_metadata.add('Microfluidics', 'Length_um', ...
                                       sprintf('%f', meta.channel.length));
                    movie_metadata.add('Experiment', 'RelativeTime_sec', ...
                                       sprintf('%f', reltime));
                    movie_metadata.write();
                    movienb = movienb + 1;
                    toc(tic0)
                end
            end
            
            mmc.setXYPosition('XYStage',x(1),y(1));
            mmc.setPosition('ZStage',z(1));
            mmc.waitForSystem();
            mmc.setConfig('System','Shutdown');
        end
    end
end
