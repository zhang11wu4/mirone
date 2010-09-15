function varargout = bg_map(varargin)
% Helper window to select a basemap image in geogs

%	Copyright (c) 2004-2010 by J. Luis
%
%	This program is free software; you can redistribute it and/or modify
%	it under the terms of the GNU General Public License as published by
%	the Free Software Foundation; version 2 of the License.
%
%	This program is distributed in the hope that it will be useful,
%	but WITHOUT ANY WARRANTY; without even the implied warranty of
%	MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
%	GNU General Public License for more details.
%
%	Contact info: w3.ualg.pt/~jluis/mirone
% --------------------------------------------------------------------
%
%	On several instances of this code apear the dimensions 5400 & 2700.
%	They come from the size of the 'etopo4.jpg' image. If another image would
%	be used, those figures need to be adapted (as well as those of the tilles)

	hObject = figure('Tag','figure1','Visible','off','doublebuffer','on');
	bg_map_LayoutFcn(hObject);
	handles = guihandles(hObject);
	move2side(hObject,'center');
 
	if (numel(varargin) > 0)
		handles.f_path = varargin{1};
	else
		lix = getappdata(0);
		if (isfield(lix,'MIRONE_DIRS'))
			handles.f_path = [lix.MIRONE_DIRS.home_dir filesep 'data' filesep];
		elseif (exist(['data' filesep 'etopo4_logo.jpg'], 'file') == 2)
			handles.f_path = ['data' filesep];
		else
			errordlg('Don''t know where I am and therefore cannot load image file. By By.','Error')
			delete(hObject),	return
		end
	end

	logo = imread([handles.f_path 'etopo4_logo.jpg']);
	image(logo,'Parent',handles.axes1);
	set(handles.axes1,'Visible','off');
    
	handles.hRects = zeros(4,8);
	for (m=1:4)
		for (n=1:8)
			xp = [(n-1) n n (n-1)] * 64; 
			yp = [(m-1) (m-1) m m] * 64; 
			h = patch('XData',xp,'YData',yp,'FaceColor','none','EdgeColor',[.9 .9 .9],'LineWidth',1);
			%h = rectangle('Position',[(n-1) (m-1) 1 1]*64,'EdgeColor',[.7 .7 .7],'LineWidth',1);
			set(h,'ButtonDownFcn',{@bdn_bgTile,hObject},'UserData',[m n])
			handles.hRects(m,n) = h;
		end
	end
	handles.hBigRect = patch('XData',[0 512 512 0],'YData',[0 0 256 256],'FaceColor','none','Vis','off');
	set(handles.hBigRect,'ButtonDownFcn',{@bdn_bgTile,hObject})

	im = uint8(ones(20,28,3) * 255);
	im(5:6,5:25,:) = 0;			% Top  line
	im(17:18,5:25,:) = 0;		% Bottom
	im(5:18,5:6,:) = 0;			% Left
	im(5:18,24:25,:) = 0;		% Right
	set(handles.toggle_region,'CData', im);

	% Choose default command line output for bg_map
	handles.output = hObject;
	guidata(hObject, handles);

	set(hObject,'Visible','on');
	% UIWAIT makes bg_map wait for user response (see UIRESUME)
	uiwait(handles.figure1);

	handles = guidata(hObject);
	try
		x_inc = diff(handles.output.X) / (size(handles.output.img,2)-1);
		y_inc = diff(handles.output.Y) / (size(handles.output.img,1)-1);
		handles.output.head = [handles.output.X handles.output.Y 0 255 0 x_inc y_inc];
	catch
		handles.output = [];
	end
	varargout{1} = handles.output;
    delete(handles.figure1);

