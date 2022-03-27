function reloadMicroscopeChannels(mmc)

all_path = strsplit(path,';');
code_path = all_path{~cellfun('isempty',(strfind(all_path,'Microscope\config')))};

channel_phase = fullfile(code_path, 'DufourLab_Scope_Channel_Phase.cfg');
channel_fluo = fullfile(code_path, 'DufourLab_Scope_Channel_Fluo.cfg');

mmc.loadSystemConfiguration(channel_phase);
mmc.loadSystemConfiguration(channel_fluo);
mmc.waitForSystem();

fprintf('Reloading channel configuration successful!\n\n');
fprintf('Available channel configurations:\n');
disp(char(mmc.getAvailableConfigs('Channel').toArray()));