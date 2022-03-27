classdef UtrackFileInfo < FileInfo
    properties (Constant = true)
        detectionExt      = '.detection.mat';
        trackingExt       = '.tracking.mat';
        swimtrackerExt    = '.swimtracker.mat';
        allSwimtrackerExt = '.all_swimtracker_mixGauss.mat';
        swimtrackerExt_filtered = '.swimtracker_filtered.mat';
        tableExt          = '.table.txt';
        FASTfileExt       = '.FAST.mat';
        detectionDat      = 'movieInfo';
    end
    methods
        function f = UtrackFileInfo(file)
            f = f@FileInfo(file);
        end
    end
end
