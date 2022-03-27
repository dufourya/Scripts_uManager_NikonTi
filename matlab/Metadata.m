classdef Metadata<handle
    properties (Constant)
        pixel_size_key = 'CurrentPixelSize_um';
        image_height_key = 'ImageHeight';
        image_width_key = 'ImageWidth';
    end
    properties (SetAccess = private)
        data = '';
        file = '';
        bytes_per_pixel = '';
        pixel_type = '';
    end
    methods
        function m = Metadata(file)
            m.file = file;
        end
        
        function read(obj)
            if ~exist(obj.file,'file')
                error(['metafile ''' obj.file ''' is not on current path'])
            end
            fid = fopen(obj.file,'r');
            obj.data= textscan(fid,'%[^;];%[^;];%[^\n]');
            fclose(fid);
            
            if ~isempty(obj.getFilePixelTypeString())
                obj.pixel_type = obj.getFilePixelTypeString();
                obj.pixel_type = obj.pixel_type{1};
                if strcmp('*uint16',obj.pixel_type)
                    obj.bytes_per_pixel = 2;
                elseif strcmp('*uint8',obj.pixel_type)
                    obj.bytes_per_pixel = 1;
                end
            else
                obj.pixel_type = obj.getCameraPixelTypeString();
                if strcmp('16bit',obj.pixel_type)
                    obj.bytes_per_pixel = 2;
                    obj.pixel_type = '*uint16';
                elseif strcmp('8bit',obj.pixel_type)
                    obj.bytes_per_pixel = 1;
                    obj.pixel_type = '*uint8';
                end
            end
        end
        
        function create(obj, mmc)
            metadata = mmc.getLoadedDevices();
            mmc.waitForSystem;
            obj.data = cell(1,3);
            for i=1:metadata.size()
                device = char(metadata.get(i-1));
                deviceProp = mmc.getDevicePropertyNames(device);
                mmc.waitForSystem;
                for j = 1:deviceProp.size()
                    prop = char(deviceProp.get(j-1));
                    propVal = char(mmc.getProperty(device, prop));
                    mmc.waitForSystem;
                    obj.data{1} = [obj.data{1}; {device}];
                    obj.data{2} = [obj.data{2}; {prop}];
                    obj.data{3} = [obj.data{3}; {propVal}];
                end
            end
            
            obj.add('XYStage', 'XPosition_um', ...
                sprintf('%f', mmc.getXPosition('XYStage')));
            obj.add('XYStage', 'YPosition_um', ...
                sprintf('%f', mmc.getYPosition('XYStage')));
            obj.add('TIZDrive', 'ZPosition_um', ...
                sprintf('%f', mmc.getPosition('TIZDrive')));
            obj.add('Camera', 'CurrentPixelSize_um', ...
                sprintf('%f', mmc.getPixelSizeUm()));
            obj.add('Camera', 'ImageWidth', ...
                sprintf('%f', mmc.getImageWidth()));
            obj.add('Camera', 'ImageHeight', ...
                sprintf('%f', mmc.getImageHeight()));
        end
        
        % Reading/writing
        function write(obj)
            fid = fopen(obj.file,'w');
            for i=1:numel(obj.data{1})
                category = obj.data{1}(i);
                key      = obj.data{2}(i);
                val      = obj.data{3}(i);
                fwrite(fid, sprintf('%s;%s;%s\n', category{1}, key{1}, val{1}));
            end
            fclose(fid);
        end
        
        function add(obj, category, key, value)
            key_idx = find(strcmp(obj.data{2}, key));
            if size(key_idx) == 1
                error(['key with name ''' key ''' already exists.']);
            else
                obj.data{1} = [obj.data{1}; {category}];
                obj.data{2} = [obj.data{2}; {key}];
                obj.data{3} = [obj.data{3}; {value}];
            end
        end
        
        function set(obj, category, key, val)
            key_idx = find(strcmp(obj.data{2}, key));
            if size(key_idx) > 1
                error(['more than one key with name ''' key '''.']);
            end
            obj.data{3}(key_idx) = {val};
        end
        
        function append(obj, category, key, val)
            obj.add(category, key, val);
            obj.write();
        end
        
        % Getters
        function val = getVal(obj, device, key)
            val = obj.data{1,3}(ismember(obj.data{1,2},key) & ...
                ismember(obj.data{1,1},device));
        end
        
        function shutter = getShutter(obj)
            shutter = obj.getVal('Arduino-Switch','State');
        end
        
        function exposure = getExposure(obj)
            exposure = str2double(obj.getVal(obj.getCameraName(),'Exposure'));
        end
        
        function camera_name = getCameraName(obj)
            camera_name = obj.getVal('Core','Camera');
        end
        
        function pixel_size = getPixelSize(obj)
            pixel_size = str2double(obj.getVal('Camera', obj.pixel_size_key));
        end
        
        function interval = getImageIntervalMs(obj)
            interval = str2double(obj.getVal('SequenceAcquisition', 'ActualIntervalBurst-ms'));
        end
        
        function iptg = getIPTG(obj)
            iptg = str2double(obj.getVal('Sample', 'IPTG'));
        end
        
        function source = getSource(obj)
            source = str2double(obj.getVal('Sample', 'Source'));
        end
        
        function sink = getSink(obj)
            sink = str2double(obj.getVal('Sample', 'Sink'));
        end
        
        function height = getImageHeightPixel(obj)
            height = str2double(obj.getVal('Camera', obj.image_height_key));
        end
        
        function width = getImageWidthPixel(obj)
            width = str2double(obj.getVal('Camera', obj.image_width_key));
        end
        
        function width = getImageWidthUm(obj)
            width = obj.getImageWidthPixel() * obj.getPixelSize();
        end
        
        function height = getImageHeightUm(obj)
            height = obj.getImageHeightPixel() * obj.getPixelSize();
        end
        
        function camera_pixel_type_str = getCameraPixelTypeString(obj)
            camera_pixel_type_str = obj.getVal(obj.getCameraName(), 'PixelType');
        end
        
%         function bin = getBinning(obj)
%             bin_str = obj.getVal(obj.getCameraName(), 'Binning');
%             bin = str2double(bin_str{1}(1));
%         end
        
        function pix_type = getPixelType(obj)
            pix_type = obj.pixel_type;
        end
        
        function file_pixel_type_str = getFilePixelTypeString(obj)
            file_pixel_type_str = obj.getVal('SequenceAcquisition','FilePixelType');
        end
        
        function number_images = getNumberOfImages(obj)
            number_images = str2double(obj.getVal('SequenceAcquisition', 'NumberImages'));
        end
        
        function bytes_per = getBytesPerPixel(obj)
            bytes_per = obj.bytes_per_pixel;
        end
        
        function n_before = getNImagesBeforeFreeze(obj)
            n_before = str2double(obj.getVal('SequenceAcquisition', 'NImagesBeforeFreeze'));
            if isempty(n_before)
                n_before = str2double(obj.getVal('SequenceAcquisition', 'NumberImages'));
            end
        end
        
        function xcorrection = getXCorrection(obj)
            xcorrection = str2double(obj.getVal('ObjectiveOffset', 'Xcorrection'));
        end
        
        function ycorrection = getYCorrection(obj)
            ycorrection = str2double(obj.getVal('ObjectiveOffset', 'Ycorrection'));
        end
        
        function xpos = getXPos(obj)
            xpos = str2double(obj.getVal('XYStage', 'XPosition_um'));
        end
        
        function ypos = getYPos(obj)
            ypos = str2double(obj.getVal('XYStage', 'YPosition_um'));
        end
        
        function zpos = getZPos(obj)
            zpos = str2double(obj.getVal('TIZDrive', 'ZPosition_um'));
        end
        
        function datetime = getDateStr(obj)
            % format is 05-Jun-2014
            date = obj.getVal('Experiment', 'Date');
            % format is 8 : 43 PM
            time = obj.getVal('Experiment', 'Time');
            datetime = datestr([date{1}, ' ' time{1}], ...
                'dd-mmm-yyyy HH:MM:SS PM');
        end
        
        function starttime = getIncubationStartTime(obj)
            starttime = [];
            d = obj.getVal('Sample', 'IncubationStart');
            if ~isempty(d)
                starttime = datevec(d, 'dd-mmm-yyyy HH:MM:SS');
            end
        end
        
        function elapsed = getElapsedTimeSec(obj)
            elapsed = str2double(obj.getVal('Experiment', 'RelativeTime_sec'));
        end
        
        function clone = getClone(obj)
            clone = str2double(obj.getVal('Sample', 'Clone'));
        end
        
        function clone = getReplicate(obj)
            clone = str2double(obj.getVal('Sample', 'Replicate'));
        end
        
        % Setters
        function setPixelSize(obj, size)
            obj.set('Camera', obj.pixel_size_key, num2str(size, '%g'));
        end
        
        function setImageHeightPixel(obj, height)
            obj.set('Camera', obj.image_height_key, num2str(height, '%d'));
        end
        
        function setImageWidthPixel(obj, width)
            obj.set('Camera', obj.image_width_key, num2str(width, '%d'));
        end
        
        % Query state
        function is_x_mirrored = isMirroredX(obj)
            is_x_mirrored = str2double(obj.getVal(obj.getCameraName(), 'TransposeMirrorX'));
        end
        
        function is_y_mirrored = isMirroredY(obj)
            is_y_mirrored = str2double(obj.getVal(obj.getCameraName(), 'TransposeMirrorY'));
        end
        
        function reversed = isReversed(obj)
            reversed = str2double(obj.getVal('Sample','Reversed'));
        end
        
        function fluorescent = isFluorescent(obj)
            if strcmp(obj.getShutter(), '2')
                fluorescent = 1;
            elseif strcmp(obj.getShutter(), '1')
                fluorescent = 0;
            else
                error('Don''t recognize shutter state.');
            end
        end
        
        % Append
        function appendPixelSize(obj, size)
            obj.append('Camera', obj.pixel_size_key, num2str(size, '%g'));
        end
        
        function appendImageHeightPixel(obj, height)
            obj.append('Camera', obj.image_height_key, num2str(height, '%d'));
        end
        
        function appendImageWidthPixel(obj, width)
            obj.append('Camera', obj.image_width_key, num2str(width, '%d'));
        end
        
        function resolution = getResolution(obj)
            objective = obj.getVal('TINosePiece','Label');
            objective = objective{1};
            resolution = 0;
            switch objective
                case '1-Plan Fluor 4x NA 0.13 Dry'
                    resolution = 2.12/2; %um
                case '2-Plan Fluor 10x NA 0.30 Dry'
                    resolution = 0.92/2; %um
                case '3-Plan Fluor 40x NA 0.75 Dry'
                    resolution = 0.37/2; %um
                case '5-Plan Fluor 100x NA 1.30 Oil'
                    resolution = 0.21/2; %um
            end
        end
    end
end
