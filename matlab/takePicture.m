function img = takePicture(mmc, config, img_name, plotimg)


if nargin < 4
    plotimg = 0;
end

if nargin < 3 || isempty(img_name)
    saveimg = 0;
    img_name = '';
else
    saveimg = 1;
end

mmc.setConfig('Channel',config);
check15Xswitch(mmc);

if mmc.getBytesPerPixel == 2
    pixelType = 'uint16';
else
    pixelType = 'uint8';
end

mmc.setAutoShutter(0);
mmc.waitForImageSynchro();
mmc.snapImage();
img_dark = mmc.getImage();
img_dark = typecast(img_dark, pixelType);
img_dark = rotateFrame(img_dark,mmc);

mmc.setAutoShutter(1);

mmc.snapImage();
img=mmc.getImage();

img = typecast(img, pixelType);
img=rotateFrame(img,mmc);
%     clipped = img==max(img(:));
img = img - img_dark;
%     w=mmc.getImageWidth();
%     h=mmc.getImageHeight();

%     [path, img_name, ~] = fileparts(img_name);


%     if cropimg
%         img = img((w/2-w/4+1):(w/2+w/4), (h/2-h/4+1):(h/2+h/4));
%         metadata.set('Camera', 'ImageWidth', sprintf('%f', w/2));
%         metadata.set('Camera', 'ImageHeight', sprintf('%f',h/2));
%     end

if saveimg
    metadata = Metadata(fullfile(strcat(img_name, FileInfo.metaExt)));
    metadata.create(mmc);
    imwrite(img, fullfile(strcat(img_name,'.tiff')), 'TIFF');
    metadata.write();
end

if plotimg
    screensize = get( groot, 'Screensize' );
    figure('Name',img_name,...
        'Position',[ceil(screensize(3)/10) ceil(screensize(4)/2)-ceil(screensize(3)*0.2) ceil(screensize(3)*0.8) ceil(screensize(3)*0.4)]);
    subplot(1,2,1), hold on,
    imshow(img,[]);
    %         red = cat(3, ones(size(img)), zeros(size(img)), zeros(size(img)));
    %         h = imshow(red);
    %         set(h, 'AlphaData', clipped);
    title(config,'Interpreter','none');
    subplot(1,2,2),
    [N, edges] = histcounts(img(:),0:2^8:2^16);
    bar(edges(1:end-1)+2^7,log10(N),1,'k');
    xlabel('Intensity');
    ylabel('Log_{10}(Counts)');
    xlim([0 65535]);
    axis square;
    title('Pixel intensity histogram');
end
end