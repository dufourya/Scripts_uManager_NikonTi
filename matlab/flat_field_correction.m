function flat_field_correction(do_plots)
    
    % File created by Yann Dufour at Yale University.
    
    % Script for flat field correction of fluorescence images taken with
    % the multiD acquisition engine in microManager.
    
    % Flat field images must be stored in folder with names containing:
    % 'yellow', 'red', 'blue', or 'dark'.
    
    % The scripts goes through each folder and finds the corresponding
    % images in TIFF format and calculate the median intensities over the
    % field of view for each channel.
    
    % Image files must contain either 'Phase', 'YFP', 'CFP', or 'RFP' in
    % their names.
    
    % Images of cells in the remaining folders are read and grouped by
    % channels.
    
    % The shape of the background intensity is determined for each channel
    % as an additional way to determine the flat field.
    
    % The flat field images and the background images are correlated to
    % correct for additional intensity offset and normalize the flat field
    % correction (between 0 and ~1).
    
    % Each image is then corrected with the flat field reference and saved
    % in a different folder structure in the 'microbeTracker' folder.
    
    % A folder is created for each strain/condition containing subfolders
    % for the 'Phase', 'YFP', 'CFP, and 'RFP' images.
    
    if nargin < 1
        do_plots = 1;
    end
    
    % define folders containing flat field images
    yellow_dir = dir('yellow*');
    blue_dir = dir('red*');
    red_dir = dir('blue*');
    dark_dir = dir('dark*');
    
    YFP_flat = [];
    RFP_flat = [];
    CFP_flat = [];
    Phase_flat = [];
    DARK = [];
    
    % find and read flat field images
    for i = 1:numel(yellow_dir)
        if yellow_dir(i).isdir
            f = dir(yellow_dir(i).name);
            for j = 1:numel(f)
                if ~isempty(strfind(f(j).name,'YFP'))
                    img = imread(fullfile(yellow_dir(i).name,f(j).name));
                    YFP_flat = cat(3,YFP_flat,img);
                elseif ~isempty(strfind(f(j).name,'Phase'))
                    img = imread(fullfile(yellow_dir(i).name,f(j).name));
                    Phase_flat = cat(3,Phase_flat,img*(2^15/mean(img(:))));
                end
            end
        end
    end
    
    for i = 1:numel(blue_dir)
        if blue_dir(i).isdir
            f = dir(blue_dir(i).name);
            for j = 1:numel(f)
                if ~isempty(strfind(f(j).name,'CFP'))
                    img = imread(fullfile(blue_dir(i).name,f(j).name));
                    CFP_flat = cat(3,CFP_flat,img);
                elseif ~isempty(strfind(f(j).name,'Phase'))
                    img = imread(fullfile(blue_dir(i).name,f(j).name));
                    Phase_flat = cat(3,Phase_flat,img*(2^15/mean(img(:))));
                end
            end
        end
    end
    
    for i = 1:numel(red_dir)
        if red_dir(i).isdir
            f = dir(red_dir(i).name);
            for j = 1:numel(f)
                if ~isempty(strfind(f(j).name,'RFP'))
                    img = imread(fullfile(red_dir(i).name,f(j).name));
                    RFP_flat = cat(3,RFP_flat,img);
                elseif ~isempty(strfind(f(j).name,'Phase'))
                    img = imread(fullfile(red_dir(i).name,f(j).name));
                    Phase_flat = cat(3,Phase_flat,img*(2^15/mean(img(:))));
                end
            end
        end
    end
    
    for i = 1:numel(dark_dir)
        if dark_dir(i).isdir
            f = dir(dark_dir(i).name);
            for j = 1:numel(f)
                if ~isempty(strfind(f(j).name,'.tif'))
                    img = imread(fullfile(red_dir(i).name,f(j).name));
                    DARK = cat(3,DARK,img);
                end
            end
        end
    end
    
    % gaussian filter and median intensity of flat field images
    h = fspecial('gaussian',21 , 5);
    
    if ~isempty(DARK)
        DARK = imfilter(mean(double(DARK),3),h,'symmetric','conv');
    else
        DARK = 100;
    end
    
    YFP_flat = imfilter(double(median(YFP_flat-DARK,3)),h,'symmetric');
    YFP_flat = YFP_flat / quantile(YFP_flat(:),0.95);
    CFP_flat = imfilter(double(median(CFP_flat-DARK,3)),h,'symmetric');
    CFP_flat = CFP_flat / quantile(CFP_flat(:),0.95);
    RFP_flat = imfilter(double(median(RFP_flat-DARK,3)),h,'symmetric');
    RFP_flat = RFP_flat / quantile(RFP_flat(:),0.95);
    Phase_flat = imfilter(double(median(Phase_flat-DARK,3)),h,'symmetric');
    Phase_flat = Phase_flat / quantile(Phase_flat(:),0.50);
    
    if sum(RFP_flat(:)<=0) || sum(CFP_flat(:)<=0) || sum(YFP_flat(:)<=0)...
            || sum(Phase_flat(:)<=0)
        error('Negative or zero values in flat field images');
    end
    
    % plot flat field images
    if do_plots
        figure,
        subplot(2,2,1),
        imshow(Phase_flat,[0 max(Phase_flat(:))]);
        title('Phase flat field');
        subplot(2,2,2),
        imshow(CFP_flat,[0 max(CFP_flat(:))]);
        title('CFP flat field');
        subplot(2,2,3),
        imshow(YFP_flat,[0 max(YFP_flat(:))]);
        title('YFP flat field');
        subplot(2,2,4),
        imshow(RFP_flat,[0 max(RFP_flat(:))]);
        title('RFP flat field');
        drawnow;
    end
    
    % find the remaining folders containing cell images
    f = dir;
    ind = cellfun(@isempty,regexpi({f.name},'yellow')) & ...
        cellfun(@isempty, regexpi({f.name},'blue')) & ...
        cellfun(@isempty,regexpi({f.name},'red'))& ...
        cellfun(@isempty,regexpi({f.name},'dark')) & ...
        cellfun(@isempty,regexpi({f.name},'microbeTracker')) & ...
        cellfun(@isempty,strfind({f.name},'.'));
    f = f(ind);
    
    % initialize arrays to store images
    all_Phase = zeros(size(Phase_flat,1),size(Phase_flat,2),numel(f),'uint16');
    all_CFP = zeros(size(Phase_flat,1),size(Phase_flat,2),numel(f),'uint16');
    all_YFP = zeros(size(Phase_flat,1),size(Phase_flat,2),numel(f),'uint16');
    all_RFP = zeros(size(Phase_flat,1),size(Phase_flat,2),numel(f),'uint16');
    all_Target_files = cell(numel(f),2);
    
    % read and store all images
    for i = 1:numel(f)
        fi = dir(f(i).name);
        c = strsplit(f(i).name,'_');
        all_Target_files{i,1} = strjoin(c(1:end-1),'_');
        all_Target_files{i,2} = c{end};
        
        fprintf('Reading images in %s\n',f(i).name);
        for j = 1:numel(fi)
            if ~isempty(strfind(fi(j).name,'YFP'))
                YFP = imread(fullfile(f(i).name,fi(j).name));
                all_YFP(:,:,i) = YFP-DARK;
            elseif ~isempty(strfind(fi(j).name,'CFP'))
                CFP = imread(fullfile(f(i).name,fi(j).name));
                all_CFP(:,:,i) = CFP-DARK;
            elseif ~isempty(strfind(fi(j).name,'RFP'))
                RFP = imread(fullfile(f(i).name,fi(j).name));
                all_RFP(:,:,i) = RFP-DARK;
            elseif ~isempty(strfind(fi(j).name,'Phase'))
                Phase = imread(fullfile(f(i).name,fi(j).name));
                all_Phase(:,:,i) = Phase-DARK;
            end
        end
    end
    
    % calculate background image by taking median intensities
    fprintf('Calculating background and normalizing flat field images...');
    
    h = fspecial('gaussian',41 , 10);
    m_Phase = imfilter(median(all_Phase,3),h,'same','symmetric');
    m_YFP = imfilter(median(all_YFP,3),h,'same','symmetric');
    m_CFP = imfilter(median(all_CFP,3),h,'same','symmetric');
    m_RFP = imfilter(median(all_RFP,3),h,'same','symmetric');
    
    % linear fit of flat field with background intensity to determine
    % intensity offset (in addition to dark current)
    opts = fitoptions('poly1','Robust','Bisquare');
    pPhase = fit(Phase_flat(:), double(m_Phase(:)),'poly1',opts);
    pCFP = fit(CFP_flat(:), double(m_CFP(:)),'poly1',opts);
    pRFP = fit(RFP_flat(:), double(m_RFP(:)),'poly1',opts);
    pYFP = fit(YFP_flat(:), double(m_YFP(:)),'poly1',opts);
    
    % plot data and fit
    if do_plots
        figure,
        subplot(2,2,1),
        imshow(m_Phase,[]);
        title('Background Phase');
        subplot(2,2,2),
        imshow(m_CFP,[]);
        title('Background CFP');
        subplot(2,2,3),
        imshow(m_YFP,[]);
        title('Background YFP');
        subplot(2,2,4),
        imshow(m_RFP,[]);
        title('Background RFP');
        
        figure,
        subplot(2,2,1),
        scatter(Phase_flat(1:10000:end), m_Phase(1:10000:end),'.');
        axis([0 max(Phase_flat(:)) 0 max(m_Phase(:))]);
        title('Phase');
        xlabel('Phase flat field intensity');
        ylabel('Phase background intensity');
        hold on,
        plot(pPhase);
        subplot(2,2,2),
        scatter(CFP_flat(1:10000:end), m_CFP(1:10000:end),'.');
        axis([0 max(CFP_flat(:)) 0 max(m_CFP(:))]) ;
        title('CFP');
        xlabel('CFP flat field intensity');
        ylabel('CFP background intensity');
        hold on,
        plot(pCFP);
        subplot(2,2,3),
        scatter(RFP_flat(1:10000:end), m_RFP(1:10000:end),'.');
        axis([0 max(RFP_flat(:)) 0 max(m_RFP(:))]) ;
        title('RFP');
        xlabel('RFP flat field intensity');
        ylabel('RFP background intensity');
        hold on,
        plot(pRFP);
        subplot(2,2,4),
        scatter(YFP_flat(1:10000:end), m_YFP(1:10000:end),'.');
        axis([0 max(YFP_flat(:)) 0 max(m_YFP(:))]) ;
        title('YFP');
        xlabel('YFP flat field intensity');
        ylabel('YFP background intensity');
        hold on,
        plot(pYFP);
        drawnow;
    end
    
    % re-normaliztion of flat field images
    YFP_flat = (YFP_flat + pYFP.p2/pYFP.p1)/(1 + pYFP.p2/pYFP.p1);
    CFP_flat = (CFP_flat + pCFP.p2/pCFP.p1)/(1 + pCFP.p2/pCFP.p1);
    RFP_flat = (RFP_flat + pRFP.p2/pRFP.p1)/(1 + pRFP.p2/pRFP.p1);
    Phase_flat = (Phase_flat + pPhase.p2/pPhase.p1)/(1 + pPhase.p2/pPhase.p1);
    
    % plot new flat field images
    if do_plots
        figure,
        subplot(2,2,1),
        imshow(Phase_flat,[0 max(Phase_flat(:))]);
        title('New flat Phase');
        subplot(2,2,2),
        imshow(CFP_flat,[0 max(CFP_flat(:))]);
        title('New flat CFP');
        subplot(2,2,3),
        imshow(RFP_flat,[0 max(RFP_flat(:))]);
        title('New flat YFP');
        subplot(2,2,4),
        imshow(YFP_flat,[0 max(YFP_flat(:))]);
        title('New flat RFP');
        drawnow;
    end
    
    fprintf('done.\nWriting corrected images...\n');
    
    % create new folder structure with corrected images
    if ~exist('microbeTracker','dir')
        mkdir('microbeTracker');
    end
    
    % correct and write images
    [optimizer, metric] = imregconfig('multimodal');
    optimizer.MaximumIterations = 100;
    optimizer.GrowthFactor = 10;
    optimizer.Epsilon = 0.1;
    optimizer.InitialRadius =0.01;
    
    
    for i = 1:size(all_Phase,3)
        Phase = uint16(double(all_Phase(:,:,i)) ./ Phase_flat);
        YFP = uint16(double(all_YFP(:,:,i)) ./ YFP_flat);
        CFP = uint16(double(all_CFP(:,:,i)) ./ CFP_flat);
        RFP = uint16(double(all_RFP(:,:,i)) ./ RFP_flat);
        
        if sum(Phase(:))>0
            target_folder = all_Target_files{i,1};
            fprintf('%s\n', target_folder);
            if ~exist(fullfile('microbeTracker',target_folder),'dir');
                mkdir(fullfile('microbeTracker',target_folder));
                mkdir(fullfile('microbeTracker',target_folder,'YFP'));
                mkdir(fullfile('microbeTracker',target_folder,'CFP'));
                mkdir(fullfile('microbeTracker',target_folder,'RFP'));
                mkdir(fullfile('microbeTracker',target_folder,'Phase'));
            end
            
            file_nb = all_Target_files{i,2};
            
            invertedPhase = imcomplement(Phase);
            
            tfYFP = imregtform(YFP, invertedPhase, 'translation', optimizer, metric);
            tfCFP = imregtform(CFP, invertedPhase, 'translation', optimizer, metric);
            tfRFP = imregtform(RFP, invertedPhase, 'translation', optimizer, metric);
            
            if sqrt(sum(tfYFP.T(3,[1 2]).^2)) < 10 && sqrt(sum(tfYFP.T(3,[1 2]).^2)) > 0
                YFP = imwarp(YFP, tfYFP, 'OutputView', imref2d(size(YFP)),'FillValues', mode(YFP(:)));
            end
            if sqrt(sum(tfRFP.T(3,[1 2]).^2)) < 10 && sqrt(sum(tfRFP.T(3,[1 2]).^2)) > 0
                RFP = imwarp(RFP, tfRFP, 'OutputView', imref2d(size(RFP)),'FillValues', mode(RFP(:)));
            end
            if sqrt(sum(tfCFP.T(3,[1 2]).^2)) < 10 && sqrt(sum(tfCFP.T(3,[1 2]).^2)) > 0
                CFP = imwarp(CFP, tfCFP, 'OutputView', imref2d(size(CFP)),'FillValues', mode(CFP(:)));
            end
            
            imwrite(Phase,fullfile('microbeTracker',target_folder,'Phase',...
                strcat('Phase_',file_nb,'.tiff')));
            imwrite(YFP,fullfile('microbeTracker',target_folder,'YFP',...
                strcat('YFP_',file_nb,'.tiff')));
            imwrite(CFP,fullfile('microbeTracker',target_folder,'CFP',...
                strcat('CFP_',file_nb,'.tiff')));
            imwrite(RFP,fullfile('microbeTracker',target_folder,'RFP',...
                strcat('RFP_',file_nb,'.tiff')));
        end
    end
    fprintf('done.\n');
end
