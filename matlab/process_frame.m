function objects = process_frame(frame, background)

background = double(background) / mean(double(background(:)));
meanf = mean(double(frame(:)));
grayframe = background-(double((frame))./meanf);
grayframe = grayframe - min(grayframe(:));
grayframe = grayframe / max(grayframe(:));
% grayframe = uint16(grayframe);
% figure, imshow(grayframe,[]);

rangeframe = double(rangefilt(grayframe));
rangeframe = rangeframe - min(rangeframe(:));
rangeframe = rangeframe/ max(rangeframe(:));
% rangeframe = uint16(rangeframe);
% figure, imshow(rangeframe,[]);

bwrgframe = im2bw(rangeframe,mean(rangeframe(:)) + 3*std(rangeframe(:)));
bwrgframe = imfill(bwrgframe,'holes');
% figure, imshow(bwrgframe);
bwframe = im2bw(grayframe,(0.5*std(grayframe(:))) + mean(grayframe(:)));
%  figure, imshow(bwframe);
bwframe = bwframe & bwrgframe;
filtw = round(size(bwframe,1)/341);
bwframe = medfilt2(bwframe,[filtw filtw]);
%bwframe = medfilt2(bwrgframe,[3 3]);
% figure, imshow(bwframe);

stats = regionprops(bwframe, grayframe, 'Area', 'Centroid','MeanIntensity','BoundingBox');
if numel(stats) == 0
    objects = zeros(1,10);
    return;
end

% idlarge = find([stats.Area]>=(mean([stats.Area])+2*std([stats.Area])));

% for id=idlarge,
%     box = stats(id).BoundingBox;
%     offset = 1;
%     box = [max(box(1)-offset,1) max(box(2)-offset,1) min(box(3)+2*offset,size(frame,1)) min(box(4)+2*offset,size(frame,2))];
%     object = imcrop(grayframe, box);
%     %     figure, imagesc(object);
%     %     axis image
%     %     colormap('Gray')
%     objectbw = imcrop(bwframe, box);
%     objectw = object;
%     objectw(~objectbw) = -Inf;
%     L = watershed(-objectw);
%     newstats = regionprops(L, object, 'Area', 'Centroid','MeanIntensity','BoundingBox');
%     for iid=1:numel(newstats)
%         newstats(iid).Centroid = newstats(iid).Centroid + box(1:2);
%     end
%     stats = [stats; newstats];
% end

% idlarge = [stats.Area]>=(mean([stats.Area])+2*std([stats.Area]));
% stats(idlarge) = [];

objects = zeros(numel(stats),10);
coord = cell2mat({stats.Centroid}');
objects(:,1) = coord(:,1);
objects(:,2) = coord(:,2);
objects(:,3) = [stats.Area]';
objects(:,4) = double([stats.MeanIntensity]');

% imshow(grayframe,[]);
% hold on
% scatter(coord(:,1),coord(:,2));
% hold off

end