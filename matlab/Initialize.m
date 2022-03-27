function mmc = Initialize()
    
    all_path = strsplit(path,';');
    code_path = all_path{~cellfun('isempty',(strfind(all_path,'Microscope\config')))};
    bf_path = all_path{~cellfun('isempty',(strfind(all_path,'bfmatlab')))};
    %
    %     mmcpath = genpath('C:\Micro-Manager-1.4');
    %     addpath(mmcpath);
    
    generateMicroscopeDiaConfigs;
    generateMicroscopeEpiConfigs;
    
    channel_phase = fullfile(code_path, 'DufourLab_Scope_Channel_Phase.cfg');
    channel_fluo = fullfile(code_path, 'DufourLab_Scope_Channel_Fluo.cfg');
    pixel_size = fullfile(code_path, 'DufourLab_Scope_PixelSize.cfg');
    config_system = fullfile(code_path, 'DufourLab_Scope_System.cfg');
    
    if ~evalin('base','exist(''mmc'',''var'')')
        javaaddpath(fullfile(bf_path,'bioformats_package.jar'),'-end');
        javaaddpath('C:\Micro-Manager-2.0\plugins\Micro-Manager\MMCoreJ.jar','-end');
        import mmcorej.*;
        mmc = CMMCore;
    else
        mmc = evalin('base','mmc');
    end
    %     try
    %         config = fullfile(code_path, 'DufourLab_Scope_Config_Fluo_Oko.cfg');
    %         %         mmc = CMMCore;
    %         mmc.loadSystemConfiguration(config);
    %         mmc.loadSystemConfiguration(channel_fluo);
    %     catch
    try
        mmc.reset();
        config = fullfile(code_path, 'DufourLab_Scope_Config_Fluo.cfg');
        mmc.loadSystemConfiguration(config);
        mmc.loadSystemConfiguration(channel_fluo);
        %             fprintf('Oko temperature control not available.\n');
    catch
        %             try
        %                 config = fullfile(code_path, 'DufourLab_Scope_Config_Oko.cfg');
        %                 mmc.reset();
        %                 mmc.loadSystemConfiguration(config);
        %                 fprintf('Epifluorescence not available.\n');
        %             catch
        try
            mmc.reset();
            config = fullfile(code_path, 'DufourLab_Scope_Config.cfg');
            mmc.loadSystemConfiguration(config);
            %             fprintf('Epifluorescence and Oko temperature control not available.\n');
            fprintf('Epifluorescence not available.\n');
        catch
            
            mmc.reset();
            error('Initialization unsuccessful. Check if the desired components are turned ON.');
        end
    end
    % end
    % end
    
    mmc.loadSystemConfiguration(channel_phase);
    mmc.loadSystemConfiguration(pixel_size);
    mmc.loadSystemConfiguration(config_system);
    mmc.setConfig('System','Startup');
    mmc.waitForSystem();
    
    fprintf('Loading system configuration successful!\n\n');
    %     fprintf('Available channel configurations:\n');
    %     disp(char(mmc.getAvailableConfigs('Channel').toArray()));
    
    
    FileObj      = java.io.File(pwd);
    total_bytes  = FileObj.getTotalSpace;
    usable_bytes = FileObj.getUsableSpace;
    
    if usable_bytes/total_bytes < 0.2
        warndlg('Disk almost full! Free some space or risk losing data.','Warning');
    end
    
end