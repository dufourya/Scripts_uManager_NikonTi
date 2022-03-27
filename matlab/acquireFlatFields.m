function flats = acquireFlatFields(mmc,nimages,configPhase,configFluo)

if exist('flat_fields\flat_fields.mat', 'file')
    load('flat_fields\flat_fields.mat','flats');
    flatconfigs = fieldnames(flats);
    flatconfigs_short = regexprep(flatconfigs,'_\d+sola','');
    config_short = regexprep(cat(2,configPhase,configFluo),'_\d+sola','');
    if ~sum(~ismember(config_short,flatconfigs_short))
        return;
    end
end

%%
if nargin < 4 || isempty(configFluo)
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
        configFluo_short = regexprep(configFluo,'_\d+sola','');
        %         fprintf('Taking fluorescence pictures in channel: %s\n', configFluo{:});
    end
end

q0 = questdlg('Place FLAT FIELD slide on stage. Turn off the lights.', 'Warning','OK','Cancel','OK');

if ~strcmp(q0,'OK')
    error('Acquisition aborted');
end

waitfor(Live(mmc,configPhase));
mmc.setOriginXY('XYStage');

if ~strcmp(mmc.getProperty('TIPFSStatus','State'),'On')
    error('Aborted! PFS needs to be turned ON.');
end
drawnow;
%%
if mmc.getBytesPerPixel == 2
    pixelType = 'uint16';
else
    pixelType = 'uint8';
end

fprintf('Calibrating exposure...\n');
flats.(genvarname(configPhase)) = [];
for k = 1:numel(configFluo)
    flats.(genvarname(configFluo_short{k})) = [];
    sola.(genvarname(configFluo_short{k})) = calibrateWhiteLevel(mmc,configFluo{k});
end
fprintf('done.\n');

%%
bleachdiameter = 500;
paddiam = 5000;

n = fix(paddiam/bleachdiameter)*2;
[xcoord, ycoord] = meshgrid(1:2:n,1:2:n);
xcoord(1:2:end,:) = xcoord(1:2:end,:) + 1;
ycoord = ycoord*sqrt(3)/2;
xcoord = xcoord * bleachdiameter;
ycoord = ycoord * bleachdiameter;

xcoord = xcoord - xcoord(fix(n/4)+1,fix(n/4)+1);
ycoord = ycoord - ycoord(fix(n/4)+1,fix(n/4)+1);
xcoord = xcoord(:);
ycoord = ycoord(:);
xydist = sqrt(xcoord.^2 + ycoord.^2);

ind = xydist <= min(max(abs(xcoord)),max(abs(ycoord)));

xcoord = xcoord(ind);
ycoord = ycoord(ind);
xydist = xydist(ind);

xprev = 0;
yprev = 0;

poslist = [];

while numel(xydist)>0
    currdist = sqrt((xcoord - xprev).^2 + (ycoord - yprev).^2);
    [~,k] = min(xydist+currdist);
    poslist = cat(1,poslist,[xcoord(k) ycoord(k)]);
    xprev = xcoord(k);
    yprev = ycoord(k);
    xcoord(k) = [];
    ycoord(k) = [];
    xydist(k) = [];
end

% plot(poslist(:,1),poslist(:,2))
%%
nimages = max(1,min(nimages,size(poslist,1)));
stdimages = zeros(nimages,numel(configFluo)+1);

for i = 1:nimages
    
    fprintf('Acquiring flat field %d...',i);
    mmc.setXYPosition('XYStage',poslist(i,1),poslist(i,2));
    
    % Phase
    img = getImage(mmc, configPhase, 0);
    flats.(genvarname(configPhase)) = cat(3, flats.(genvarname(configPhase)), img);
    stdimages(i,1) = std(double(img(:)));
    
    for k = 1:numel(configFluo)
        img = getImage(mmc, configFluo{k}, sola.(genvarname(configFluo_short{k})));
        flats.(genvarname(configFluo_short{k})) = cat(3, flats.(genvarname(configFluo_short{k})), img);
        stdimages(i,k+1) = std(double(img(:)));
    end
    
    fprintf('done.\n');
    %         pause(0.01);
