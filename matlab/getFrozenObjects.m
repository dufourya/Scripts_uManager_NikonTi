function last_objects = getFrozenObjects(image_file, cutoff, show_im)
%% read frame timestamp from file metadata

[path, ~, ~] = fileparts(image_file);
if isempty(path)
    path = pwd();
end

track_method = 'radcenter';
if strcmp(track_method, 'radcenter')
    image_info = RadFileInfo(image_file);
elseif strcmp(track_method, 'utrack')
    image_info = UtrackFileInfo(image_file);
else
    error(['do not recognize tracking method ''' track_method '''.'])
end

if ~exist(image_info.bin_file, 'file')
    error(['could not find ''' image_info.bin_file ''' on path.'])
end

metadata = Metadata(fullfile(path,image_info.metaFile));
metadata.read();

numImagesbeforeFreeze = metadata.getNImagesBeforeFreeze();
imHeight = metadata.getImageHeightPixel();
imWidth = metadata.getImageWidthPixel();
interval = metadata.getImageIntervalMs() / 1000;
pixel_type = metadata.getPixelType();

%% calculate image background to be substracted from
%     sample_time = 30;
%     sample_time = min(sample_time, interval*numImagesbeforeFreeze);
%     block_size = floor(sample_time/interval);
%
%     background = calculateBackground(image_info.bin_file, metadata, block_size);
%     background = squeeze(background(:,:,end));

fid = fopen(strcat(image_info.name_,'.background'),'r');
background = fread(fid,pixel_type);
fclose(fid);
background = rot90(reshape(background,[imWidth imHeight]));

fid = fopen(strcat(image_info.name_,'.lastimage'),'r');
last_frame = fread(fid,pixel_type);
fclose(fid);
last_frame = rot90(reshape(last_frame,[imWidth imHeight]));

last_objects = process_frame(last_frame,background);

z = (last_objects(:,3)-mean(last_objects(:,3)))./std(last_objects(:,3));
%remove objects of unusual sizes
last_objects(abs(z)>cutoff,:)=[];


z = (last_objects(:,4)-mean(last_objects(:,4)))./std(last_objects(:,4));
%remove objects of unusual intensity
last_objects(abs(z)>cutoff,:)=[];

if show_im==1
    figure,
    imshow(double(last_frame)-double(background),[]);
    hold on
    scatter(last_objects(:,1),last_objects(:,2));
    hold off
end

return;