classdef FileInfo
    properties (Constant = true, Access = public)
        binExt  = '.bin';
        tiffExt = '.tif';
        aviExt  = '.mp4';
        metaExt = '.meta';
        svgExt  = '.svg';
        pngExt  = '.png';
        backgroundExt = strcat('_background', FileInfo.tiffExt);
        picturesExt = '.fast.mat';
        picsMetaExt = strcat('.fast', FileInfo.metaExt);
        gradBeforeExt = strcat('_before', FileInfo.tiffExt);
        gradAfterExt = strcat('_after', FileInfo.tiffExt);
        gradBeforeMetaExt = strcat('_before', FileInfo.metaExt);
        gradAfterMetaExt = strcat('_after', FileInfo.metaExt);
        sourceExt = strcat('_source', FileInfo.tiffExt);
        sinkExt = strcat('_sink', FileInfo.tiffExt);
        sourceMetaExt = strcat('_source', FileInfo.metaExt);
        sinkMetaExt = strcat('_sink', FileInfo.metaExt);
        maskExt = strcat('_mask', FileInfo.tiffExt);
        
        tracksDat = 'tracks';
        tracksFinal = 'tracksFinal';
    end
    properties (SetAccess = private)
        full_path = '';
        name_ = '';
        bin_file = '';
        background_file = '';
        avi_file = '';
        meta_file = '';
        source_img = '';
        sink_img = '';
        source_meta = '';
        sink_meta = '';
    end
    methods
        function f = FileInfo(file)
            f.full_path = fullfile(cd, file);
            [p, n, e] = fileparts(file);
            f.name_ = n;
            f.bin_file = strcat(f.name, f.binExt);
            f.background_file = strcat(f.name, f.backgroundExt);
            f.avi_file = strcat(f.name, f.aviExt);
            f.meta_file = strcat(f.name, f.metaExt);
            f.source_img = strcat(f.name, f.sourceExt);
            f.source_meta = strcat(f.name, f.sourceMetaExt);
            f.sink_img = strcat(f.name, f.sinkExt);
            f.sink_meta = strcat(f.name, f.sinkMetaExt);
        end
        
        function source = sourceImageFile(obj)
            source = obj.source_img;
        end
        
        function sink = sinkImageFile(obj)
            sink = obj.sink_img;
        end
        
        function meta = sinkMetaFile(obj)
            meta = obj.sink_meta;
        end
        
        function meta = sourceMetaFile(obj)
            meta = obj.source_meta;
        end
        
        function n = name(obj)
            n = obj.name_;
        end
        function cfan = currentFolderAndName(obj)
            cfan = obj.current_folder_and_name;
        end
        
        function b = binFile(obj)
            b = obj.bin_file;
        end
        
        function back = backgroundFile(obj)
            back = obj.background_file;
        end
        
        function avi = aviFile(obj)
            avi = obj.avi_file;
        end
        
        function meta = metaFile(obj)
            meta = obj.meta_file;
        end
        
        function grad = gradientAfterFile(obj)
            grad = strcat(obj.name, obj.gradAfterExt);
        end
        function grad = gradientBeforeFile(obj)
            grad = strcat(obj.name, obj.gradBeforeExt);
        end
        
        function grad = gradientMetaAfterFile(obj)
            grad = strcat(obj.name, obj.gradAfterMetaExt);
        end
        
        function grad = gradientMetaBeforeFile(obj)
            grad = strcat(obj.name, obj.gradBeforeMetaExt);
        end
        
        function detect = detectionFile(obj)
            detect = strcat(obj.name, obj.detectionExt);
        end
        
        function track = trackingFile(obj)
            track = strcat(obj.name, obj.trackingExt);
        end
        
        function swim = swimtrackerFile(obj)
            swim = strcat(obj.name, obj.swimtrackerExt);
        end
        
        function pics = picturesFile(obj)
            pics = strcat(obj.name, obj.picturesExt);
        end
        
        function FAST = FASTfile(obj)
            FAST = strcat(obj.name, obj.FASTfileExt);
        end
        function tab = tableFile(obj)
            tab = strcat(obj.name, obj.tableExt);
        end
        
        function all = concatSwimtrackerFile(obj)
            all = strcat(obj.name, obj.allSwimtrackerExt);
        end
        
        function png = pngFile(obj)
            png = strcat(obj.name, obj.pngExt);
        end
        
        function svg = svgFile(obj)
            svg = strcat(obj.name, obj.svgExt);
        end
        
        function diagpng = diagpngFile(obj)
            diagpng = strcat(obj.name, '.diagnostics', obj.pngExt);
        end
        
        function diagsvg = diagsvgFile(obj)
            diagsvg = strcat(obj.name, '.diagnostics', obj.svgExt);
        end
        
        function mask = maskFile(obj)
            mask = strcat(obj.name, obj.maskExt);
        end
    end
end