end

mmc.setXYPosition('XYStage',poslist(1,1),poslist(1,2));

% detect outliers
f1 = fitgmdist(stdimages,1,'RegularizationValue',10^-5);
f2 = fitgmdist(stdimages,2,'RegularizationValue',10^-5);
c = stdimages(:,1)>0;
if f2.BIC < f1.BIC
    [~,k] = max(f2.ComponentProportion);
    c = c & f2.cluster(stdimages) == k;
end

fprintf('Discarding %d bad flats out of %d acquired flats!\n',[sum(~c), nimages]);

% average flats
flats.(genvarname(configPhase)) = nanmean(double(flats.(genvarname(configPhase))(:,:,c)),3);
for k = 1:numel(configFluo)
    flats.(genvarname(configFluo_short{k})) = nanmean(double(flats.(genvarname(configFluo_short{k}))(:,:,c)),3);
end

%% Plots
screensize = get( groot, 'Screensize' );
h = figure('Name','Flat fields',...
    'Position',[ceil(screensize(3)/10) ceil(screensize(4)/2)-ceil(screensize(3)*0.2) ceil(screensize(3)*0.8) ceil(screensize(3)*0.4)]);

r = intmin(pixelType):((intmax(pixelType)-intmin(pixelType))/256):intmax(pixelType);
s = (intmax(pixelType)-intmin(pixelType))/512;

subplot(2,numel(configFluo)+1,1), hold on,
image(flats.(genvarname(configPhase)),'CDataMapping','scaled','Alphadata',flats.(genvarname(configPhase))~=max(flats.(genvarname(configPhase))(:)));
axis image;
axis off;
title(configPhase,'Interpreter','none');

subplot(2,numel(configFluo)+1,numel(configFluo)+2),
[N, edges] = histcounts(flats.(genvarname(configPhase))(:),r);
bar(edges(1:end-1)+s,log10(N),1,'k');
xlabel('Intensity');
ylabel('Log_{10}(Counts)');
xlim([intmin(pixelType) intmax(pixelType)]);
axis square;

for k = 1:numel(configFluo)
    
    subplot(2,numel(configFluo)+1,k+1),
    image(flats.(genvarname(configFluo_short{k})),'CDataMapping','scaled','Alphadata',flats.(genvarname(configFluo_short{k}))~=max(flats.(genvarname(configFluo_short{k}))(:)));
    axis image;
    axis off;
    title(configFluo_short{k},'Interpreter','none');
    
    subplot(2,numel(configFluo)+1,numel(configFluo)+k+2),
    [N, edges] = histcounts(flats.(genvarname(configFluo_short{k}))(:),r);
    bar(edges(1:end-1)+s,log10(N),1,'k');
    xlabel('Intensity');
    ylabel('Log_{10}(Counts)');
    xlim([intmin(pixelType) intmax(pixelType)]);
    axis square;
    
end

drawnow;

q1 = questdlg('Do the flat fields look good?', 'Warning','Yes','No','Yes');

if ~strcmp(q1,'Yes')
    error('Acquisition aborted');
else
    if ~exist('flat_fields','dir')
        mkdir('flat_fields');
    end
    save('flat_fields\flat_fields.mat','flats');
    t = clock;
    file_prefix = sprintf('%02d%02d%02d_%02d%02d',t(1:5));
    set(h,'PaperPositionMode','auto');
    print(h,fullfile('flat_fields',sprintf('%s_flat_fields.png',file_prefix)),'-dpng','-r300','-noui');
end
end

function img = getImage(mmc, config, sola)

if mmc.getBytesPerPixel == 2
    pixelType = 'uint16';
else
    pixelType = 'uint8';
end

mmc.setConfig('Channel',config);
mmc.setProperty('Sola','White_Level',sola)
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
img = typecast(mmc.getImage(),pixelType);
img = rotateFrame(img,mmc)-img_dark;

end