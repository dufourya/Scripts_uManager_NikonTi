function background = getFreezeBackground(mmc,configPhase)
    
    mmc.setConfig('Channel',configPhase);
    check15Xswitch(mmc);
    mmc.setShutterOpen(1);
    
    mmc.setProperty('TIPFSStatus','State','Off');
    zpos = mmc.getPosition('TIZDrive');
    mmc.setPosition('TIZDrive',zpos-50);
    mmc.waitForDevice('TIZDrive');
    xpos = mmc.getXPosition;
    ypos = mmc.getYPosition;
    
    imWidth = mmc.getImageWidth();
    imHeight = mmc.getImageHeight();
    if mmc.getBytesPerPixel == 2
        pixelType = 'uint16';
    else
        pixelType = 'uint8';
    end
    
    img = int16(zeros(imWidth*imHeight,11));
    
    for i = 1:11
        xtarget = xpos + random('unif',-100, 100);
        ytarget = ypos + random('unif',-100, 100);
        mmc.setXYPosition(mmc.getXYStageDevice(),xtarget,ytarget);
        mmc.waitForDevice(mmc.getXYStageDevice());
        
        mmc.snapImage();
        img(:,i) = mmc.getImage;
    end
    
    mmc.setPosition('TIZDrive',zpos);
    mmc.waitForDevice('TIZDrive');
    mmc.setXYPosition(mmc.getXYStageDevice(),xpos,ypos);
    mmc.waitForDevice(mmc.getXYStageDevice());
    
    background = rotateFrame(typecast(squeeze(median(img,2)),pixelType),mmc);
end