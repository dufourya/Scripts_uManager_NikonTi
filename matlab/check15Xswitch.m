function check15Xswitch(mmc)
    WarnWave = [sin(1:.6:400), sin(1:.7:400), sin(1:.4:400)];

    obj15 = str2double(mmc.getProperty('Objective','State'));
    sensor15 = str2double(mmc.getProperty('Arduino-Input','AnalogInput0'));
    
    while obj15 == 0 && sensor15 ~= 0
        sound(WarnWave,2*8192);
        uiwait(warndlg('Disengage 1.5X switch'));
        obj15 = str2double(mmc.getProperty('Objective','State'));
        sensor15 = str2double(mmc.getProperty('Arduino-Input','AnalogInput0'));
    end
    
    while obj15 ~= 0 && sensor15 == 0
        sound(WarnWave,2*8192);
        uiwait(warndlg('Engage 1.5X switch'));
        obj15 = str2double(mmc.getProperty('Objective','State'));
        sensor15 = str2double(mmc.getProperty('Arduino-Input','AnalogInput0'));
    end
end