% -----------------------------------------------------------------------------------------
function bdn_bgTile(obj,eventdata,hFig)
    handles = guidata(hFig);
	if (get(handles.radio_WorldMap,'Val'))
		out.img = get_img(handles.figure1, obj, [handles.f_path 'etopo4.jpg'], '-U');
		out.X = [-180 180];		out.Y = [-90 90];
		if (get(handles.radio_360,'Val'))		% Must swap left and right halfs
			out.img = [out.img(:,2700:5400,:) out.img(:,1:2700,:)];
			out.X = [0 360];
		end
	else
		ud = get(gcbo,'UserData');
		x_min = -180 + (ud(2)-1)*45;	x_max = x_min + 45;
		if (get(handles.radio_360,'Val') && x_min < 0)
			x_min = x_min + 360;		x_max = x_max + 360;
		end
		y_min = 90 - ud(1)*45;			y_max = y_min + 45;
		n1 = max(1,(ud(2)-1)*675);		n2 = min(n1 + 675 + 1, 5400);
		m1 = max(1,(ud(1)-1)*675);		m2 = min(m1 + 675 + 1, 2700);
		opt_r = sprintf('-r%d/%d/%d/%d', n1, n2, m1, m2);
		out.img = get_img(handles.figure1, obj, [handles.f_path 'etopo4.jpg'], opt_r, '-U');
		out.X = [x_min x_max];      out.Y = [y_min y_max];
	end
	out.imgName = 'Base image';
    handles.output = out;   guidata(handles.figure1, handles);  uiresume(handles.figure1);

% ----------------------------------------------------------------------------------------
function img = get_img(hFig, hObj, varargin)
% Read the image and give an idea of time taken to do it
	h = hObj;
	origName = get(hFig, 'Name');
	set(hFig, 'Name', 'WAIIITT --- READING IMAGE')
	set(h,'FaceColor','y', 'FaceAlpha', 0.4),		drawnow
	img = gdalread(varargin{:});
	set(h,'FaceColor','none', 'FaceAlpha', 0)
	set(hFig, 'Name', origName)

% ----------------------------------------------------------------------------------------
function toggle_region_CB(hObject, handles)
% Select a rectangular sub-region
	set(handles.hRects,'Visible','off')
	[p1,p2] = rubberbandbox(handles.axes1);
	if (p1(2) < 1 || p2(2) < 1)			% Check if rectangle is not completely inside image
		set(hObject,'Val', 0)
		set(handles.hRects,'Visible','on')
		return
	end
	[n_row, n_col, k] = size(get(findobj(handles.axes1,'Type', 'image'),'CData'));
	x_min = -180;		y_min = -90;	inc = 360 / n_col;
  
	w = (p1(1) - 1) * inc + x_min;		e = (p2(1) - 1) * inc + x_min;			% Get Region in geogs
	s = (n_row - p2(2)) * inc + y_min;	n = (n_row - p1(2)) * inc + y_min;		% Also change the stupid origin from UL to BL corner
	pixelx = round(axes2pix(5400, [-180 180], [w e]));					% Now convert to the correct indices of big image 
	pixely = 2700 - round(axes2pix(2700, [-90 90], [s n])) + 1;			% Again the Y origin shit
	pixely = pixely(2:-1:1);
	
	if ( (diff(pixelx(1:2)) < 10) || (diff(pixely(1:2)) < 10) )
		return
	end

	opt_r = sprintf('-r%d/%d/%d/%d', pixelx(1:2), pixely(1:2));

	h = patch('XData',[p1(1) p2(1) p2(1) p1(1)],'YData',[p1(2) p1(2) p2(2) p2(2)],'FaceColor','none');
	out.img = get_img(handles.figure1, h, [handles.f_path 'etopo4.jpg'], opt_r, '-U');
	if (get(handles.radio_360,'Val') && w < 0)
		w = w + 360;		e = e + 360;
	end	
	out.X = [w e];      out.Y = [s n];
	out.imgName = 'Base image';
    handles.output = out;   guidata(handles.figure1, handles);  uiresume(handles.figure1);

% ----------------------------------------------------------------------------------------
function radio_MapTiles_CB(hObject, handles)
	if (~get(hObject,'Val')),		set(hObject,'Val', 1),		return,		end
	set(handles.radio_WorldMap, 'Value', 0);
	set(handles.figure1,'Name','World Topo Tiles')
	set(handles.hBigRect,'Visible','off'),		set(handles.hRects,'Visible','on')

