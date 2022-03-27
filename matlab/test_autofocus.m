steps = 0.5;
nstacks = 30;

mmc.setConfig('Channel','Phase_100X_nobin');

imWidth = mmc.getImageWidth;
imHeight = mmc.getImageHeight;
pos = mmc.getPosition('TIZDrive');
minoffset = pos-(nstacks-1)/2*steps;
maxoffset = pos+(nstacks-1)/2*steps;

cropFactor = 0.5;

imstack = zeros(2*round(imWidth*0.5*cropFactor),2*round(imHeight*0.5*cropFactor),nstacks,'double');
zStack = minoffset:steps:(minoffset+(nstacks-1)*steps);

if mmc.getBytesPerPixel == 2
    pixelType = 'uint16';
else
    pixelType = 'uint8';
end

mmc.setShutterOpen(1);

for i=1:nstacks
    mmc.setPosition('TIZDrive',zStack(i))
    mmc.waitForDevice('TIZDrive');
    pause(0.1);
    
    mmc.snapImage();
    imgtmp=mmc.getImage;
    imgtmp = typecast(imgtmp, pixelType);
    img=rotateFrame(imgtmp,mmc);
    imstack(:,:,i)= double(img((1+imWidth/2-round(imWidth*0.5*cropFactor)):(imWidth/2+round(imWidth*0.5*cropFactor)),(1+imHeight/2-round(imHeight*0.5*cropFactor)):(imHeight/2+round(imHeight*0.5*cropFactor)))) - background((1+imWidth/2-round(imWidth*0.5*cropFactor)):(imWidth/2+round(imWidth*0.5*cropFactor)),(1+imHeight/2-round(imHeight*0.5*cropFactor)):(imHeight/2+round(imHeight*0.5*cropFactor)));
end

save('test_stack','imstack');
%%
for i = 1:nstacks
    imshow(imstack(:,:,i),[]);
    pause;
end