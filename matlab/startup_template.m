warndlg('Do not forget to sync Github before starting Matlab!');
usr = getenv('USERNAME');
micpath = genpath(strcat('C:\Users\',usr,'\Documents\GitHub\Microscope'));
micpath = strsplit(micpath,';');
ind = cellfun(@isempty,(strfind(micpath,'.git')));
micpath = micpath(ind);
micpath = strjoin(micpath,';');
addpath(micpath);
fid = fopen(strcat('C:\Users\',usr,'\Documents\GitHub\Microscope\.git\FETCH_HEAD'));
git_sha = textscan(fid,'%s');
fclose(fid);
clear fid;
git_sha = git_sha{1};
curr_date = datestr(date,'yyyy-mm-dd');
if ~exist(strcat('D:\',usr,'\',curr_date),'dir')
    mkdir(strcat('D:\',usr,'\',curr_date));
end
cd(strcat('D:\',usr,'\',curr_date));
diary(sprintf('Log_%s_%s.txt',curr_date,usr));
disp(datestr(now));
disp('SwimTracker version:');
disp(git_sha);