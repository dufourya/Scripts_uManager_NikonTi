%% Information
file = 'test';
recordingtime = 5;
freezetime = 5;
moretime = 5;

% Parameters
cropFactor = 0.3;
bleachedzone = 30; %radius of bleached zone in um
fps = 10; %frame per second for movie
bit8 = 1; %convert images to 8 bit
crop10X = 0; % do not crop frame
totalTime = 1.5*60*60; %total time limit for entire experiment

configTracking = 'DIA_10X_DAPI_2x2_50ms';%'Phase_10X_DAPI'; 
configPhase = 'DIA_100X_CFP_1x1_500ms';%'Phase_100X_RFP'
configFluoCFP = 'EPI_100X_CFP_1x1_500ms';
configFluoYFP = 'EPI_100X_YFP_1x1_500ms';
configFluoRFP = 'EPI_100X_RFP_1x1_500ms';

cellstatsFile = '';

if exist(cellstatsFile,'file')
    load(cellstatsFile);
else

    mu = [2.1, 2.5, 0.95, 2.8];
    
    Sigma = [   0.3, 0.3, 0,     0;
                0.3, 0.5, 0,     0;
                0,   0,   0.01, 0;
                0,   0,   0,     0.1];
            
    cellstats = gmdistribution(mu,Sigma);
end
%%
tic
% movie acquisition and freezing
mmc.setProperty('TIPFSStatus','State','On');
waitfor(Live(mmc,configTracking));

if ~strcmp(mmc.getProperty('TIPFSStatus','State'),'On')
    error('PFS not locked!');
end
mmc.setOriginXY(mmc.getXYStageDevice());
mmc.waitForDevice(mmc.getXYStageDevice());

imgfile = sequenceAcquisitionFreeze(mmc, file, recordingtime, configTracking, fps, bit8, crop10X, freezetime, moretime);

%process the last frame to get the coordinate of the frozen cells
fprintf('Detecting cells...');
objects = getFrozenObjects(imgfile, 2, 1);
fprintf('done.\n');

%calculate the coordinates of each object from the center of the frame
%to translate it to the motorizes stage coordinates
imWidth = mmc.getImageWidth();
imHeight = mmc.getImageHeight();
pixelSize = mmc.getPixelSizeUm();

coordinates = objects(:,[1 2]);

coordinates(:,1) = (coordinates(:,1) - imWidth/2) * pixelSize;
coordinates(:,2) = (coordinates(:,2) - imHeight/2) * pixelSize;

[b, ix] = sort(coordinates(:,1).^2 + coordinates(:,2).^2);
coordinates = coordinates(ix,:);

%% configure the microscope for acquisition at 100X
mmc.setConfig('Channel',configPhase);
check15Xswitch(mmc);

q1 = questdlg('Set ND filter to 1 on Dia light. Switch phase ring to 100X. Close the epifluorescence lamp diaphragm. Add oil to objective. Turn off the lights.', 'Warning','OK','Cancel','OK');
if ~strcmp(q1,'OK')
    error('Experiment interrupted!');
end
% move the stage to the first object to help the user refocus the microscope

xcorrection = 2;
ycorrection = 26;

coordinates(:,1) = coordinates(:,1) + xcorrection;
coordinates(:,2) = coordinates(:,2) + ycorrection;

%start live acquisition for the user to focus on the first object
mmc.setProperty('TIPFSStatus','State','Off');
waitfor(Live(mmc,configPhase,coordinates));
pfs_status = mmc.getProperty('TIPFSStatus','State');

if ~strcmp(pfs_status,'Off')
    error('PFS activated!');
end
zpos = mmc.getPosition('TIZDrive');

prompt = {'Enter X correction:','Enter Y correction:','Enter minimum offset:','Enter maximum offset:'};
dlg_title = 'Input';
num_lines = 1;
defaultans = {'0','0',num2str(round(zpos)-9.6),num2str(round(zpos)+9.6)};

answer = inputdlg(prompt,dlg_title,num_lines,defaultans);

xcorrection = str2double(answer{1});
ycorrection = str2double(answer{2});
minoffset   = str2double(answer{3});
maxoffset   = str2double(answer{4});

coordinates(:,1) = coordinates(:,1) + xcorrection;
coordinates(:,2) = coordinates(:,2) + ycorrection;

close all;
drawnow;

%% get background image for Phase acquisition
imWidth = mmc.getImageWidth();
imHeight = mmc.getImageHeight();
pixelSize = mmc.getPixelSizeUm();

if exist(strcat(configPhase,'_background.tiff'),'file')
    background = imread(strcat(configPhase,'_background.tiff'));
    if sum(size(background) == [imHeight,imWidth]) ~= 2
        background = getFreezeBackground(mmc,configPhase);
        imwrite(background,strcat(configPhase,'_background.tiff'));
    end
else
    background = getFreezeBackground(mmc,configPhase);
    imwrite(background,strcat(configPhase,'_background.tiff'));
