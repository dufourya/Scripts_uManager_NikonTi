classdef PixelInfo
    properties (SetAccess = private)
        camera = '';
        x10 = 0;
        x15 = 0;
        x100 = 0;
        x150 = 0;
        array_width = 0;
        array_height = 0;
    end    
    methods
        function pix_info = PixelInfo(camera)
            if strcmp(camera, 'ixon')
                pix_info.camera = 'ixon';
                pix_info.x10 = 1.3064;
                pix_info.x15 = 0.8724;
                pix_info.x100 = 0.1315;
                pix_info.x150 = 0.0878;
                pix_info.array_width = 1024;
                pix_info.array_height = 1024;
            elseif strcmp(camera, 'flash')
                pix_info.camera = 'flash';
                pix_info.x10 = 0.6539;
                pix_info.x15 = 0.4354;
                pix_info.x100 = 0.0654;
                pix_info.x150 = 0.0435;
                pix_info.array_width = 2048;
                pix_info.array_height = 2048; 
            else
                error('pixelSize:argChk', 'camera must be ''ixon'' or ''flash''');
            end
        end
        
        function size = getUmPerPixel(obj, mag) 
            size = obj.(strcat('x',num2str(mag)));
        end
        function width = getImageWidthPixel(obj)
            width = obj.array_width;
        end
        function height = getImageHeightPixel(obj)
            height = obj.array_height;
        end
    end
end