% ----------------------------------------------------------------------------------
function radio_WorldMap_CB(hObject, handles)
	if (~get(hObject,'Val')),		set(hObject,'Val', 1),		return,		end
	set(handles.radio_MapTiles, 'Value', 0);
	set(handles.figure1,'Name','World Topo')
	set(handles.hBigRect,'Visible','on'),		set(handles.hRects,'Visible','off')

% ----------------------------------------------------------------------------------------
function radio_180_CB(hObject, handles)
	if (~get(hObject,'Val')),		set(hObject,'Val', 1),		return,		end
	set(handles.radio_360, 'Val', 0)

% ----------------------------------------------------------------------------------------
function radio_360_CB(hObject, handles)
	if (~get(hObject,'Val')),		set(hObject,'Val', 1),		return,		end
	set(handles.radio_180, 'Val', 0)

% ----------------------------------------------------------------------------------------
function figure1_CloseRequestFcn(hObject, eventdata)
	handles = guidata(hObject);
	if isequal(get(handles.figure1, 'waitstatus'), 'waiting')
		handles.output = [];			% User gave up, return nothing
		guidata(hObject, handles);		uiresume(hObject);
	else								% The GUI is no longer waiting, just close it
		handles.output = [];			% User gave up, return nothing
		guidata(hObject, handles);		delete(hObject);
	end

% ----------------------------------------------------------------------------------------
function figure1_KeyPressFcn(hObject, eventdata)
	if isequal(get(hObject,'CurrentKey'),'escape')
		handles = guidata(hObject);
		handles.output = [];			% User said no by hitting escape
		guidata(hObject, handles);		uiresume(hObject);
	end

% --- Creates and returns a handle to the GUI figure. 
function bg_map_LayoutFcn(h1)
	set(h1,'PaperUnits','centimeters',...
	'CloseRequestFcn',@figure1_CloseRequestFcn,...
	'Color',get(0,'factoryUicontrolBackgroundColor'),...
	'KeyPressFcn',@figure1_KeyPressFcn,...
	'MenuBar','none',...
	'Name','World Topo Tiles',...
	'NumberTitle','off',...
	'Position',[520 525 512 280],...
	'Resize','off',...
	'Tag','figure1');

axes('Parent',h1,'Units','pixels','Position',[1 1 512 256],'Tag','axes1','Visible','off');

uicontrol('Parent',h1,...
'Call',{@bg_map_uiCB,h1,'radio_MapTiles_CB'},...
'Position',[10 259 110 15],...
'String','World Map Tiles',...
'Style','radio',...
'Value',1,...
'Tag','radio_MapTiles');

uicontrol('Parent',h1,...
'Call',{@bg_map_uiCB,h1,'radio_WorldMap_CB'},...
'Position',[128 259 90 15],...
'String','World Map',...
'Style','radio',...
'Tag','radio_WorldMap');

uicontrol('Parent',h1,...
'Call',{@bg_map_uiCB,h1,'radio_180_CB'},...
'Position',[350 259 90 15],...
'String','[-180 180]',...
'Style','radio',...
'Value',1,...
'Tooltip','Central meridian at Greenwich',...
'Tag','radio_180');

uicontrol('Parent',h1,...
'Call',{@bg_map_uiCB,h1,'radio_360_CB'},...
'Position',[440 259 90 15],...
'String','[0 360]',...
'Style','radio',...
'Tooltip','Central meridian at date line',...
'Tag','radio_360');

uicontrol('Parent',h1, 'Position',[255 259 30 21],...
'Call',{@bg_map_uiCB,h1,'toggle_region_CB'},...
'Style','toggle',...
'Tooltip','Select a rectangular region with the mouse',...
'Tag','toggle_region');

function bg_map_uiCB(hObject, eventdata, h1, callback_name)
% This function is executed by the callback and than the handles is allways updated.
	feval(callback_name,hObject,guidata(h1));
