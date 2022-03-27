function data = autofocus_cell(mmc,cellstats,cropFactor,configPhase,...
    configFluoCFP,configFluoYFP,configFluoRFP,background,minoffset,maxoffset)
%     tic
diagnostic_plots = 0;
background = double(background);
meanbackground = mean(background(:));
mmc.setConfig('Channel',configPhase);
check15Xswitch(mmc);
mmc.setShutterOpen(1);

imWidth = mmc.getImageWidth();
imHeight = mmc.getImageHeight();
pixelSize = mmc.getPixelSizeUm();

xPosition = mmc.getXPosition(mmc.getXYStageDevice());
yPosition = mmc.getYPosition(mmc.getXYStageDevice());
mmc.setProperty('TIPFSStatus','State','Off');

if mmc.getBytesPerPixel == 2
    pixelType = 'uint16';
else
    pixelType = 'uint8';
end

data = struct('Area',[],'MajorAxisLength',[],...
    'Solidity',[],'NormVar',[],'LogL',[],'Phase',[],'YFP',[],'CFP',[],'RFP',[],...
    'Zcoord',[],'XYcoord',[],'time',[],'Centroid',[]);

%% take z-stack pictures with 150X phase

steps = 0.025*2^7;
nstacks = ceil((maxoffset-minoffset)/steps); %must be odd
imstack = zeros(2*round(imWidth*0.5*cropFactor),2*round(imHeight*0.5*cropFactor),nstacks,'double');
zStack = minoffset:steps:(minoffset+(nstacks-1)*steps);
zStack = round(zStack./0.025).*0.025;

for i = 1:nstacks
    mmc.setPosition('TIZDrive',zStack(i))
    mmc.waitForDevice('TIZDrive');
    mmc.snapImage();
    imgtmp = mmc.getImage;
    imgtmp = typecast(imgtmp, pixelType);
    img = (double(rotateFrame(imgtmp,mmc))- background) + meanbackground;
    imstack(:,:,i) = img((1+imWidth/2-round(imWidth*0.5*cropFactor)):(imWidth/2+round(imWidth*0.5*cropFactor)),(1+imHeight/2-round(imHeight*0.5*cropFactor)):(imHeight/2+round(imHeight*0.5*cropFactor)));
end

% minstack = min(imstack(:));
% maxstack = max(imstack(:));
% imstack = (imstack - minstack)/(maxstack-minstack);
% meanim = mean(imstack(:));
%% detect dark object in all z
sedil = strel('disk',2);
seero = strel('disk',5);

best = -Inf;
boxp = [1 1 2 2];
normvar = zeros(size(imstack,3),1);
% beststats = [0 0 0 0];

for i = 1:nstacks
    imnorm = imstack(:,:,i);
    imef = rangefilt(imnorm);
    imbw = imbinarize(imef,mean(imef(:))+3*std(imef(:)));
    imbw = imdilate(imbw, sedil);
    imbw = imfill(imbw,'holes');
    imbw = imerode(imbw, seero);
    objects = regionprops(imbw,'Area','Centroid','Solidity','MajorAxisLength');
    [objects.NormVar] = deal(log(var(imnorm(:))/mean(imnorm(:))));
    
    if ~isempty(objects)
        statsobj = [[objects.Area].*pixelSize^2;[objects.MajorAxisLength]*pixelSize;[objects.Solidity];[objects.NormVar]]';
        ll = log(pdf(cellstats,statsobj));
        cent = vertcat(objects.Centroid);
        cent = [size(imstack,1)/2 - cent(:,1), size(imstack,2)/2 - cent(:,2)];
        cent = pixelSize.*sqrt(mean(cent.^2,2));
        ll = ll + log(normpdf(cent,0,50));
        %             ll(([objects.MeanIntensity]-meanim)<0) = -Inf;
        
        [s, ind] = max(ll);
%         [s, ind] = max([objects.Area]);
        
        box = [round(objects(ind).Centroid(1)-(5/pixelSize)) round(objects(ind).Centroid(2)-(5/pixelSize)) round(10/pixelSize) round(10/pixelSize)];
        
        if s>best && ~sum(box<1) && (box(1)+box(3)) <= size(imnorm,1) && (box(2)+box(4)) <= size(imnorm,2)
            boxp = box;
            best = s;
            data.Centroid = objects(ind).Centroid;
            imgp = imcrop(imnorm, boxp);
%             beststats = statsobj(ind,:);
%         end
        
        if diagnostic_plots
            figure(1),
            subplot(1,2,1),
            imshow(imnorm,[],'InitialMagnification',50);
            hold on,
            rectangle('Position',box,'EdgeColor', 'red');
            rectangle('Position',boxp,'EdgeColor', 'green');
