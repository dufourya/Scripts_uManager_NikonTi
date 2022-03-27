function coordinates = Live(mmc,config,coordinates)

global Live

display_size_width = 1280;
display_size_height = 1280;

if exist('Live','var') && isfield(Live,'Figure') && ishandle(Live.Figure)
    figure(Live.Figure);
else
    Live.Figure = figure('pos',[100 15 display_size_width+95 ...
        display_size_height], 'Toolbar','none', ...
        'Menubar','none','Name','Live','NumberTitle', ...
        'off','IntegerHandle','off');
end

h = Live.Figure;

%mmc.setConfig('System','Startup');
if nargin <2 || isempty(config)
    config = 'Startup';
    mmc.setConfig('System',config);
else
    mmc.setConfig('Channel',config);
    check15Xswitch(mmc);
end

if strcmp(mmc.getProperty('Arduino-Switch', 'Sequence'),'On')
    mmc.stopPropertySequence('Arduino-Switch','State');
    mmc.setProperty('Arduino-Switch', 'Sequence','Off');
end

stage_pos.x = mmc.getXPosition('XYStage');
stage_pos.y = mmc.getYPosition('XYStage');
stage_pos.z = mmc.getPosition('TIZDrive');
prev_stage_pos = stage_pos;

if nargin<3 || isempty(coordinates) || size(coordinates,2)~=2
    coordinates = [stage_pos.x stage_pos.y];
else
    coordinates = cat(1, [stage_pos.x stage_pos.y], coordinates);
end

mmc.waitForSystem();

mmc.setAutoShutter(0);

camera = char(mmc.getCameraDevice());

exposure = mmc.getExposure();

intensity = 0;
maxintensity = 0;

devices = cell(mmc.getLoadedDevices().toArray());

imgtmp = zeros(display_size_width,display_size_height);
width = mmc.getImageWidth();
height = mmc.getImageHeight();
pixelSize = mmc.getPixelSizeUm();
exitlive = false;
zoom = false;
normalize = false;
crossmark = false;
circle = false;
pfs = false;
show_color = true;
pfs_status = 'Off';
pfstext = char(mmc.getProperty('TIPFSOffset','Position'));
remove_background = false;
num_bg = 0;
num_obj = 0;
pixelType = 'uint16';
circ_buff_size_mb = 10000;

cursorPointX = 0;
cursorPointY = 0;

okosettemp = '?';
okocurrtemp = '?';
okosethum = '?';
okocurrhum = '?';

numObj = 0;

%     img1 = zeros(display_size_width, display_size_height);

objective = char(mmc.getProperty('TINosePiece','Label'));
objective = objective(3:min(18,length(objective)));
background_image = zeros(width,height);
[xc,yc] = cylinder(150,500);
xc = display_size_width/2 + round(xc(1,:));
yc = display_size_height/2 + round(yc(1,:));

epishutter = 0;
diashutter = 0;
shot = 1;

stage_tic = tic;

blocks = ...
    cell(mmc.getAllowedPropertyValues('TIFilterBlock1','Label').toArray());
currentblock = ...
    find(strcmp(char(mmc.getProperty('TIFilterBlock1','Label')),blocks));
strblocks = blocks{1};
for j = 2:numel(blocks)
    strblocks = strcat(strblocks,'|',blocks{j});
end

mmc.setProperty('Arduino-Switch','State', ...
    num2str(diashutter + epishutter*2));

set(Live.Figure,'CloseRequestFcn',@closeGUI);

fpos = get(Live.Figure,'pos');
lppos = [0 95 95 fpos(4)-95];
axpos = [96 1 fpos(3)-95 fpos(4)];

Live.Panel = uipanel('units','pixels','pos',lppos,...
    'BorderType','none');

Live.Axes = axes('Parent',Live.Figure,'units','pixels','pos',axpos, ...
    'Color',[0 0 0],'xtick',[],'ytick',[],'XLim',[0.5 display_size_width+0.5],...
    'YLim',[0.5 display_size_height+0.5],'NextPlot','replacechildren','box','off');
%      set(Live.Axes,'ButtonDownFcn', @getMousePositionOnImage);
%     set(Live.Axes,'HitTest', 'off');

Live.Histaxes = axes('Parent',Live.Figure,'units','pixels','pos',[0 0 96 90], ...
    'Color',[0 0 0],'xtick',[],'ytick',[]);

Live.Image = imshow(imgtmp,'parent',Live.Axes);
set(Live.Image,'ButtonDownFcn', @getMousePositionOnImage);
%      set(Live.Image,'HitTest','off');

[counts,binLocations] = imhist(imgtmp);
Live.Histogram = bar(Live.Histaxes, binLocations, log(counts));
% set(Live.Image, 'Pointer', 'cross');
pan off % Panning will interfere with this code

%Camera
uicontrol(Live.Panel,'units','pixels','Position',[5 fpos(4)-95-20 80 15], ...
    'Style','text','String','Live','HorizontalAlignment','left');

Live.StartBtn = uicontrol(Live.Panel,'units','pixels','Position', ...
    [5 fpos(4)-95-40 40 20],'String','Start','callback', ...
    @StartFn);
Live.StopBtn = uicontrol(Live.Panel,'units','pixels','Position', ...
    [50 fpos(4)-95-40 40 20],'String','Stop','callback',@StopFn);

