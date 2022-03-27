function data = autofocus_cell(mmc,cellstats,cropFactor,configPhase,configFluoCFP,configFluoYFP,configFluoRFP,background,minoffset, maxoffset)

diagnostic_plots = 1;

mmc.setConfig('Channel',configPhase);

imWidth = mmc.getImageWidth();
imHeight = mmc.getImageHeight();
pixelSize = mmc.getPixelSizeUm();

xPosition = mmc.getXPosition(mmc.getXYStageDevice());
yPosition = mmc.getYPosition(mmc.getXYStageDevice());
mmc.setProperty('TIPFSStatus','State','Off');

%     zPosition = str2double(char(mmc.getProperty('TIPFSOffset','Position')));

if mmc.getBytesPerPixel == 2
    pixelType = 'uint16';
else
    pixelType = 'uint8';
end

data = struct('Area',[],'Eccentricity',[],'MajorAxisLength',[],'MinIntensity',[],'Phase',[],'NormVar',[],'YFP',[],'CFP',[],'RFP',[],'Zcoord',[],'XYcoord',[],'time',[],'Centroid',[]);
%data = struct('Area',[],'Centroid',[],'Eccentricity',[],'BoundingBox',[],'MajorAxisLength',[],'MinIntensity',[],'Phase',[],'YFP',[],'CFP',[],'RFP',[],'Zcoord',[],'XYcoord',[],'time',[]);

% %%setup acquisition for phase 150X
% mmc.setAutoShutter(0);
% mmc.setShutterDevice('TIDiaShutter');
% mmc.setProperty('Andor', 'Gain', num2str(gain)) % Must be between 4 and 300 (1000)
% mmc.setProperty('TIFilterBlock1', 'Label', blockepi)
% %mmc.setProperty('TIDiaLamp','ComputerControl','On');
% %mmc.setProperty('TIDiaLamp','Intensity',num2str(intensity));
% mmc.setExposure(exposure);
%
% data.XYtarget = xycoord;
%
% x = xycoord(1);
% y = xycoord(2);
%
% xtarget = pixelsize * (-1024/2 + xcorrection + x);
% ytarget = pixelsize * (-1024/2 + ycorrection + y);
%
% mmc.setXYPosition('XYStage',xtarget,ytarget);

%% take z-stack pictures with 150X phase
%
% disp('capturing image stack');
steps = 0.025*3^4;

nstacks = ceil((maxoffset-minoffset)/steps); %must be odd

imstack = zeros(2*round(imWidth*0.5*cropFactor),2*round(imHeight*0.5*cropFactor),nstacks,'double');

%   mmc.setAutoShutter(0);
mmc.setShutterOpen(1);

zStack = minoffset:steps:(minoffset+(nstacks-1)*steps);

for i=1:nstacks
    mmc.setPosition('TIZDrive',zStack(i))
    mmc.waitForDevice('TIZDrive');
    %         mmc.setProperty('TIPFSOffset','Position',num2str(zStack(i)));
    %         mmc.waitForDevice('TIPFSOffset');
%     pause(0.1);
    mmc.snapImage();
    imgtmp=mmc.getImage;
    imgtmp = typecast(imgtmp, pixelType);
    img=rotateFrame(imgtmp,mmc);
    imstack(:,:,i)= double(img((1+imWidth/2-round(imWidth*0.5*cropFactor)):(imWidth/2+round(imWidth*0.5*cropFactor)),(1+imHeight/2-round(imHeight*0.5*cropFactor)):(imHeight/2+round(imHeight*0.5*cropFactor)))) - background((1+imWidth/2-round(imWidth*0.5*cropFactor)):(imWidth/2+round(imWidth*0.5*cropFactor)),(1+imHeight/2-round(imHeight*0.5*cropFactor)):(imHeight/2+round(imHeight*0.5*cropFactor)));
end

minstack = min(imstack(:));
maxstack = max(imstack(:));

imstack  = (imstack - minstack)/(maxstack-minstack);
%%
%     if diagnostic_plots
%         for i = 1:nstacks
%             figure, imshow(imstack(:,:,i),[]);
%         end
%     end
%% detect dark object in all z

% contrast = -1;
best = Inf;
boxp = [1 1 2 2];
% zp = minoffset;
normvar = zeros(size(imstack,3),1);

