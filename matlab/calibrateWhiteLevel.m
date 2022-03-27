function wl = calibrateWhiteLevel(mmc, configFluo)

if mmc.getBytesPerPixel == 2
    pixelType = 'uint16';
else
    pixelType = 'uint8';
end

orixPos = mmc.getXPosition('XYStage');
oriyPos = mmc.getYPosition('XYStage');
mmc.setConfig('Channel',configFluo);
check15Xswitch(mmc);

spacing = 2*mmc.getPixelSizeUm*mmc.getImageWidth;
mmc.setXYPosition('XYStage',orixPos+spacing,oriyPos+spacing);

wl = 10;
good = 0;

xPos = orixPos;
yPos = oriyPos;

while ~good && xPos-orixPos < 3000 && yPos-oriyPos < 3000
    
    xPos = mmc.getXPosition('XYStage');
    yPos = mmc.getYPosition('XYStage');
    mmc.setProperty('Sola','White_Level',wl)
    mmc.waitForImageSynchro();
    mmc.setAutoShutter(1);
    mmc.snapImage();
    img = typecast(mmc.getImage(),pixelType);
    if sum(img==max(img))>(0.01*numel(img))
        wl = min(100,max(1,round(wl/3)));
        mmc.setXYPosition('XYStage',xPos+spacing,yPos+spacing);
    elseif mean(img)<16384 && wl < 100
        wl = min(100,max(1,round(wl*sqrt(21845/double(mean(img))))));
        mmc.setXYPosition('XYStage',xPos+spacing,yPos+spacing);
    else
        fprintf('%s %d\n',configFluo,wl);
        good = 1;
    end
    
end

if ~good
    error('Sola intensity calibration failed! Please adjust fluorofore concentrations.');
end

end