end
%% write metadata for fluorescence pictures
picmetafile = strcat(imgfile,'.fast.meta');
fid = fopen(picmetafile,'w');
fprintf(fid,'%s;%s;%s\n', 'Experiment', 'Date', date);
fprintf(fid,'%s;%s;%s\n', 'Experiment', 'Time', datestr(rem(now,1)));
fprintf(fid,'%s;%s;%s\n', 'Experiment', 'DateVector', num2str(clock));
fprintf(fid,'%s;%s;%s\n', 'Experiment', 'Computer', getenv('COMPUTERNAME'));
fprintf(fid,'%s;%s;%s\n', 'Experiment', 'User', getenv('USERNAME'));
metadata = mmc.getLoadedDevices();
for i=1:metadata.size()
    device = metadata.get(i-1);
    deviceProp = mmc.getDevicePropertyNames(char(device));
    for j = 1:deviceProp.size()
        prop = deviceProp.get(j-1);
        propVal = mmc.getProperty(char(device),char(prop));
        fprintf(fid,'%s;%s;%s\n', char(device), char(prop), char(propVal));
    end
end
fprintf(fid,'Camera;CurrentPixelSize_um;%f\n', mmc.getPixelSizeUm());
fprintf(fid,'Camera;ImageWidth;%f\n', mmc.getImageWidth());
fprintf(fid,'Camera;ImageHeight;%f\n', mmc.getImageHeight());
fprintf(fid,'ObjectiveOffset;Xcorrection;%f\n', xcorrection);
fprintf(fid,'ObjectiveOffset;Ycorrection;%f\n', ycorrection);
fclose(fid);
%%
quest = questdlg('Are you ready to continue?', 'Warning', 'Yes','No','No');
%start automated cell acquisition
if ~strcmp(quest,'Yes')
    error('Experiment Interrupted!');
end

%create cell array to store pictures
pictures = cell(size(coordinates,1),1);

j=1;
f=0;

meanz = (maxoffset + minoffset)/2;
minoffset = meanz-9.6;
maxoffset = meanz+9.6;
%%
while size(coordinates,1)>0 && toc < totalTime
    
    %get the object closest to the current stage position to minimize stage
    %movement
    
    xtarget = coordinates(1,1);
    ytarget = coordinates(1,2);
    
    mmc.setXYPosition(mmc.getXYStageDevice(),xtarget,ytarget);
    mmc.waitForDevice(mmc.getXYStageDevice());
    
    %start automated focusing and picture acquisition
    pictures{j} = autofocus_cell(mmc,cellstats,cropFactor,configPhase,...
        configFluoCFP,configFluoYFP,configFluoRFP,background,minoffset,maxoffset);
    pictures{j}.time = toc;
    
    coordinates(1,:)=[];
    
    if ~isempty(pictures{j}.RFP) || ~isempty(pictures{j}.CFP) || ~isempty(pictures{j}.YFP)
        f=f+1;
        %calculate the distance of the remaining objects from the
        %center of the bleached zone
        xtarget_all = coordinates(:,1);
        ytarget_all = coordinates(:,2);
        d = sqrt((xtarget_all-pictures{j}.XYcoord(1)).^2 + (ytarget_all-pictures{j}.XYcoord(2)).^2);
        %remove bleached objects from the queue
        coordinates(d<bleachedzone,:)=[];
        
        %add the object z coordinate to the list and calculate the
        %mean z coordinate as a starting pint for the next object
        meanz = (maxoffset + minoffset)/2;
        meanz = meanz + (pictures{j}.Zcoord-meanz)/10;
        minoffset = meanz-9.6;
        maxoffset = meanz+9.6;
        
        fprintf('Area: %3g, Length: %3g, Solidity: %3g, NormVar: %3g\n',pictures{j}.Area,pictures{j}.MajorAxisLength,...
            pictures{j}.Solidity, pictures{j}.NormVar);
    end
    fprintf('%d objects captured (z = %d), %d objects or %d minutes remaining\n',f, pictures{j}.Zcoord,size(coordinates,1),round((totalTime-toc)/60));
    j=j+1;
end
%
% remove objects with no picture taken and save data
pictures(cellfun('isempty',pictures))=[];
pictures = horzcat(pictures{:});
pictures(cellfun('isempty',{pictures.Phase}))=[];
save(strcat(imgfile,'.fast.mat'),'pictures');

% calculate the statistics of the captured objects
ind = ~cellfun(@isempty,{pictures.CFP}) | ~cellfun(@isempty,{pictures.YFP}) | ~cellfun(@isempty,{pictures.RFP});
data = [[pictures(ind).Area];[pictures(ind).MajorAxisLength];[pictures(ind).Solidity];[pictures(ind).NormVar]];
cellstats = fitgmdist(data',1);
save(strcat(imgfile,'.cellstats.mat'),'cellstats');