classdef RadFileInfo < FileInfo
    properties (Constant = true)
        detectionExt      = '.rad_detection.mat';
        trackingExt       = '.rad_tracking.mat';
        swimtrackerExt    = '.rad_swimtracker.mat';
        tableExt          = '.table.txt';
        detectionDat      = 'rad_detection';
        FASTfileExt       = '.FAST_tracks.mat';
    end
    methods
        function f = RadFileInfo(file)
            f = f@FileInfo(file);
        end
    end
end
