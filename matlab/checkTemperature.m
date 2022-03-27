function checkTemperature(mmc)
    f_name = getFunctionName();
    camera = char(mmc.getCameraDevice());
    
    if strcmp('Andor', camera)
        max_temp = -69;
        fprintf('[%s] Max CCD temp set to %d C\n', f_name, max_temp);
      
        camera_temp = str2double(mmc.getProperty(camera, 'CCDTemperature'));
        while (camera_temp > max_temp)
            fprintf('[%s] Camera temp is %d C\n', ...
                    f_name, camera_temp);
            pause(5);
            camera_temp = str2double(mmc.getProperty(camera, 'CCDTemperature'));
        end
        fprintf('[%s] Camera temp at %d C, continuing...\n', ...
                f_name, camera_temp);
    elseif strcmp('Andor Zyla 4.2', camera)
        camera_temp = char(mmc.getProperty(camera,'TemperatureStatus'));
        if ~strcmp(camera_temp,'Stabilised')
            fprintf('[%s] Camera temperature is %s, please wait...\n', ...
                    f_name, camera_temp);
        end
        while ~strcmp(camera_temp,'Stabilised')
            pause(1);
            camera_temp = char(mmc.getProperty(camera,'TemperatureStatus'));
        end
        fprintf('[%s] Camera temperature is %s\n', ...
                f_name, camera_temp);
    end
end