%  figure,
for i=1:nstacks
    
    imnorm = imstack(:,:,i);
    %     imshow(imnorm,[]);
    %     pause;
    %         meanint = mean(imnorm(:));
    %         bwim = ~im2bw(imnorm,meanint);
    %     imshow(bwim,[]);
    %     pause;
    imef = rangefilt(imnorm);
    %imef = (imef-min(reshape(imef,1,[])))/max(reshape(imef,1,[]));
%         imshow(imef,[]);
%         pause;
    imbw = im2bw(imef,mean(imef(:))+4*std(imef(:)));
    imbw = imdilate(imbw, [1 1 1; 1 1 1; 1 1 1]);
    imbw = imfill(imbw,'holes');
%         imshow(imbw,[]);
%         pause;
    
    %         imbw = imbw & bwim;
    %     imshow(imbw,[]);
    %     pause;
    %imbw_filled = imfill(imbw,'holes');
%     imbw_filled = medfilt2(imbw,[5 5]);
    %     imshow(imbw_filled,[]);
    
    objects=regionprops(imbw,'Area','Centroid','Eccentricity','BoundingBox','MajorAxisLength');
    
    objects(([objects.Area].*pixelSize^2)<(cellstats.Area-3*cellstats.stdArea))=[];
    objects(([objects.Area].*pixelSize^2)>(cellstats.Area+3*cellstats.stdArea))=[];
    %numel(objects);
    %pause;
    % pick most likely to be E. coli cell
    
    if numel(objects)>0
        cent = vertcat(objects.Centroid);
        dcent = ((size(imstack,1)/2-cent(:,1)')./(imWidth/100)).^2 + ((size(imstack,2)/2-cent(:,2)')./(imHeight/100)).^2;
        dsize = ((cellstats.Area - [objects.Area].*pixelSize^2)/cellstats.stdArea).^2;
        decc = ((cellstats.Eccentricity - [objects.Eccentricity])/cellstats.stdEccentricity).^2;
        daxis = ((cellstats.MajorAxisLength - [objects.MajorAxisLength]*pixelSize)/cellstats.stdMajorAxisLength).^2;
%                     idx = sub2ind(size(imnorm), round(cent(:,2)), round(cent(:,1)));
%                     dintensity = imnorm(idx)' - mean(imnorm(:));
        scores = dsize + decc + daxis + dcent;% + dintensity;
        
        %min(dsize)
        %min(decc)
        %min(daxis)
        %min(dcent)
        %         pause();
        %disp([objects.MinIntensity]);
        %scores = dcent.^2 + dintensity.^2;
        %scores = dsize.^2 + decc.^2 + daxis.^2 + dintensity.^2;
        [s, ind] = min(scores);
    else
        continue;
    end
    
    if ~isempty(ind)
        %         box = objects(ind).BoundingBox;
        %         offset = 30;
        box = [round(objects(ind).Centroid(1)-5/pixelSize) round(objects(ind).Centroid(2)-5/pixelSize) round(10/pixelSize) round(10/pixelSize)];
%         object = imcrop(imnorm, box);
        %object = imnorm;
        %             glcmb = graycomatrix(object,'NumLevels',32);
        %             statsb = graycoprops(glcmb,'Contrast');
%         normvar(i) = var(object(:))/mean(object(:)); %sign(dintensity(ind))
        
        if s<best
            boxp = box;
            best=s;
            %contrast = statsb.Contrast;
%             zp = zStack(i);
            %             imgp = object;
            %             data.Area = objects(ind).Area*pixelSize^2;
            data.Centroid = objects(ind).Centroid;
            %             data.Eccentricity = objects(ind).Eccentricity;
            %             %data.BoundingBox = objects(ind).BoundingBox;
            %             data.MajorAxisLength = objects(ind).MajorAxisLength*pixelSize;
            %             data.MinIntensity = objects(ind).MinIntensity;
        end
        if diagnostic_plots
            figure(1),
            imshow(imnorm,[],'InitialMagnification',50);
            hold on,
            rectangle('Position',box,'EdgeColor', 'red');
            rectangle('Position',boxp,'EdgeColor', 'green');
            plot(data.Centroid(1),data.Centroid(2),'g+');
            hold off
            drawnow;
            %                 pause(0.1);
        end
        
    end
    
    %     pause();
