function generateMicroscopeDiaConfigs
    
    fileID = fopen(which('DufourLab_Scope_Channel_Phase.cfg'),'w');
    %     fileID = fopen('test.txt','w');
    
    fprintf(fileID,'# Group: Channel\n');
    
    objectives = {'4X','6X','10X','15X','40X','60X','100X','150X'};
    objstate = [0 0 1 1 2 2 4 4];
    switchstate = [0 1 0 1 0 1 0 1];
    filters = {'DAPI','CFP','GFP','YFP','RFP','EMPTY'};
    filtsate = [0 1 2 3 4 5];
    binning = {'1x1','2x2'};
    exposure = [10 20 50 100 200 500 1000 2000 5000];
    
    for k1 = 1:numel(objectives)
        for k2 = 1:numel(filters)
            for k3 = 1:numel(binning)
                for k4 = 1:numel(exposure)
                    name = sprintf('DIA_%s_%s_%s_%dms',objectives{k1},filters{k2},binning{k3},exposure(k4));
                    fprintf(fileID,'\n# Preset: %s\n',name);
                    fprintf(fileID,'ConfigGroup,Channel,%s,Andor Zyla 4.2,Binning,%s\n',name,binning{k3});
                    fprintf(fileID,'ConfigGroup,Channel,%s,Arduino-Switch,State,1\n',name);
                    fprintf(fileID,'ConfigGroup,Channel,%s,Arduino-Shutter,OnOff,0\n',name);
                    if exposure(k4)<50
                        fprintf(fileID,'ConfigGroup,Channel,%s,Andor Zyla 4.2,PixelReadoutRate,540 MHz - fastest readout\n',name);
                        fprintf(fileID,'ConfigGroup,Channel,%s,Arduino-Switch,Blanking Mode,Off\n',name);
                    else
                        fprintf(fileID,'ConfigGroup,Channel,%s,Andor Zyla 4.2,PixelReadoutRate,200 MHz - lowest noise\n',name);
                        fprintf(fileID,'ConfigGroup,Channel,%s,Arduino-Switch,Blanking Mode,On\n',name);
                    end
                    fprintf(fileID,'ConfigGroup,Channel,%s,TINosePiece,State,%d\n',name,objstate(k1));
                    fprintf(fileID,'ConfigGroup,Channel,%s,Objective,State,%d\n',name,switchstate(k1));
                    fprintf(fileID,'ConfigGroup,Channel,%s,TIFilterBlock1,State,%d\n',name,filtsate(k2));
                    fprintf(fileID,'ConfigGroup,Channel,%s,TILightPath,State,1\n',name);
                    fprintf(fileID,'ConfigGroup,Channel,%s,Andor Zyla 4.2,Exposure,%d\n',name,exposure(k4));
                end
            end
        end
    end
end