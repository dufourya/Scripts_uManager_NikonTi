function img = rotateFrame(img,mmc)

imWidth = mmc.getImageWidth();
imHeight = mmc.getImageHeight();

img = rot90(reshape(img,imWidth,imHeight));

if str2num(mmc.getProperty(mmc.getCameraDevice(),'TransposeCorrection'))
    if ~str2num(mmc.getProperty(mmc.getCameraDevice(),'TransposeMirrorY'))
        img = flipud(img);
    end
    if str2num(mmc.getProperty(mmc.getCameraDevice(),'TransposeMirrorX'))
        img = fliplr(img);
    end
    if str2num(mmc.getProperty(mmc.getCameraDevice(),'TransposeXY'))
        img = img';
    end
end