function locations = defineMultipointPositions(mmc, config)

    mmc.setConfig('System','Startup');
    mmc.waitForSystem();
    % initialize stage
    q0 = questdlg('Ready to align the fields of view?', 'Warning','OK','Cancel','OK');

    if strcmp(q0,'OK')
        % align stage with start of channel
        % warndlg('First, align and focus the start of the channel.');
        waitfor(Live(mmc,config));
        
        meta.startPos.x = mmc.getXPosition('XYStage');
        meta.startPos.y = mmc.getYPosition('XYStage');
        meta.startPos.z = mmc.getPosition('ZStage');

        % align stage with end of channel
        % warndlg('Second, align and focus the end of the channel.');
        waitfor(Live(mmc,config));

        % get coordinates of end position
        meta.endPos.x = mmc.getXPosition('XYStage');
        meta.endPos.y = mmc.getYPosition('XYStage');
        meta.endPos.z = mmc.getPosition('ZStage');

        % determine how many frame are necessary to cover the channel
        totalLength = max(abs(meta.endPos.y - meta.startPos.y), abs(meta.endPos.x - meta.startPos.x));
        nbFrame = ceil(abs(totalLength/mmc.getImageWidth/mmc.getPixelSizeUm));

        % calculate coordinates for all frames
        locations.x = round(meta.startPos.x:(meta.endPos.x-meta.startPos.x+0.1)/(nbFrame):meta.endPos.x+0.1);
        locations.y = round(meta.startPos.y:(meta.endPos.y-meta.startPos.y+0.1)/(nbFrame):meta.endPos.y+0.1);
        locations.z = round(meta.startPos.z:(meta.endPos.z-meta.startPos.z+0.1)/(nbFrame):meta.endPos.z+0.1);
        
    end
end