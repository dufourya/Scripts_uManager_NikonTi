function viewMovie(image_file, varargin)
    
    track_method = 'radcenter';
    save_movie = 0;
    show_detection = 0;
    show_tracking = 0;
    % show_background = 0;
    subtract_background = 0;
    make_tiff = 0;
    filtertraj =[];
    visfig = 'On';
    
    vararginchar = varargin;
    vararginchar(~cellfun(@ischar,varargin)) = {''};
    
    if strcmp(track_method, 'radcenter')
        image_info = RadFileInfo(image_file);
    elseif strcmp(track_method, 'utrack')
        image_info = UtrackFileInfo(image_file);
    else
        error(['do not recognize tracking method ''' track_method '''.'])
    end
    
    [path, name, ~] = fileparts(image_file);
    
    if ~exist(fullfile(path,image_info.bin_file), 'file')
        error(['could not find ''' image_info.bin_file ''' on path.'])
    end
    
    metadata = Metadata(fullfile(path,image_info.metaFile));
    metadata.read();
    n_frames = metadata.getNumberOfImages();
    % n_frames_before_freeze = metadata.getNImagesBeforeFreeze();
    % if isempty(n_frames_before_freeze)
    %     n_frames_before_freeze=n_frames;
    % end
    interval = metadata.getImageIntervalMs() / 1000;
    %     pixel_size = metadata.getPixelSize();
    height = metadata.getImageHeightPixel();
    width = metadata.getImageWidthPixel();
    pixel_type = metadata.getPixelType();
    
    if ismember('tifstack',vararginchar)
        make_tiff = 1;
        visfig = 'Off';
        mkdir(name);
    end
    
    if ismember('background',vararginchar)
        subtract_background = 1;
    end
    
    
    if ismember('mask',vararginchar) && exist(image_info.maskFile,'file')
        mask = flipud(imread(image_info.maskFile));
        mask = mask == max(mask(:));
        mask_image = 1;
    else
        mask = true(width,height);
    end
    
    if ismember('detection',vararginchar)
        show_detection = 1;
    end
    if ismember('tracking',vararginchar)
        show_tracking = 1;
    end
    if ismember('save',vararginchar)
        save_movie = 1;
        visfig = 'Off';
    end
    % if ismember('showbackground',vararginchar)
    %     show_background = 1;
    % end
    [~,fi]=ismember('filtertraj',vararginchar);
    if fi
        filtertraj = varargin{fi+1};
    end
    
    if isempty(path)
        path = pwd();
    end
    
    if save_movie
        movie_mag =  min(100*2^floor(log2(1024/height)), 100*2^floor(log2(1024/height)));
    else
        screensize = get( groot, 'Screensize' );
        movie_mag =  min(100*2^floor(log2((screensize(3)-100)/height)), 100*2^floor(log2((screensize(4)-100)/height)));
        if ismac
            movie_mag =  min(100*2^floor(log2((2*screensize(3)-100)/height)), 100*2^floor(log2((2*screensize(4)-100)/height)));
        end
    end
    
    if save_movie
        vid_obj = VideoWriter(image_info.aviFile,'Archival');
        vid_obj.FrameRate = ceil(1/interval);
        %vid_obj.Quality = 100;
        open(vid_obj);
        fprintf('Saving movie to file.\n');
    end
    
    if show_detection && exist(fullfile(path,image_info.detectionFile),'file')
        data = load(fullfile(path,image_info.detectionFile),'detected_objs','rad_detection');
        detected_objs = data.detected_objs;
        if make_tiff
            rad_detection = data.rad_detection;
            imageFilename = compose('%s\\%s\\frame_%04d.tif',pwd,name,1:n_frames)';
            object = cell(numel(imageFilename),1);
            for i = 1:numel(object)
                n_obj = size(rad_detection(i).xCoord,1);
                object{i} = [rad_detection(i).xCoord(:,1)-12 rad_detection(i).yCoord(:,1)-12 25*ones(n_obj,2)];
            end
            objs_boxes = table(imageFilename,object);
            save(fullfile(name,'objects_boxes.mat'),'objs_boxes');
        end
        %         ind = log(detected_objs(3,:))>7.5;
        %         detected_objs = detected_objs(:,ind);
    else
        %     fprintf('WARNING: No detection data to display\n');
        show_detection = 0;
    end
    
    if show_tracking && exist(fullfile(path,image_info.trackingFile),'file')
        data_tracking = load(fullfile(path,image_info.trackingFile),'tracksFinal');
        tracksFinal = data_tracking.tracksFinal;
        track_color = hsv(numel(tracksFinal));
        track_color = track_color(randperm(numel(tracksFinal)),:);
        tracking_obj = [];
        
        if ~isempty(filtertraj)
            tracksFinal = tracksFinal(filtertraj(1,:));
            if size(filtertraj,1)==2
                [c,~,ic] = unique(filtertraj(2,:));
                colors = lines(numel(c));
                track_color = colors(ic,:);
            end
        end
        %         ind = cellfun(@numel,{tracksFinal.tracksFeatIndxCG})<20;
        %         tracksFinal(ind)=[];
        for i = 1:numel(tracksFinal)
            ind = tracksFinal(i).seqOfEvents(1,1):tracksFinal(i).seqOfEvents(2,1);
            tracking_obj = horzcat(tracking_obj, ...
                [tracksFinal(i).tracksCoordAmpCG(1:8:end);...
                tracksFinal(i).tracksCoordAmpCG(2:8:end);...
                (ind .* ones(1, numel(ind)));...
                (i .* ones(1, numel(ind)))]);
        end
        ind = isnan(tracking_obj(1,:));
        tracking_obj(:,ind) = [];
    else
        %     fprintf('WARNING: No tracking data to display\n');
        show_tracking = 0;
    end
    
    fid = fopen(fullfile(path,image_info.bin_file));
    
    frame = double(fread(fid,width*height,pixel_type));
    scaling = [quantile(frame(mask),0.00001) quantile(frame(mask),0.99999)];
    
    % sample_time = interval*n_frames_before_freeze;
    % sample_time = 5;
    %
    % block_size = floor(sample_time/interval);
    
    % if subtract_background
    %     fprintf('Calculating background...');
    %     backgrounds = calculateBackground(image_info.bin_file, metadata, block_size);
    %     scaling = [quantile(backgrounds(:),0.01) quantile(backgrounds(:),0.99)]-mean(backgrounds(:));
    %     fprintf('done.\n');
    % end
    
    % if show_background
    %     figure,
    %     bg_img = imshow(mean(backgrounds,3), [], 'InitialMagnification', ...
    %         movie_mag);
    % end
    
    times = zeros([1 n_frames]);
    
    figure('visible',visfig),
    
    frewind(fid);
    
    backgrounds = zeros(height,width,5);
    bgw = cumsum(ones(height,width,5),3);
    
    for i=1:n_frames
        
        times(i) = (i-1)*interval;
        
        frame = fread(fid,width*height,pixel_type);
        
        if ~isempty(frame)
            frame = rot90(reshape(frame,[width height]));
            
            if make_tiff
                imwrite(imadjust(frame,stretchlim(frame,scaling),[]),fullfile(name,sprintf('frame_%04d.tif',i)));
            else
                d_frame = double(frame);
                %         img = d_frame./mean(d_frame(:));
                if subtract_background
                    background = sum((bgw .* backgrounds)/sum(1:5),3);
                    img = (d_frame - background)+mean(background(:));
                    backgrounds = cat(3,backgrounds(:,:,2:5),d_frame);
                else
                    img = d_frame;
                end
                hold off
                img = ((img - scaling(1)) / diff(scaling))*(exp(1)-1) + 1;
                img(img<1) = 1;
                img(~mask) = 0;
                imshow(log(img),'InitialMagnification', movie_mag);
                %         imshow(img, scaling, 'InitialMagnification', movie_mag);
                hold on
                if show_detection
                    ind_obj = detected_objs(5,:)==i;
                    plot(detected_objs(1,ind_obj),detected_objs(2,ind_obj),'mo');
                end
                
                if show_tracking
                    %ind_obj = tracking_obj(3,:) == i;
                    %scatter(tracking_obj(1,ind_obj),tracking_obj(2,ind_obj),[],track_color(tracking_obj(4,ind_obj),:),'filled');
                    ind_obj = tracking_obj(3,:) <= i;
                    track_ind = unique(tracking_obj(4,ind_obj));
                    for j = 1:numel(track_ind)
                        ind = ind_obj & tracking_obj(4,:) == track_ind(j);
                        trackj = tracking_obj(:,ind);
                        f = plot(trackj(1,:), trackj(2,:), 'color', track_color(track_ind(j),:),'linewidth',2);
                        f.Color(4) = 1;
                    end
                end
                
                text(5, height-5, sprintf('%s | frame: %02d | time: %.2f s', ...
                    name, i, times(i)), 'backgroundcolor','white',...
                    'FontSize',10,'Interpreter','none','margin',1,...
                    'verticalalignment','bottom');
                
                if save_movie
                    writeVideo(vid_obj, getframe(gcf));
                end
                
                drawnow;
            end
        end
    end
    if save_movie
        close(vid_obj);
    end
    fclose(fid);
end