%Shutter
uicontrol(Live.Panel,'units','pixels','Position',[5 fpos(4)-95-65 80 15], ...
    'Style','text','String','Shutter','HorizontalAlignment','left');

Live.shutterDia = uicontrol(Live.Panel,'units','pixels', ...
    'Position', [5 fpos(4)-95-85 40 20], ...
    'Style','togglebutton', ...
    'String','Dia','enable','on', ...
    'callback',@DiaFn);
Live.shutterEpi = uicontrol(Live.Panel,'units','pixels', ...
    'Position', [50 fpos(4)-95-85 40 20], ...
    'Style','togglebutton', ...
    'String','Epi','enable','off', ...
    'callback',@EpiFn);

%Image
uicontrol(Live.Panel,'units','pixels','Position',[5 fpos(4)-95-110 55 15], ...
    'Style','text','String','Image','HorizontalAlignment','left');

Live.norm = uicontrol(Live.Panel,'units','pixels','Position', ...
    [5 fpos(4)-95-130 30 20],'Style','togglebutton','String', ...
    'N','enable','on','Value',false, ...
    'callback',@NormFn);

Live.zoom = uicontrol(Live.Panel,'units','pixels','Position', ...
    [35 fpos(4)-95-130 30 20],'Style','togglebutton','String', ...
    'Z','enable','on','Value',false,'callback',@ZoomFn);

Live.backgroung = uicontrol(Live.Panel,'units','pixels','Position', ...
    [65 fpos(4)-95-130 30 20],'Style','togglebutton','String', ...
    'B','enable','on','Value',false, ...
    'callback',@backgroundSub);

Live.num_objs = uicontrol(Live.Panel,'units','pixels','Position',[65 fpos(4)-95-110 25 15], ...
    'Style','text','String',num2str(num_obj),'HorizontalAlignment','left','enable','off');

%Overlay
uicontrol(Live.Panel,'units','pixels','Position',[5 fpos(4)-95-155 80 15], ...
    'Style','text','String','Overlay','HorizontalAlignment','left');

Live.crossmark = uicontrol(Live.Panel,'units','pixels', ...
    'Position',[5 fpos(4)-95-175 30 20],'String','+','Style','togglebutton', ...
    'Value',false,'Callback',@drawCross,'enable','on');

Live.circle = uicontrol(Live.Panel,'units','pixels', ...
    'Position',[35 fpos(4)-95-175 30 20],'String','O','Style','togglebutton', ...
    'Value',false,'Callback',@drawCircle,'enable','on');

Live.saturation = uicontrol(Live.Panel,'units','pixels', ...
    'Position',[65 fpos(4)-95-175 30 20],'String','RGB', 'Style','togglebutton',...
    'Value',true,'Callback',@toggleColor,'enable','on');

%     Live.focus = uicontrol(Live.Panel,'units','pixels', ...
%         'Position',[5 fpos(4)-95-245 40 20],'String','Focus', ...
%         'Callback',@fullFocus,'enable','off');
%
%     Live.focustext = uicontrol(Live.Panel,'units','pixels','Style','text', ...
%         'Position',[50 fpos(4)-95-245 40 20], ...
%         'String',num2str(0),'callback',@fullFocus, ...
%         'enable','off','HorizontalAlignment','left');

%Exposure
uicontrol(Live.Panel,'units','pixels','Position',[5 fpos(4)-95-300 80 15], ...
    'Style','text','String','Exposure','HorizontalAlignment','left');

Live.ExpoMinus = uicontrol(Live.Panel,'units','pixels','Position', ...
    [5 fpos(4)-95-320 20 20],'String','-', ...
    'callback',@ExpoFn,'enable','on');
Live.ExpoPlus = uicontrol(Live.Panel,'units','pixels','Position', ...
    [25 fpos(4)-95-320 20 20],'String','+', ...
    'callback',@ExpoFn,'enable','on');
Live.expotext = uicontrol(Live.Panel,'units','pixels','Style','edit', ...
    'Position',[50 fpos(4)-95-320 40 20], ...
    'String',num2str(round(exposure)), ...
    'callback',@ExpoFn,'enable','on');

%Block
uicontrol(Live.Panel,'units','pixels','Position',[5 fpos(4)-95-340 80 15], ...
    'Style','text','String','Block','HorizontalAlignment','left');
Live.block = uicontrol(Live.Panel,'units','pixels', ...
    'Position',[5 fpos(4)-95-360 85 20],'Style','popup', ...
    'String',strblocks,'Callback',@changeBlock, ...
    'enable','on','Value',currentblock);

% Light
uicontrol(Live.Panel,'units','pixels','Position',[5 fpos(4)-95-410 80 15],'Style', ...
    'text','String','Light','HorizontalAlignment','left');

Live.intensitytext = uicontrol(Live.Panel,'units','pixels','Style', ...
    'text','Position',[5 fpos(4)-95-430 30 20], ...
    'String',num2str(intensity), ...
    'enable','on','HorizontalAlignment','left');
Live.maxintensitytext = uicontrol(Live.Panel,'units','pixels','Style', ...
    'text','Position',[40 fpos(4)-95-430 30 20], ...
    'String',num2str(maxintensity), ...
    'enable','on','HorizontalAlignment','left');