end

% return;

if best==Inf
    return;
end
%%

object = imstack(boxp(1):(boxp(1)+boxp(3)), boxp(2):(boxp(2)+boxp(4)),:);
for i = 1:nstacks
    tmp = object(:,:,i);
    normvar(i) = var(tmp(:))/mean(tmp(:));
end

f = fit(zStack',-normvar,'smoothingspline');
[zp, nv] = fminbnd(f,zStack(1),zStack(end));

figure(2),
hold on,
plot(zStack',-normvar,'o');
plot(f);
plot(zp,nv,'*');

[~,ind] = max(normvar);

% figure(3),
% subplot(1,3,1),
% imshow(object(:,:,ind-1),[]);
% subplot(1,3,2),
% imshow(object(:,:,ind),[]);
% xlabel(zp);
% subplot(1,3,3),
% imshow(object(:,:,ind+1),[]);
%% center stage on selected object

xtarget = xPosition - round(pixelSize*(size(imstack,1)/2 - data.Centroid(1)));
ytarget = yPosition - round(pixelSize*(size(imstack,2)/2 - data.Centroid(2)));

mmc.setXYPosition('XYStage',xtarget,ytarget);

%     mmc.setProperty('TIPFSOffset','Position',num2str(zp));
mmc.setPosition('TIZDrive',zp);
mmc.waitForDevice('TIZDrive');
mmc.waitForDevice('XYStage');
mmc.waitForImageSynchro();
% pause(0.1);

%%
%     mmc.setXYPosition('XYStage',xPosition,yPosition);

%%
boxp = [round(imWidth/2-5/pixelSize), round(imHeight/2-5/pixelSize), round(10/pixelSize), round(10/pixelSize)];

% figure,
% hold on
mmc.setShutterOpen(1);
mmc.waitForImageSynchro();

mmc.snapImage;
imgtmp = mmc.getImage;
imgtmp = typecast(imgtmp, pixelType);
img = double(rotateFrame(imgtmp,mmc));
%imgnorm = (img-min(img(:)))/max(img(:));

%     imshow(double(img),[]);
%     rectangle('Position',boxp,'EdgeColor', 'green');
%     mmc.setShutterOpen(0);
% hold off

imgp = imcrop(img, boxp);
%     mingray = min(imgp(:)) - (max(imgp(:))-min(imgp(:)))/2;
%     maxgray = max(imgp(:)) + (max(imgp(:))-min(imgp(:)))/2;

%     mingray = min(imgp(:));
%     maxgray = max(imgp(:));

%     glcmb = graycomatrix(imgp,'NumLevels',32,'GrayLimits',[mingray maxgray]);
%     statsb = graycoprops(glcmb,'Contrast');
bw = edge(imgp,'log');
bw = imfill(bw,'holes');
%bw = bwselect(bw,size(bw,2)/2,size(bw,1)/2);
prop = regionprops(bw,'Area','Centroid');
[ma, ~] = max([prop.Area]);
%     mint = sign(-imgp(round(prop(mi).Centroid(2)),round(prop(mi).Centroid(1))) + mean(imgp(:)));
%      mint = -imgp(round(prop(mi).Centroid(2)),round(prop(mi).Centroid(1))) + mean(imgp(:));

%     contrast = mint * statsb.Contrast;
contrast = var(imgp(:))/mean(imgp(:));

if ma*pixelSize^2 > 1
    hasarea = 1;
    contarea = contrast;
else
    hasarea = 0;
    contarea = 0;
end
%     pause();

% refine focus on selected object
%
% disp('refining focus');

%mmc.setShutterOpen(1);
% mmc.waitForSystem();
figure(4),
subplot(2,3,1), imshow(imgp,[],'InitialMagnification',100);
xlabel(sprintf('Var0 %0.3g\nVar %0.3g',best, contrast));
%     hold off;
drawnow;

steps = steps / 3;
ozp = zp;
areazp = zp;

while abs(steps) > 0.02
    disp(abs(steps));
    j=0;
    %         mmc.setProperty('TIPFSOffset','Position',num2str(max(0,zp+steps)));
    %         mmc.waitForSystem();
    mmc.setPosition('TIZDrive',zp+steps)
    mmc.waitForDevice('TIZDrive');
%     pause(0.1);
    mmc.snapImage;
    imgtmp = mmc.getImage;
    imgtmp = typecast(imgtmp, pixelType);
    img=double(rotateFrame(imgtmp,mmc));
    object = imcrop(img, boxp);
    %object = (object-min(object(:)))/max(object(:));
    %object = imcrop(double(imgnorm), boxp);
    %object = imcrop(imgnorm, boxp);
    %mint = min(object(:));
    %         glcmb = graycomatrix(object,'NumLevels',32,'GrayLimits',[mingray maxgray]);
    %         statsb = graycoprops(glcmb,'Contrast');
    bw = edge(object,'log');
    bw = imfill(bw,'holes');
    %     bw = bwselect(bw,size(bw,2)/2,size(bw,1)/2);
    
    prop = regionprops(bw,'Area','Centroid');
    [ma, ~] = max([prop.Area]);
    %         mint = sign(-object(round(prop(mi).Centroid(2)),round(prop(mi).Centroid(1))) + mean(object(:)));
    %                 mint = -object(round(prop(mi).Centroid(2)),round(prop(mi).Centroid(1))) + mean(object(:));
    
    contobject = var(object(:))/mean(object(:));
    
    if contobject > (contrast+0.001*contrast) %&& ma*pixelSize^2 > 1
        contrast = contobject;
        ozp = zp;
        nzp = zp+steps;
        %subplot(2,3,2), imshow(object,[]);
        %subplot(2,3,1), imshow(imgp,[]);
        %xlabel(statsb.Contrast);
        %drawnow;
        %imgp = object;
        j=1;
        %         fprintf('better\n');
        if ma*pixelSize^2 > 1
            areazp = nzp;
            hasarea = 1;
            contarea = contrast;
        end
    end
    
    if (zp-steps) ~= ozp
        steps = -steps;
        %             mmc.setProperty('TIPFSOffset','Position',num2str(max(0,zp+steps)));
        %             mmc.waitForSystem();
        mmc.setPosition('TIZDrive',zp+steps)
        mmc.waitForDevice('TIZDrive');
%         pause(0.1);
        mmc.snapImage;
        imgtmp=mmc.getImage;
        imgtmp = typecast(imgtmp, pixelType);
        img=double(rotateFrame(imgtmp,mmc));
        object = imcrop(img, boxp);
        %object = (object-min(object(:)))/max(object(:));
        %subplot(2,3,2), imshow(object,[]);
        %mint = min(object(:));
        %             glcmb = graycomatrix(object,'NumLevels',32,'GrayLimits',[mingray maxgray]);
        %             statsb = graycoprops(glcmb,'Contrast');
        bw = imfill(bw,'holes');
        %bw = bwselect(bw,size(bw,2)/2,size(bw,1)/2);
        prop = regionprops(bw,'Area','Centroid');
        [ma, ~] = max([prop.Area]);
        %             mint = sign(-object(round(prop(mi).Centroid(2)),round(prop(mi).Centroid(1))) + mean(object(:)));
        %                         mint = -object(round(prop(mi).Centroid(2)),round(prop(mi).Centroid(1))) + mean(object(:));
        contobject = var(object(:))/mean(object(:));
        
        if contobject>(contrast+0.001*contrast) %&& ma*pixelSize^2 > 1
            contrast = contobject;
            ozp = zp;
            nzp = zp+steps;
            %subplot(2,3,2), imshow(object,[]);
            %xlabel(statsb.Contrast);
            %subplot(2,3,1), imshow(imgp,[]);
            %drawnow;
            %imgp = object;
            j=1;
            %             fprintf('better\n');
            if ma*pixelSize^2 > 1
                areazp = nzp;
                hasarea = 1;
                contarea = contrast;
            end
        end
    end
    if j == 0
        steps = steps/3;
    else
        zp = nzp;
    end
end

if hasarea && contarea > (contrast+0.001*contrast);
    zp = areazp;
    %     fprintf('area!\n');
    % else
    %     fprintf('no area!\n');
end

%     mmc.setProperty('TIPFSOffset','Position',num2str(max(0,zp)));
%     mmc.waitForSystem();
mmc.setPosition('TIZDrive',zp)
mmc.waitForDevice('TIZDrive');
% pause(0.1);
mmc.snapImage;
imgtmp=mmc.getImage;
imgtmp = typecast(imgtmp, pixelType);
img=double(rotateFrame(imgtmp,mmc));
imgp = imcrop(img, boxp);
contrast = var(imgp(:))/mean(imgp(:));
%     glcmb = graycomatrix(imgp,'NumLevels',32,'GrayLimits',[mingray maxgray]);
%     statsb = graycoprops(glcmb,'Contrast');

% mmc.waitForSystem();
%     mmc.setShutterOpen(0);

data.Zcoord = zp;
data.Phase = imgp;
data.NormVar = contrast;

% data.YFP=1;
% data.CFP=1;


%% check if cell is good

bw = edge(imgp,'log');
bw = imfill(bw,'holes');
% bw = bwselect(bw,size(bw,2)/2,size(bw,1)/2);

prop = regionprops(bw, imgp, 'Area','Eccentricity','Centroid','MajorAxisLength','MinIntensity');

[ma, mi] = max([prop.Area]);

data.Area = ma*pixelSize^2;
%data.Centroid = objects(ind).Centroid;
data.Eccentricity = prop(mi).Eccentricity;
%data.BoundingBox = objects(ind).BoundingBox;
data.MajorAxisLength = prop(mi).MajorAxisLength*pixelSize;
data.MinIntensity = prop(mi).MinIntensity;

data.XYcoord = [xtarget+pixelSize*(prop(mi).Centroid(1)-size(bw,1)/2); ytarget+pixelSize*(prop(mi).Centroid(2)-size(bw,2)/2)];

subplot(2,3,2), imshow(imgp,[],'InitialMagnification',100);
xlabel(sprintf('contrast %0.3g',contrast));


subplot(2,3,3), imshow(bw,[],'InitialMagnification',100);
xlabel(sprintf('area %0.3g\nlength %0.3g',data.Area, data.MajorAxisLength));


drawnow;

if data.Area > 1 && data.Area < 8 && data.MajorAxisLength > 1 && data.MajorAxisLength < 10 && data.Eccentricity > 0.8 && (data.MinIntensity - mean(imgp(:)))<0
    % take fluorescence image
    
    
    %% take CFP
    
    mmc.setConfig('Channel',configFluoCFP);
        mmc.setShutterOpen(1);
    mmc.waitForImageSynchro();
    pause(0.1);
    mmc.snapImage;
    imgtmp=mmc.getImage;
    imgtmp = typecast(imgtmp, pixelType);
    imgf=imcrop(double(rotateFrame(imgtmp,mmc)), boxp);
    
    %subplot(2,3,4), imshow(imgp,[]);
    %xlabel(ma*pixelSize^2);
    subplot(2,3,4), imshow(imgf,[],'InitialMagnification',100);
    xlabel('CFP');
    drawnow;
    %pause();
    data.CFP = imgf;
    
    %% take YFP
    mmc.setConfig('Channel',configFluoYFP);
        mmc.setShutterOpen(1);
    mmc.waitForImageSynchro();
    pause(0.1);
    mmc.snapImage;
    imgtmp=mmc.getImage;
    imgtmp = typecast(imgtmp, pixelType);
    
    imgf=imcrop(double(rotateFrame(imgtmp,mmc)), boxp);
    
    %subplot(2,3,5), imshow(imgp,[]);
    %xlabel(ma*pixelSize^2);
    subplot(2,3,5), imshow(imgf,[],'InitialMagnification',100);
    xlabel('YFP');
    drawnow;
    %pause();
    data.YFP = imgf;
    
    %% take RFP
    
    mmc.setConfig('Channel',configFluoRFP);
        mmc.setShutterOpen(1);
    mmc.waitForImageSynchro();
    pause(0.1);
    mmc.snapImage;
    imgtmp=mmc.getImage;
    imgtmp = typecast(imgtmp, pixelType);
    
    imgf=imcrop(double(rotateFrame(imgtmp,mmc)), boxp);
    
    %subplot(2,3,1), imshow(imgp,[]);
    %xlabel(ma*pixelSize^2);
    subplot(2,3,6), imshow(imgf,[],'InitialMagnification',100);
    xlabel('RFP');
    %         pause();
    data.RFP = imgf;
    drawnow;
end

end