%             xlabel(beststats);
%             ylabel(log(pdf(cellstats,beststats)));
            %plot(data.Centroid(1),data.Centroid(2),'g+');
            hold off
            subplot(1,2,2),
            imshow(imbw,[],'InitialMagnification',50);
            hold on,
            rectangle('Position',box,'EdgeColor', 'red');
            rectangle('Position',boxp,'EdgeColor', 'green');
            %plot(data.Centroid(1),data.Centroid(2),'g+');
            hold off
            drawnow;
            pause(0.25);
        end
        end
    end
end

if best < -25
    if best > -Inf
        figure(4),
        subplot(2,3,1), imshow(imgp,[],'InitialMagnification',100);
        xlabel(sprintf('Score: %0.3g\nScore too low!',best));
        drawnow;
    end
    return;
end
%%

object = imstack(boxp(2):(boxp(2)+boxp(4)), boxp(1):(boxp(1)+boxp(3)),:);
for i = 1:nstacks
    tmp = squeeze(object(:,:,i));
    normvar(i) = log(var(tmp(:))/mean(tmp(:)));
end

%f = fit(zStack',-normvar,'smoothingspline');
% [zp, nv] = fminbnd(f,zStack(1)-steps,zStack(end)+steps);
%zsteps = zStack(1)-0.5*steps:(steps/4):zStack(end)+0.5*steps;
%[nv, I] = min(f(zsteps));
[nv, I] = max(normvar);
zp = zStack(I);
% zp = round(zp/0.025)*0.025;

if diagnostic_plots
    figure(2),
    plot(zStack',normvar,'o');
    hold on;
%     plot(f);
    plot(zp,nv,'*');
    hold off;
    drawnow;
    [~,ind] = max(normvar);
    figure(3),
    subplot(1,3,1),
    if ind>1
        imshow(object(:,:,ind-1),[]);
    end
    subplot(1,3,2),
    imshow(object(:,:,ind),[]);
    xlabel(zp);
    subplot(1,3,3),
    if ind<size(object,3)
        imshow(object(:,:,ind+1),[]);
    end
end
%% center stage on selected object

focusData = [];

xtarget = xPosition + (pixelSize*(data.Centroid(1) - size(imstack,1)/2));
ytarget = yPosition + (pixelSize*(data.Centroid(2) - size(imstack,2)/2));

mmc.setXYPosition('XYStage',xtarget,ytarget);
mmc.setPosition('TIZDrive',zp);
mmc.waitForDevice('TIZDrive');
mmc.waitForDevice('XYStage');
mmc.waitForImageSynchro();

%%
boxp = [round(imWidth/2-5/pixelSize), round(imHeight/2-5/pixelSize), round(10/pixelSize), round(10/pixelSize)];
%     disp(mmc.getPosition('TIZDrive'));
mmc.snapImage;
imgtmp = mmc.getImage;
imgtmp = typecast(imgtmp, pixelType);
img = (double(rotateFrame(imgtmp,mmc))-background)+ meanbackground;
imgp = imcrop(img, boxp);
contrast = log(var(imgp(:))/mean(imgp(:)));
focusData = [focusData; zp contrast];

figure(4),
subplot(2,3,1), imshow(imgp,[],'InitialMagnification',100);
xlabel(sprintf('Score: %0.3g\nNormVar: %.03g',best,contrast));
drawnow;

%% Focus
%     steps = 2.0250;
steps = steps / 2;
direction = 1;
first = 1;
lastcontrast = contrast;

while abs(steps) > 0.02
    
    ind = find(focusData(:,1) == zp+(direction*steps));
    if isempty(ind)
        mmc.setPosition('TIZDrive',zp+(direction*steps));
        mmc.waitForDevice('TIZDrive');
        mmc.snapImage;
        imgtmp = mmc.getImage;
        imgtmp = typecast(imgtmp, pixelType);
        img = (double(rotateFrame(imgtmp,mmc))-background)+ meanbackground;
        object = imcrop(img, boxp);
        contobject = log(var(object(:))/mean(object(:)));
        focusData = [focusData; zp+(direction*steps) contobject];
        %             fprintf('%.7g %.4g %.4g\n',zp+(direction*steps), steps, contobject);
    else
        contobject = focusData(ind,2);
    end
    
    if contobject > contrast
        lastcontrast = contrast;
        if diagnostic_plots
            subplot(2,3,2), imshow(object,[],'InitialMagnification',100);
            xlabel(sprintf('NormVar: %0.3g',contobject));
            drawnow;
        end
        contrast = contobject;
        zp = zp+(direction*steps);
        first = 0;
    else
        if ~first
            steps = steps / 2;
        else
            first = 0;
        end
        if contobject < lastcontrast
            direction = -direction;
        end
    end
end
%%

mmc.setPosition('TIZDrive',zp)
mmc.waitForDevice('TIZDrive');
%     disp(mmc.getPosition('TIZDrive'));
mmc.snapImage;
imgtmp = mmc.getImage;
imgtmp = typecast(imgtmp, pixelType);
img = (double(rotateFrame(imgtmp,mmc))-background)+ meanbackground;
imgp = imcrop(img, boxp);
contrast = log(var(imgp(:))/mean(imgp(:)));

data.Zcoord = mmc.getPosition('TIZDrive');
data.Phase = imgp;
data.NormVar = contrast;

%% check if cell is good

bw = edge(imgp,'log');
bw = imfill(bw,'holes');
prop = regionprops(bw,'Area','Centroid',...
    'MajorAxisLength','Solidity');
[ma, mi] = max([prop.Area]);

data.Area = ma*pixelSize^2;
data.MajorAxisLength = prop(mi).MajorAxisLength*pixelSize;
data.Solidity = prop(mi).Solidity;

data.XYcoord = [xtarget+pixelSize*(prop(mi).Centroid(1)-size(bw,1)/2);...
    ytarget+pixelSize*(prop(mi).Centroid(2)-size(bw,2)/2)];

statsobj = [data.Area;data.MajorAxisLength;data.Solidity;data.NormVar]';
ll = log(pdf(cellstats,statsobj));
% ll =0;
data.LogL = ll;

subplot(2,3,2), imshow(imgp,[],'InitialMagnification',100);
xlabel(sprintf('Score: %0.3g\nNormVar: %0.3g',ll,data.NormVar));
subplot(2,3,3), imshow(bw,[],'InitialMagnification',100);
xlabel(sprintf('Area: %0.3g\\mum^2\nLength %0.3g\\mum',data.Area, data.MajorAxisLength));
drawnow;

if data.Area > 1 && data.LogL > -5
    
    %% take CFP
    if ~isempty(configFluoCFP)
        mmc.setConfig('Channel',configFluoCFP);
        check15Xswitch(mmc);
        mmc.setShutterOpen(1);
        mmc.waitForImageSynchro();
        pause(0.1);
        mmc.snapImage;
        imgtmp = mmc.getImage;
        imgtmp = typecast(imgtmp, pixelType);
        imgf = imcrop(double(rotateFrame(imgtmp,mmc)), boxp);
        subplot(2,3,4), imshow(imgf,[prctile(imgf(:),0.05) prctile(imgf(:),99.95)],'InitialMagnification',100);
        xlabel('CFP');
        drawnow;
        data.CFP = imgf;
    end
    %% take YFP
    if ~isempty(configFluoYFP)
        mmc.setConfig('Channel',configFluoYFP);
        check15Xswitch(mmc);
        mmc.setShutterOpen(1);
        mmc.waitForImageSynchro();
        pause(0.1);
        mmc.snapImage;
        imgtmp = mmc.getImage;
        imgtmp = typecast(imgtmp, pixelType);
        imgf = imcrop(double(rotateFrame(imgtmp,mmc)), boxp);        
        subplot(2,3,5), imshow(imgf,[prctile(imgf(:),0.5) prctile(imgf(:),99.95)],'InitialMagnification',100);
        xlabel('YFP');
        drawnow;
        data.YFP = imgf;
    end
    %% take RFP
    if ~isempty(configFluoRFP)
        mmc.setConfig('Channel',configFluoRFP);
        check15Xswitch(mmc);
        mmc.setShutterOpen(1);
        mmc.waitForImageSynchro();
        pause(0.1);
        mmc.snapImage;
        imgtmp = mmc.getImage;
        imgtmp = typecast(imgtmp, pixelType);
        imgf = imcrop(double(rotateFrame(imgtmp,mmc)), boxp);
        subplot(2,3,6), imshow(imgf,[prctile(imgf(:),0.05) prctile(imgf(:),99.95)],'InitialMagnification',100);
        xlabel('RFP');
        drawnow;
        data.RFP = imgf;
    end
end
if diagnostic_plots
    figure(5),
    plot(focusData(:,1), focusData(:,2), 'o');
    hold on;
    plot(zp, contrast,'x');
    xlabel('Z-position');
    ylabel('NormVar');
    hold off
end
%     toc
end