% Stage
uicontrol(Live.Panel,'units','pixels','Position',[5 fpos(4)-95-455 80 15],'Style', ...
    'text','String','Stage','HorizontalAlignment','left');

uicontrol(Live.Panel,'units','pixels','Position',[5 fpos(4)-95-470 10 15],'Style', ...
    'text','String','X','HorizontalAlignment','left');

Live.xpos = uicontrol(Live.Panel,'units','pixels','Style', ...
    'text','Position',[20 fpos(4)-95-470 70 15], ...
    'String',num2str(stage_pos.x), ...
    'enable','on','HorizontalAlignment','left');

uicontrol(Live.Panel,'units','pixels','Position',[5 fpos(4)-95-485 10 15],'Style', ...
    'text','String','Y','HorizontalAlignment','left');

Live.ypos = uicontrol(Live.Panel,'units','pixels','Style', ...
    'text','Position',[20 fpos(4)-95-485 70 15], ...
    'String',num2str(stage_pos.y), ...
    'enable','on','HorizontalAlignment','left');

uicontrol(Live.Panel,'units','pixels','Position',[5 fpos(4)-95-500 10 15],'Style', ...
    'text','String','Z','HorizontalAlignment','left');

Live.zpos = uicontrol(Live.Panel,'units','pixels','Style', ...
    'text','Position',[20 fpos(4)-95-500 70 15], ...
    'String',num2str(stage_pos.z), ...
    'enable','on','HorizontalAlignment','left');

uicontrol(Live.Panel,'units','pixels','Position',[5 fpos(4)-95-540 80 15],'Style', ...
    'text','String','Objective','HorizontalAlignment','left');

Live.objective = uicontrol(Live.Panel,'units','pixels','Style', ...
    'text','Position',[5 fpos(4)-95-560 85 20], ...
    'String',objective, ...
    'enable','on','HorizontalAlignment','left');

uicontrol(Live.Panel,'units','pixels','Position',[5 fpos(4)-95-585 80 15],'Style', ...
    'text','String','Configuration','HorizontalAlignment','left');

Live.config = uicontrol(Live.Panel,'units','pixels','Style', ...
    'text','Position',[5 fpos(4)-95-615 85 30], ...
    'String',config, ...
    'enable','on','HorizontalAlignment','left');

%Objects
uicontrol(Live.Panel,'units','pixels','Position',[5 205 90 15],'Style', ...
    'text','String','Objects','HorizontalAlignment','center');

Live.objtext = uicontrol(Live.Panel,'units','pixels','Style','edit', ...
    'Position',[30 180 40 20], ...
    'String',num2str(numObj), ...
    'callback',@ObjFn,'enable','on');

Live.prevObj = uicontrol(Live.Panel,'units','pixels', ...
    'Position', [5 155 40 20],'String','Prev', ...
    'Callback',@prevObj,'enable','on');

Live.nextObj = uicontrol(Live.Panel,'units','pixels', ...
    'Position', [50 155 40 20],'String','Next', ...
    'Callback',@nextObj,'enable','on');

Live.addObj = uicontrol(Live.Panel,'units','pixels', ...
    'Position', [5 130 40 20],'String','Add', ...
    'Callback',@addObj,'enable','on');

Live.remObj = uicontrol(Live.Panel,'units','pixels', ...
    'Position', [50 130 40 20],'String','Rem', ...
    'Callback',@remObj,'enable','on');

%Cursor coordinates
uicontrol(Live.Panel,'units','pixels','Position',[5 100 80 15],'Style', ...
    'text','String','Cursor position','HorizontalAlignment','center');

Live.cursorPoint = uicontrol(Live.Panel,'units','pixels','Style', ...
    'text','Position',[5 85 80 15], ...
    'String',sprintf('%g | %g', cursorPointX, cursorPointY), ...
    'enable','on','HorizontalAlignment','center');

Live.movestage = uicontrol(Live.Panel,'units','pixels', ...
    'Position', [5 60 85 20],'String','MoveStage', ...
    'Callback',@moveStage,'enable','on');

%Snapshot
Live.snap = uicontrol(Live.Panel,'units','pixels', ...
    'Position', [5 10 85 20],'String','Snapshot', ...
    'Callback',@snapShot,'enable','on');

%Sola
if sum(strcmp('Sola',devices))
    set(Live.shutterEpi, 'enable', 'on');
    mmc.setProperty('Sola','State',num2str(1));
    mmc.setProperty('Sola','White_Enable',num2str(1));
    %mmc.setProperty('Sola','White_Level',num2str(100));
    solalevel = str2double(mmc.getProperty('Sola','White_Level'));
    
    uicontrol(Live.Panel,'units','pixels','Position',[5 fpos(4)-95-387.5 45 15],'Style', ...
        'text','String','Sola','HorizontalAlignment','left');
    
    Live.sola = uicontrol(Live.Panel,'units','pixels','Style','edit', ...
        'Position',[50 fpos(4)-95-390 40 20], ...
        'String',num2str(solalevel), ...
        'callback',@SolaFn,'enable','on');
    
end

