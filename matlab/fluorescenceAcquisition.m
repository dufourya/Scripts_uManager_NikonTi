function fluorescenceAcquisition(mmc, strain, configPhase, configFluo)

    if iscell(strain)
        strain = strjoin(strain,'_');
    end
    
    if regexp(strain,'[^\w()_-]')
        error('Invalid file name!');
    end
    
    mmc.setConfig('System','Startup');
    mmc.waitForSystem();
    
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
Live(mmc,configPhase);

mmc.setOriginXY('XYStage');

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
%%

if mmc.getBytesPerPixel == 2
    pixelType = 'uint16';
else
    pixelType = 'uint8';
end

screensize = get( groot, 'Screensize' );
figure('Name','Acquisition',...
    'Position',[ceil(screensize(3)*0.1) ceil(screensize(4)*0.1) ceil(screensize(3)*0.8) ceil(screensize(4)*0.5)]);
nmsg = 0;

for nimage = 1:size(poslist,1)
    
    ometiff = zeros(mmc.getImageWidth, mmc.getImageHeight, numel(configFluo)+1, 1, 1, 'uint16');
    metadata = createMinimalOMEXMLMetadata(ometiff,'XYCZT');
    metadata.setImageAcquisitionDate(ome.xml.model.primitives.Timestamp(string(org.joda.time.Instant)),0);
    
    fprintf(repmat('\b',1,nmsg));
    msg = sprintf('Acquiring position %d of %d...', [nimage, size(poslist,1)]);
    fprintf(msg);
    nmsg=numel(msg);
    
    % Phase
    mmc.setXYPosition('XYStage',poslist(nimage,1),poslist(nimage,2));
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
    phase = uint16(double(img_flat-img_dark)./phase_flat);
    
    ometiff(:,:,1,1,1) = phase;
    metadata.setChannelName(configPhase,0,0);
    phase_ref = imref2d(size(phase));
    phase_fft = fft2(phase);
    
    subplot(1,numel(configFluo)+1,1);
    imshow(phase,[]);
    title(configPhase,'Interpreter','none');
    xlabel(sprintf('Saturation: %d pixels\n',sum(phase(:) == max(phase(:)))));
    drawnow;
    
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
    metadata.setPlanePositionX(ome.units.quantity.Length(java.lang.Double(mmc.getXPosition('XYStage')), ome.units.UNITS.MICROMETER), 0,0)
    metadata.setPlanePositionY(ome.units.quantity.Length(java.lang.Double(mmc.getYPosition('XYStage')), ome.units.UNITS.MICROMETER), 0,0)
    metadata.setPlanePositionZ(ome.units.quantity.Length(java.lang.Double(mmc.getProperty('TIPFSOffset','Position')), ome.units.UNITS.MICROMETER), 0,0)
    pixelSize = ome.units.quantity.Length(java.lang.Double(mmc.getPixelSizeUm), ome.units.UNITS.MICROM);
    metadata.setPixelsPhysicalSizeX(pixelSize, 0);
    metadata.setPixelsPhysicalSizeY(pixelSize, 0);
    metadata.setPixelsPhysicalSizeZ(pixelSize, 0);
    bfsave(ometiff,char(fullfile(strain,sprintf('%.3d_slide',i),sprintf('%s_%s_t0001xy%.3d.ome.tiff',file_prefix,strain,nimage))),'dimensionOrder', 'XYCZT', 'metadata', metadata, 'Compression', 'LZW');
end

fprintf('\nDone\n');
return
