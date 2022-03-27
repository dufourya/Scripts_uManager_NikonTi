file = '311_R400_I5_4_OD_0.3';

%start timelapse acquisition of swimming cells
recordingtime = 300; %length of movie in seconds


exposuretime = 50; %camera exposure time in milliseconds
lightintensity = 8; %light intensity for phase contrast


%%
%set the field of view and focus the cells
waitfor(Live(mmc));

load('background150.mat');
% 
close all
drawnow;

sequenceAcquisitionFreeze(mmc, file, recordingtime, exposuretime, lightintensity);
tic

%%
%process the last frame to get the coordinate of the frozen cells
objects = getFrozenObjects(file);

%configure the microscope for acquisition at 150X
q = questdlg('Switch objective to 150 X. Switch phase ring. Turn off the light. Close the mercury lamp diaphragm.', 'Warning','OK','Cancel','OK');
%%
%start acquisition of single cell fluorescence
if strcmp(q,'OK') 
%parameters for cell detection
    cellstats.meanArea = 350;
    cellstats.stdArea = 50;
    cellstats.meanMajorAxisLength = 35;
    cellstats.stdMajorAxisLength = 10;
    cellstats.meanEccentricity = 0.95;
    cellstats.stdEccentricity = 0.05;
    cellstats.meanMeanIntensity = 0;
    cellstats.stdMeanIntensity = 0.001;
    cellstats.stddevxy = 0.25;
% load('cellstats.mat');
    
%parameters for picture acquisition
    exposure = 150; %phase contrast exposure in msec
    intensity = 20; %light intensity for phase contrast
    gain = 20; %camera gain for phase contrast
    epiexposure = 250; %exposure time for epifluorescence
    epigain = 30; %camera gain for phase epifluorescence
    blockepi = '1-CFPHQ'; %filter block for epifluorescence
    %bleachedzone = 100; %radius of the bleached zone in micrometer
    
    pixelsize = 1.3051; %pixel size at 10X magnification
    
    %calculate z-score of object sizes extracted from the last frame at 10X
    z = (objects(:,3)-mean(objects(:,3)))./std(objects(:,3));
    %remove objects of unusual sizes
    objects(abs(z)>3,:)=[];
    
    %calculate the coordinates of each object from the center of the frame
    %to translate it to the motorizes stage coordinates
    coordinates = objects(:,[1 2]);
    [b, ix] = sort((coordinates(:,1)-512).^2 + (coordinates(:,2)-512).^2);
    
    %correction factor for the discrepency between the 10X and 150X center
    %of frame
    xcorrection = 27;
    ycorrection = 27;
    
    %move the stage to the first object to help the user refocus the
    %microscope
    x = coordinates(ix(1),1);
    y = coordinates(ix(1),2);
    
    xtarget = pixelsize * (-1024/2 + xcorrection + x);
    ytarget = pixelsize * (-1024/2 + ycorrection + y);
    
    mmc.setXYPosition('XYStage',xtarget,ytarget );
    
    %start live acquisition for the user to focus on the first object
    waitfor(Live(mmc));
    
    quest = questdlg('Are you ready to continue?', 'Warning', 'Yes','No','No');

    %start automated cell acquisition
    if strcmp(quest,'Yes')
        
        %create cell array to store pictures
        pictures = cell(size(coordinates,1),1);
        
        %get z coordinates
        pos = mmc.getPosition('ZStage');
        newpos = [pos pos pos];
        
        currentcoord = coordinates(ix(1),:);
        j=1;
        f=0;
        
        close all;
        drawnow;
        
        while size(coordinates,1) > 0
            
            close all;
            fprintf('%d objects captured, %d objects remaining\n',f,size(coordinates,1));
            
            %get the object closest to the current stage position to
            %minimize stage position
            [b, ix] = sort((coordinates(:,1)-currentcoord(1)).^2 + (coordinates(:,2)-currentcoord(2)).^2);
            currentcoord = coordinates(ix(1),:);
            
            %start automated focusing and picture acquisition
            pictures{j} = autofocus_cell(mmc,exposure, intensity, gain, epiexposure, epigain, blockepi,pos,coordinates(ix(1),:),cellstats,xcorrection,ycorrection,background150,pixelsize);
            pictures{j}.time = toc;
            %delete current object from queue
            coordinates(ix(1),:) = [];           
            
            if ~isempty(pictures{j}.Phase)
                %calculate the distance of the remaining objects from the
                %center of the bleached zone
                %d = (coordinates(:,1)-pictures{j}.XYcoord(1)).^2 + (coordinates(:,2)-pictures{j}.XYcoord(2)).^2;
                %remove bleached objects from the queue
                %coordinates(sqrt(d)*pixelsize < bleachedzone,:)=[];
                
                %add the object z coordinate to the list and calculate the
                %mean z coordinate as a starting pint for the next object
                newpos = [newpos pictures{j}.Zcoord];
                pos = mean(newpos);
                f=f+1;
            end
            j=j+1;
        end
        
        %remove objects with no picture taken and save data
        pictures(cellfun('isempty',pictures))=[];
        pictures = horzcat(pictures{:});
        pictures(cellfun('isempty',{pictures.Phase}))=[];
        save(strcat(file,'.mat'),'pictures');
        
    end
end
%%
%calculate the statistics of the captured objects
ind = [];
meanepi = [];
for i=1:numel(pictures)
    if ~isempty(pictures(i).YFP)
        ind = [ind i];
        meanepi = [meanepi mean(pictures(i).YFP(:))];
    end
end

cellstats.meanArea = mean([pictures(ind).Area]);
cellstats.stdArea = std([pictures(ind).Area]);
cellstats.meanMajorAxisLength = mean([pictures(ind).MajorAxisLength]);
cellstats.stdMajorAxisLength = std([pictures(ind).MajorAxisLength]);
cellstats.meanEccentricity = mean([pictures(ind).Eccentricity]);
cellstats.stdEccentricity = std([pictures(ind).Eccentricity]);
cellstats.meanMeanIntensity = mean([pictures(ind).MinIntensity]);
cellstats.stdMeanIntensity = std([pictures(ind).MinIntensity]);
devxy = 512-vertcat(pictures(ind).Centroid);
cellstats.meandevxy = mean(devxy);
cellstats.stddevxy = std(sqrt(devxy(:,1).^2+devxy(:,2).^2));

save(strcat(file,'.cellstats.mat'),'cellstats');

close all;