if sum(strcmp('TIPFSStatus',devices))
    
    pfs_status = mmc.getProperty('TIPFSStatus','State');
    pfstext = char(mmc.getProperty('TIPFSOffset','Position'));
    if strcmp('On',pfs_status)
        pfs = true;
    else
        pfs = false;
    end
    
    %Focus
    uicontrol(Live.Panel,'units','pixels','Position',[5 fpos(4)-95-200 80 15], ...
        'Style','text','String','Focus','HorizontalAlignment','left');
    
    Live.pfs =  uicontrol(Live.Panel,'units','pixels','Position', ...
        [5 fpos(4)-95-220 30 20],'Style','togglebutton','String', ...
        'PFS','Value',pfs,'enable','on','callback',@PFSFn);
    
    Live.pfstext = uicontrol(Live.Panel,'units','pixels','Style','edit', ...
        'Position',[40 fpos(4)-95-220 50 20], ...
        'String',pfstext(1:end-1), 'callback',@PFSFn, 'enable','on','HorizontalAlignment','left');
    
    pfsstatus = char(mmc.getProperty('TIPFSStatus','Status'));
    
    Live.pfsstatus = uicontrol(Live.Panel,'units','pixels','Style','text', ...
        'Position',[5 fpos(4)-95-255 90 30], ...
        'String',pfsstatus, 'callback',@PFSFn, 'enable','off','HorizontalAlignment','left');
end

Live.autofocus =  uicontrol(Live.Panel,'units','pixels','Position', ...
    [5 fpos(4)-95-275 85 20],'String','Auto Focus','Style','togglebutton',...
    'enable','off','callback',@AutoFocusFn);

if sum(strcmp('OKO Control Server',devices))
    
    %Oko-lab
    uicontrol(Live.Panel,'units','pixels','Position',[5 fpos(4)-95-580 80 15],'Style', ...
        'text','String','Oko-lab','HorizontalAlignment','left');
    
    uicontrol(Live.Panel,'units','pixels','Position',[5 fpos(4)-95-600 10 15],'Style', ...
        'text','String','T','HorizontalAlignment','left');
    
    Live.okosettemp = uicontrol(Live.Panel,'units','pixels','Style', ...
        'text','Position',[20 fpos(4)-95-600 30 15], ...
        'String',okosettemp, ...
        'enable','on','HorizontalAlignment','left');
    Live.okocurrtemp = uicontrol(Live.Panel,'units','pixels','Style', ...
        'text','Position',[55 fpos(4)-95-600 35 15], ...
        'String',okocurrtemp, ...
        'enable','on','HorizontalAlignment','left');
    
    uicontrol(Live.Panel,'units','pixels','Position',[5 fpos(4)-95-620 10 15],'Style', ...
        'text','String','H','HorizontalAlignment','left');
    Live.okosethum = uicontrol(Live.Panel,'units','pixels','Style', ...
        'text','Position',[20 fpos(4)-95-620 30 15], ...
        'String',okosethum, ...
        'enable','on','HorizontalAlignment','left');
    
    Live.okocurrhum = uicontrol(Live.Panel,'units','pixels','Style', ...
        'text','Position',[55 fpos(4)-95-620 35 15], ...
        'String',okocurrhum, ...
        'enable','on','HorizontalAlignment','left');
    
    Live.okoupdate =  uicontrol(Live.Panel,'units','pixels','Position', ...
        [15 fpos(4)-95-645 65 20],'Style','pushbutton','String', ...
        'Update','enable','on','callback',@OkoFn);
    
    okosettemp = char(mmc.getProperty('H301-T Unit-BL','Set-Point'));
    okocurrtemp = char(mmc.getProperty('H301-T Unit-BL','Temperature'));
    okosethum = char(mmc.getProperty('H301-HM-ACTIVE','Set-Point'));
    okocurrhum = char(mmc.getProperty('H301-HM-ACTIVE','Humidity'));
    mmc.waitForSystem();
    set(Live.okosettemp,'String',okosettemp(1:4));
    set(Live.okocurrtemp,'String',okocurrtemp(1:4));
    set(Live.okosethum,'String',okosethum(1:4));
    set(Live.okocurrhum,'String',okocurrhum(1:4));
