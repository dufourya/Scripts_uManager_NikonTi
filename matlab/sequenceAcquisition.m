function file = sequenceAcquisition(mmc, file, runtime, config, fps, bit8, crop)
    % Record a movie, saved as raw binary output.
    %
    % INPUTS
    %   mmc     : the micro-manager object representing the microscope.
    %   file    : the output file name.
    %   runtime : the length of the movie to be recorded, in seconds.
    %   config  : the name of the objective configuration used to acquire the
    %               movie
    %   fps     : max frame per second
    %   bit8    : boolean, convert image to 8 bit/pixel instead of 16bit
    %   crop    : boolean, crop image by half
    
    % OUTPUT
    %  A raw binary file in little-endian byte order.
    %  metadata = a Metadata object describing the acquisition.
    
    % check for invalid charaters in file name
    fclose('all');
    % if ~strcmp(mmc.getProperty('TIPFSStatus','State'),'On')
    %     error('PFS not locked!');
    % end
    
    %   540 MHz 9.8304 ms deadtime
    %   200 MHz 24.576 ms deadtime
    
    if iscell(file)
        file = strjoin(file,'_');
    end
    
    t = clock;
    file = strcat(sprintf('%02d%02d%02d_%02d%02d_',t(1:5)),file);
    
    if regexp(file,'[^\w()_-]')
        error('Invalid file name!');
    end

    %% microscope settings
    import mmcorej.mmc.*;
    %     f_name = getFunctionName()
    computer_name = getenv('COMPUTERNAME');
    camera = mmc.getCameraDevice();
    
    % set microscope settings
    mmc.setConfig('System','Startup');
    mmc.setConfig('Channel',config);
    check15Xswitch(mmc);
    mmc.waitForSystem();
       
    % check camera pixelType
    if mmc.getBytesPerPixel == 2
        pixelType = 'uint16';
        realbit = 16;
    else
        pixelType = 'uint8';
        realbit = 8;
    end
    
    % set circular buffer
    %     [~,sysmem] = memory;
    max_buff_size_mb = 20000; %(sysmem.PhysicalMemory.Available - sysmem.PhysicalMemory.Total*0.2)/(1024^2);
    
    %% prepare frame rate config
    w=mmc.getImageWidth();
    h=mmc.getImageHeight();
    interval = mmc.getExposure;
    skip_frame = 1;
    
    if fps ~=0
        skip_frame = round(1000/(fps * interval));
        if skip_frame < 1 || skip_frame > 10
            error('The target aquisition frame rate cannot be achieved with this configuration! Use fps = 0 if you want to record at the maximum possible frame rate.');
        elseif skip_frame > 1 && strcmp(mmc.getProperty('Arduino-Switch','Blanking Mode'),'On')
            import mmcorej.StrVector
            seq = StrVector();
            seq.add(mmc.getProperty('Arduino-Switch', 'State'))
            for i = 2:skip_frame
                seq.add('0')
            end
            mmc.setProperty('Arduino-Switch', 'Sequence','On')
            mmc.loadPropertySequence('Arduino-Switch','State',seq)
            mmc.startPropertySequence('Arduino-Switch','State')
            fprintf('Shutter sequence activated.\n');
        end
    end
    
    nImages = ceil(runtime*1000/interval)+skip_frame-1;
    
    circular_buffer = max(100,min(max_buff_size_mb,(nImages+skip_frame+10)*w*h*mmc.getBytesPerPixel/(1024^2)));
    mmc.setCircularBufferMemoryFootprint(circular_buffer);
    mmc.initializeCircularBuffer();
    
    %% start sequence acquisition
    if bit8 == 1
        fprintf('Converting images to 8 bits\n');
    else
        fprintf('Recording images in 16 bits\n');
    end
    if crop == 1
        fprintf('Frame is cropped by 1/2\n');
    else
        fprintf('Recording full frame\n');
    end
    fprintf('Image resolution: %d x %d\n', mmc.getImageWidth, mmc.getImageHeight);
    fprintf('Skipping %d frame(s)\n', skip_frame-1);
    fprintf('Image interval: %.2f ms\n', skip_frame*interval);
    fprintf('Recording at %.2f frames/sec\n', 1000/(skip_frame*interval));
    fprintf('Capturing %d images for %d seconds\n', ceil(nImages/skip_frame),runtime);
    fprintf('Circular buffer size: %0.0d MB\n', circular_buffer);
    
    checkTemperature(mmc);
    
    mmc.prepareSequenceAcquisition(camera)
    mmc.setProperty(camera,'FrameRate','1000');
    
    mmc.setShutterOpen(1);
    mmc.waitForImageSynchro();
      
    mmc.startSequenceAcquisition(nImages+skip_frame-1,0,1);
    tic1=tic;
    % mmc.getProperty(camera,'FrameRate')
    
    strInt = regexp(string(mmc.getProperty(camera,'FrameRateLimits')),'Max:\s+(\S+)','tokens');
    interval = 1000/str2double(strInt{1});
    if string(mmc.getProperty('Arduino-Switch','Blanking Mode')) == "On"
        strFR = regexp(string(mmc.getProperty(camera,'FrameRateLimits')),'Min:\s+(\S+)','tokens');
        deadinterval = 1000/str2double(strFR{1}) - interval;
    else
        deadinterval = 0;
    end
    exposure = str2double(mmc.getProperty(camera,'Exposure'))-deadinterval;
    fprintf('Image exposure = %.2f ms\n', exposure);
    
    fprintf('Acquisition in progress: 000%%');
    
    while mmc.isSequenceRunning && ~mmc.isBufferOverflowed
        fprintf('\b\b\b\b%0.3d%%',ceil(100*mmc.getRemainingImageCount()/(nImages+skip_frame)));
        pause(interval/1000);
    end
    fprintf('\n');
    toc(tic1);
    mmc.waitForSystem;
       
    if mmc.isBufferOverflowed
        error('Circular buffer is overflowed! Reduce sequence length or frame rate.');
    end
    %%
    metadata = Metadata(strcat(file, FileInfo.metaExt));
    metadata.create(mmc);
    
    if strcmp(mmc.getProperty('Arduino-Switch', 'Sequence'),'On')
        mmc.stopPropertySequence('Arduino-Switch','State');
        mmc.setProperty('Arduino-Switch', 'Sequence','Off');
    end
    
    mmc.setShutterOpen(0);
    
    %% open files to save data
    
    imgfile = strcat(file, FileInfo.binExt);
    fid = fopen(imgfile,'w');
    
    sync_seq = 0;
    sync_mean = -Inf;
    i = 0;
    
    while i < skip_frame && skip_frame > 1
        if mmc.getRemainingImageCount()>0
            img = mmc.popNextImage();
            img = typecast(img, pixelType);
            mimg = mean(img(:));
            %         fprintf('Mean intensity sync %d: %d\n',i,mimg);
            if mimg > sync_mean
                sync_mean = mimg;
                sync_seq = i;
            end
            i = i+1;
        end
    end
    
    i=0;
    nImages_actual = 0;
    
    fprintf('Writing data to disk...');
    
    while mmc.getRemainingImageCount()>0
        img = mmc.popNextImage();
        if mod(i-sync_seq, skip_frame) == 0
            img = typecast(img, pixelType);
            if crop == 1
                img = reshape(img,w,h);
                img = img((w/2-w/4+1):(w/2+w/4), (h/2-h/4+1):(h/2+h/4));
                img = img(:);
            end
            if bit8 == 1 && realbit ~= 8
                img = uint8(double(img) * (2^8 - 1) / (2^realbit - 1));
                fwrite(fid, img, 'uint8');
            else
                fwrite(fid, img, pixelType);
            end
            nImages_actual = nImages_actual + 1;
        end
        i = i+1;
    end
    fclose(fid);
    fprintf('%d images\n\n', nImages_actual);
    
    imagesBeforeFreeze = nImages_actual;

    %%
    mmc.clearCircularBuffer;
    mmc.waitForSystem;
    
    %% write more metadata
    metadata.add('Camera', 'LightExposure', num2str(exposure));
    metadata.add('Experiment', 'Date', date);
    metadata.add('Experiment', 'Time', datestr(rem(now,1)));
    metadata.add('Experiment', 'DateVector', num2str(clock));
    metadata.add('Experiment', 'Computer', computer_name);
    metadata.add('Experiment', 'User', getenv('USERNAME'));
    
    metadata.add('SequenceAcquisition', 'ActualIntervalBurst-ms', ...
        sprintf('%f', skip_frame * interval));
    metadata.add('SequenceAcquisition', 'NumberImages', ...
        sprintf('%d', nImages_actual));
    metadata.add('SequenceAcquisition', 'NImagesBeforeFreeze', ...
        sprintf('%d', imagesBeforeFreeze));
    if bit8 == 1
        metadata.add('SequenceAcquisition', 'FilePixelType', '*uint8');
    else
        metadata.add('SequenceAcquisition', 'FilePixelType', ...
            strcat('*', pixelType));
    end
    
    if crop == 1
        metadata.set('Camera', 'ImageWidth', ...
            sprintf('%f', mmc.getImageWidth()/2));
        metadata.set('Camera', 'ImageHeight', ...
            sprintf('%f', mmc.getImageHeight()/2));
    end
    metadata.write();
end
