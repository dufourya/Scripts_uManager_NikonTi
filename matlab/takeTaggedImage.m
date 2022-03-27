function img = takeTaggedImage(mmc, config)
    % Gets a TaggedImage and converts it into something matlab can read.
    mmc.setConfig('Channel',config);
    check15Xswitch(mmc);
    mmc.waitForImageSynchro();
    mmc.snapImage();
    timg = mmc.getTaggedImage();
    w = mmc.getImageWidth();
    h = mmc.getImageHeight();
    
    img.pix = uint16(rotateFrame(timg.pix,mmc));
    img.tags = char(timg.tags);
end