end

    function SolaFn(hObject, ~)
        solalevel = round(str2double(get(hObject,'String')));
        solalevel = max(min(solalevel, 100),0);
        mmc.setProperty('Sola','White_Level',num2str(solalevel));
        mmc.waitForDevice('Sola');
        set(Live.sola, 'String', num2str(solalevel));
    end

    function ObjFn(hObject, ~)
        numObj = str2double(get(hObject,'String'));
        numObj = max(min(numObj, size(coordinates,1)-1),0);
        mmc.setXYPosition(mmc.getXYStageDevice(),coordinates(numObj+1,1),coordinates(numObj+1,2));
        mmc.waitForDevice(mmc.getXYStageDevice())
        set(Live.objtext, 'String', num2str(numObj));
    end

    function nextObj(~, ~)
        numObj = numObj + 1;
        if numObj>size(coordinates,1)-1
            numObj = 0;
        end
        mmc.setXYPosition(mmc.getXYStageDevice(),coordinates(numObj+1,1),coordinates(numObj+1,2));
        mmc.waitForDevice(mmc.getXYStageDevice())
        set(Live.objtext, 'String', num2str(numObj));
    end

    function prevObj(~, ~)
        numObj = numObj - 1;
        if numObj<0
            numObj = size(coordinates,1)-1;
        end
        mmc.setXYPosition(mmc.getXYStageDevice(),coordinates(numObj+1,1),coordinates(numObj+1,2));
        mmc.waitForDevice(mmc.getXYStageDevice())
        set(Live.objtext, 'String', num2str(numObj));
    end

    function addObj(~,~)
        coordinates = cat(1,coordinates,[mmc.getXPosition('XYStage') mmc.getYPosition('XYStage')]);
        numObj = size(coordinates,1)-1;
        set(Live.objtext, 'String', num2str(numObj));
    end

    function remObj(~,~)
        if numObj<size(coordinates,1) && numObj>0
            coordinates(numObj+1,:) = [];
            numObj = 0;
            set(Live.objtext, 'String', num2str(numObj));
        end
    end


    function getMousePositionOnImage(~, ~)
        cursorPoint = get(Live.Axes, 'CurrentPoint');
        cursorPointX = round((cursorPoint(1,1)-display_size_width/2) * pixelSize*width/display_size_width);
        cursorPointY = round((cursorPoint(1,2)-display_size_height/2) * pixelSize*height/display_size_height);
        set(Live.cursorPoint,'String',sprintf('%g | %g', cursorPointX, cursorPointY));
        
    end

    function moveStage(~, ~)
        mmc.setXYPosition(mmc.getXYStageDevice(),mmc.getXPosition()+cursorPointX,mmc.getYPosition()+cursorPointY);
        mmc.waitForDevice(mmc.getXYStageDevice());
        stage_pos.x = mmc.getXPosition();
        stage_pos.y = mmc.getYPosition();
        cursorPointX = 0;
        cursorPointY = 0;
        set(Live.cursorPoint,'String',sprintf('%g | %g', cursorPointX, cursorPointY));
    end

    function OkoFn(~, ~)
        set(Live.okoupdate,'Enable','off');
        %         if hObject == Live.okosettemp
        %             okosettempin = get(hObject,'String');
        %             if str2double(okosettempin)<25
        %                 okosettempin = '25';
        %             elseif str2double(okosettempin)>45
        %                 okosettempin = '45';
        %             end
        %             mmc.setProperty('H301-T Unit-BL','Set Set-Point', okosettempin);
        %             okosettemp = char(mmc.getProperty('H301-T Unit-BL','Set-Point'));
        %             okocurrtemp = char(mmc.getProperty('H301-T Unit-BL','Temperature'));
        %             while(min([str2double(okosettemp) str2double(okocurrtemp)])<25)
        %                 pause(0.5)
        %                 okosettemp = char(mmc.getProperty('H301-T Unit-BL','Set-Point'));
        %                 okocurrtemp = char(mmc.getProperty('H301-T Unit-BL','Temperature'));
        %             end
        %             set(Live.okosettemp,'String',okosettemp(1:4));
        %             set(Live.okocurrtemp,'String',okocurrtemp(1:4));
        %
        %         elseif hObject == Live.okosethum
        %             okosethumin = get(hObject,'String');
        %             if str2double(okosethumin)<76
        %                 okosethumin = '76';
        %             elseif str2double(okosethumin)>95
        %                 okosethumin = '95';
        %             end
        %             mmc.setProperty('H301-HM-ACTIVE','Set Set-Point', okosethumin);
        %             okosethum = char(mmc.getProperty('H301-HM-ACTIVE','Set-Point'));
        %             okocurrhum = char(mmc.getProperty('H301-HM-ACTIVE','Humidity'));
        %             while(min([str2double(okosethum) str2double(okocurrhum)])<76)
        %                 pause(0.5)
        %                 okosethum = char(mmc.getProperty('H301-HM-ACTIVE','Set-Point'));
        %                 okocurrhum = char(mmc.getProperty('H301-HM-ACTIVE','Humidity'));
        %             end
        %             set(Live.okosethum,'String',okosethum(1:4));
        %             set(Live.okocurrhum,'String',okocurrhum(1:4));
        %
        %         elseif hObject == Live.okoupdate
        okocurrhum = char(mmc.getProperty('H301-HM-ACTIVE','Humidity'));
        okocurrtemp = char(mmc.getProperty('H301-T Unit-BL','Temperature'));
        okosethum = char(mmc.getProperty('H301-HM-ACTIVE','Set-Point'));
        okosettemp = char(mmc.getProperty('H301-T Unit-BL','Set-Point'));
        mmc.waitForSystem();
        while(str2double(okocurrhum)*str2double(okocurrtemp)*str2double(okosethum)*str2double(okosettemp))<10
            okocurrhum = char(mmc.getProperty('H301-HM-ACTIVE','Humidity'));
            okocurrtemp = char(mmc.getProperty('H301-T Unit-BL','Temperature'));
            okosethum = char(mmc.getProperty('H301-HM-ACTIVE','Set-Point'));
            okosettemp = char(mmc.getProperty('H301-T Unit-BL','Set-Point'));
            mmc.waitForSystem();
        end
        pause(0.01);
        set(Live.okosettemp,'String',okosettemp(1:4));
        set(Live.okocurrtemp,'String',okocurrtemp(1:4));
        set(Live.okosethum,'String',okosethum(1:4));
        set(Live.okocurrhum,'String',okocurrhum(1:4));
        
        set(Live.okoupdate,'Enable','on');
    end

    function backgroundSub(~, ~)
        remove_background = ~remove_background;
        if ~remove_background
            background_image = 0 * background_image;
            num_bg = 0;
            num_obj = 0;
            set(Live.num_objs,'String',num2str(num_obj));
        end
    end

    function AutoFocusFn(hObject, ~)
        
        button_state = get(hObject,'Value');
        
        if button_state
            set(Live.autofocus,'String','Cancel');
            imgtmp = mmc.getLastImage();
            imgtmp = typecast(imgtmp, pixelType);
            tmp = double(imgtmp(:));
            contrast = var(tmp)/mean(tmp);
            direction = 1;
            first = 1;
            lastcontrast = contrast;
            
            if ~contains(objective,'100x')
                steps = 0.025*2^6;
            elseif ~contains(objective,'10x')
                steps = 0.025*2^9;
            elseif ~contains(objective,'40x')
                steps = 0.025*2^7;
            elseif ~contains(objective,'4x')
                steps = 0.025*2^10;
            else
                steps = 0;
            end
            drawnow;
            
            if strcmp(char(mmc.getProperty('TIPFSStatus','Status')),'Locked in focus')
                
                zp = str2double(mmc.getProperty('TIPFSOffset','Position'));
                
                focusData = [zp contrast];
                
                while abs(steps) > 0.02 && button_state
                    ind = find(focusData(:,1) == zp+(direction*steps));
                    
                    if isempty(ind)
                        mmc.setProperty('TIPFSOffset','Position',zp+(direction*steps));
                        mmc.waitForDevice('TIPFSOffset');
                        while ~strcmp(char(mmc.getProperty('TIPFSStatus','Status')),'Locked in focus')
                            pause(0.1);
                        end
                        pause(0.25);
                        imgtmp = mmc.getLastImage();
                        imgtmp = typecast(imgtmp, pixelType);
                        tmp = double(imgtmp(:));
                        contobject = var(tmp)/mean(tmp);
                        focusData = [focusData; zp+(direction*steps) contobject];
                    else
                        contobject = focusData(ind,2);
                    end
                    
                    if contobject > contrast
                        lastcontrast = contrast;
                        contrast = contobject;
                        zp = zp+(direction*steps);
                        first = 0;
                    else
                        if ~first
                            steps = steps / 2;
                        else
                            first = 0;
                        end
                        if contobject < lastcontrast
                            direction = -direction;
                        end
                    end
                    button_state = get(hObject,'Value');
                end
                mmc.setProperty('TIPFSOffset','Position',zp);
                mmc.waitForDevice('TIPFSStatus');
            else
                pfs_status = 'Off';
                pfs = false;
                Live.pfs.Value = pfs;
                mmc.setProperty('TIPFSStatus','State',pfs_status);
                %                 pfstext = char(mmc.getProperty('TIPFSOffset','Position'));
                %                 pfsstatus = char(mmc.getProperty('TIPFSStatus','Status'));
                %                 set(Live.pfsstatus, 'String', pfsstatus);
                %                 set(Live.pfstext, 'String', pfstext(1:end-1));
                
                zp =  mmc.getPosition('TIZDrive');
                focusData = [zp contrast];
                
                while abs(steps) > 0.02 && button_state
                    %                     drawnow;
                    ind = find(focusData(:,1) == zp+(direction*steps));
                    
                    if isempty(ind)
                        mmc.setPosition('TIZDrive',zp+(direction*steps));
                        mmc.waitForDevice('TIZDrive');
                        imgtmp = mmc.getLastImage();
                        imgtmp = typecast(imgtmp, pixelType);
                        tmp = double(imgtmp(:));
                        contobject = var(tmp)/mean(tmp);
                        focusData = [focusData; zp+(direction*steps) contobject];
                        %             fprintf('%.7g %.4g %.4g\n',zp+(direction*steps), steps, contobject);
                    else
                        contobject = focusData(ind,2);
                    end
                    
                    if contobject > contrast
                        lastcontrast = contrast;
                        contrast = contobject;
                        zp = zp+(direction*steps);
                        first = 0;
                    else
                        if ~first
                            steps = steps / 2;
                        else
                            first = 0;
                        end
                        if contobject < lastcontrast
                            direction = -direction;
                        end
                    end
                    button_state = get(hObject,'Value');
                end
                mmc.setPosition('TIZDrive',zp)
                mmc.waitForDevice('TIZDrive');
            end
            set(Live.autofocus,'String','Auto Focus');
            set(hObject,'Value',0);
        else
            set(Live.autofocus,'String','Auto Focus');
        end
    end

    function drawCross(~, ~)
        crossmark = ~crossmark;
    end

    function drawCircle(~, ~)
        circle = ~circle;
    end

    function toggleColor(hObject, ~)
        show_color = get(hObject,'Value');
    end

    function DiaFn(hObject, ~)
        diashutter = get(hObject,'Value');
        mmc.setShutterOpen(diashutter + epishutter>0);
        mmc.setProperty('Arduino-Switch','State',num2str(diashutter + epishutter*2));
        stage_tic = tic;
    end

    function EpiFn(hObject, ~)
        epishutter =  get(hObject,'Value');
        mmc.setProperty('Arduino-Switch','State',num2str(diashutter + epishutter*2));
        mmc.setProperty('Sola','State',epishutter);
        mmc.setProperty('Sola','White_Enable',epishutter);
        %mmc.setProperty('Sola','White_Level',100*epishutter);
        mmc.setShutterOpen(diashutter + epishutter>0);
        stage_tic = tic;
    end

    function snapShot(~, ~)
        while exist(strcat('snapshot',num2str(shot,'%0.5d'),'.tiff'),'file')
            shot = shot+1;
        end
        imwrite(rotateFrame(imgtmp,mmc),strcat('snapshot', ...
            num2str(shot,'%0.5d'),'.tiff'),'tiff');
    end

    function changeBlock(hObject, ~)
        mmc.setProperty('TIFilterBlock1', 'Label', ...
            blocks{get(hObject,'Value')})
        stage_tic = tic;
    end

    function ZoomFn(~, ~)
        zoom = ~zoom;
        stage_tic = tic;
    end

    function NormFn(~, ~)
        normalize = ~normalize;
        stage_tic = tic;
    end

    function PFSFn(hObject, ~)
        if hObject == Live.pfs
            pfs = ~pfs;
            if pfs
                pfs_status = 'On';
            else
                pfs_status = 'Off';
            end
            mmc.setProperty('TIPFSStatus','State',pfs_status);
            pfstext = char(mmc.getProperty('TIPFSOffset','Position'));
        elseif hObject == Live.pfstext
            pfstext = get(hObject,'String');
            pfsoffset = round(str2double(pfstext));
            if pfsoffset < 0
                pfsoffset = 0;
            elseif pfsoffset > 1000
                pfsoffset = 1000;
            end
            mmc.setProperty('TIPFSOffset','Position',pfsoffset);
        end
        %         pause(0.1);
        pfsstatus = char(mmc.getProperty('TIPFSStatus','Status'));
        set(Live.pfsstatus, 'String', pfsstatus);
        set(Live.pfstext, 'String', pfstext(1:end-1));
    end

    function ExpoFn(hObject, ~)
        if hObject == Live.expotext
            exposure = int16(str2double(get(hObject,'String')));
        elseif hObject==Live.ExpoMinus
            exposure = exposure - 10;
        elseif hObject==Live.ExpoPlus
            exposure = exposure + 10;
        end
        if exposure>1000, exposure = int16(1000);
        elseif exposure <1, exposure = int16(1); end
        mmc.setExposure(exposure);
        set(Live.expotext, 'String',num2str(round(exposure)));
    end

    function StartFn(~, ~)
        if ~mmc.isSequenceRunning()
            set(Live.ExpoMinus, 'enable', 'off');
            set(Live.ExpoPlus, 'enable', 'off');
            set(Live.expotext, 'enable', 'off');
            set(Live.autofocus, 'enable', 'on');
            %             set(Live.snap, 'enable', 'on');
            %             set(Live.focus, 'enable', 'off');
            
            camera_device = mmc.getCameraDevice();
            if strcmp('Andor Zyla 4.2',char(camera_device))
                if strcmp('Mono16',char(mmc.getProperty(camera,'PixelEncoding')))
                    real_bit = 16;
                else
                    real_bit = 12;
                end
            end
            
            Live.Histaxes.XLim = [0 (2^real_bit-1)];
            Live.Histaxes.NextPlot = 'replacechildren';
            
            exitlive = false;
            
            mmc.setCircularBufferMemoryFootprint(circ_buff_size_mb);
            mmc.initializeCircularBuffer();
            mmc.prepareSequenceAcquisition(camera);
            mmc.startContinuousSequenceAcquisition(0);
            
            if mmc.getBytesPerPixel == 2
                pixelType = 'uint16';
            else
                pixelType = 'uint8';
            end
            
            while ~exitlive
                %                 pause(0.01);
                if (mmc.getRemainingImageCount() > 0)
                    
                    mmc.waitForImageSynchro();
                    imgtmp = mmc.getLastImage();
                    imgtmp = typecast(imgtmp, pixelType);
                    [counts,binLocations] = imhist(imgtmp);
                    Live.Histogram = bar(Live.Histaxes, binLocations, log(counts));
                    Live.Histogram.BarWidth = 1;
                    Live.Histaxes.YLim = [0 max(log(counts))+1];
                    Live.Histaxes.Box = 'off';
                    
                    img1 = double(rotateFrame(imgtmp,mmc));
                    zeropx = img1 < 100;
                    
                    img1 = img1 ./ (2^real_bit-1);
                    saturatedpx = isnan(img1) | img1 == 1;
                    
                    if remove_background
                        if abs(stage_pos.x - prev_stage_pos.x) || ...
                                abs(stage_pos.y - prev_stage_pos.y)
                            background_image = 0 * background_image;
                            num_bg = 0;
                            prev_stage_pos = stage_pos;
                            stage_tic = tic;
                        elseif toc(stage_tic) < 0.5
                            background_image = 0 * background_image;
                            num_bg = 0;
                        end
                        
                        delta_background = img1 - background_image;
                        img1 = img1 - background_image + 0.5;
                        CC = bwconncomp(~imbinarize(img1,max(0,min(1,0.5-6*std(img1(:))))));
                        num_obj = CC.NumObjects;
                        set(Live.num_objs,'String',num2str(num_obj));
                        
                        num_bg = num_bg + 1;
                        background_image = background_image + delta_background/num_bg;
                    end
                    
                    
                    intensity = (10^5)*round(var(img1(:))/mean(img1(:)),3,'significant');
                    
                    if normalize
                        img1 = img1 - prctile(img1(:),0.001);
                        img1 = img1 ./ prctile(img1(:),99.999);
                    end
                    
                    img1 = uint8(255*img1);
                    
                    maxintensity = sum(saturatedpx(:));
                    
                    stage_pos.x = mmc.getXPosition('XYStage');
                    stage_pos.y = mmc.getYPosition('XYStage');
                    stage_pos.z = mmc.getPosition('TIZDrive');
                    pfstext = char(mmc.getProperty('TIPFSOffset','Position'));
                    pfsstatus = char(mmc.getProperty('TIPFSStatus','Status'));
                    
                    set(Live.intensitytext, 'String',num2str(min(9999,intensity)));
                    set(Live.maxintensitytext, 'String',num2str(min(9999,maxintensity)));
                    set(Live.pfstext, 'String', pfstext(1:end-1));
                    set(Live.pfsstatus, 'String', pfsstatus);
                    
                    set(Live.xpos, 'String', num2str(stage_pos.x));
                    set(Live.ypos, 'String', num2str(stage_pos.y));
                    set(Live.zpos, 'String', num2str(stage_pos.z));
                    
                    imgred = img1;
                    imgblue = img1;
                    imggreen = img1;
                    
                    if show_color
                        imgred(saturatedpx) = 255;
                        imgred(zeropx) = 50;
                        imgblue(saturatedpx) = 50;
                        imgblue(zeropx) = 255;
                        imggreen(saturatedpx) = 50;
                        imggreen(zeropx) = 50;
                    end
                    
                    imgcol = cat(3,imgred,imggreen,imgblue);
                    
                    if width > display_size_width
                        if zoom
                            imgcol = imcrop(imgcol, ...
                                [floor(width/2)-display_size_width/2 ...
                                floor(height/2)-display_size_height/2 ...
                                display_size_width display_size_height]);
                        else
                            imgcol = imresize(imgcol, ...
                                display_size_width/width, ...
                                'bilinear');
                        end
                    else
                        if zoom
                            imgcol = imresize(imgcol, ...
                                2*display_size_width/width, ...
                                'bilinear');
                            imgcol = imcrop(imgcol, [display_size_width/2 ...
                                display_size_height/2 ...
                                display_size_width ...
                                display_size_height]);
                        else
                            imgcol = imresize(imgcol, ...
                                display_size_width/width, ...
                                'bilinear');
                        end
                    end
                    
                    if crossmark
                        imgcol(2:4:end,display_size_width/2,2) = 255;
                        imgcol(display_size_height/2,2:4:end,2) = 255;
                        imgcol(2:4:end,display_size_width/2,1) = 0;
                        imgcol(display_size_height/2,2:4:end,1) = 0;
                        imgcol(2:4:end,display_size_width/2,3) = 0;
                        imgcol(display_size_height/2,2:4:end,3) = 0;
                    end
                    
                    if circle
                        for i = 1:2:numel(xc)
                            imgcol(xc(i),yc(i),2) = 255;
                            imgcol(xc(i),yc(i),1) = 0;
                            imgcol(xc(i),yc(i),3) = 0;
                        end
                    end
                    
                    Live.Image = imshow(imgcol,'parent',Live.Axes);
                    %                     set(Live.Image,'HitTest','off');
                    set(Live.Image,'ButtonDownFcn', @getMousePositionOnImage);
                    drawnow;
                    pause(0.001);
                    %                     mmc.clearCircularBuffer();
                    mmc.waitForImageSynchro();
                end
            end
            mmc.stopSequenceAcquisition();
            %             mmc.clearCircularBuffer();
            mmc.waitForSystem();
        end
    end

    function StopFn(~, ~)
        exitlive = true;
        set(Live.ExpoMinus, 'enable', 'on');
        set(Live.ExpoPlus, 'enable', 'on');
        set(Live.expotext, 'enable', 'on');
        set(Live.autofocus, 'enable', 'off');
        set(Live.shutterDia,'Value', 0);
        set(Live.shutterEpi,'Value', 0);
        epishutter = 0;
        diashutter = 0;
        mmc.setShutterOpen(0);
        %         set(Live.snap, 'enable', 'off');
        %         set(Live.focus, 'enable', 'on');
        background_image = 0 * background_image;
        num_bg = 0;
        mmc.clearCircularBuffer();
    end

    function closeGUI(~, ~)
        exitlive = true;
        mmc.stopSequenceAcquisition();
        if sum(strcmp('Sola',devices))
            mmc.setProperty('Sola','White_Enable',0);
            mmc.setProperty('Sola','White_Level',0);
            mmc.setProperty('Sola','State',0);
        end
        mmc.setShutterOpen(0);
        mmc.waitForSystem();
        delete(h);
    end

waitfor(h);
coordinates = coordinates(2:end,:);

end
