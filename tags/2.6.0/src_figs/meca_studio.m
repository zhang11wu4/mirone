function varargout = meca_studio(varargin)
% Demonstration tool to create focal mechanisms (beach balls)

%	Copyright (c) 2004-2012 by J. Luis
%
% 	This program is part of Mirone and is free software; you can redistribute
% 	it and/or modify it under the terms of the GNU Lesser General Public
% 	License as published by the Free Software Foundation; either
% 	version 2.1 of the License, or any later version.
% 
% 	This program is distributed in the hope that it will be useful,
% 	but WITHOUT ANY WARRANTY; without even the implied warranty of
% 	MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the GNU
% 	Lesser General Public License for more details.
%
%	Contact info: w3.ualg.pt/~jluis/mirone
% --------------------------------------------------------------------

	hObject = figure('Vis','off');
	meca_studio_LayoutFcn(hObject);
	handles = guihandles(hObject);
	move2side(hObject,'right')

	if (isempty(varargin))
		handles.strike = 0;
		handles.dip = 90;
		handles.rake = 180;
	elseif (numel(varargin) ~= 3)
		errordlg('Meca Studio: wrong number of input arguments (should be 3).','Error')
		delete(hObject),	return
	else
		handles.strike = varargin{1};
		handles.dip = varargin{2};
		handles.rake = varargin{3};
		set(handles.edit_strike,'String', handles.strike)
		set(handles.slider_strike, 'Val', handles.strike)
		set(handles.edit_dip,'String', handles.dip)
		set(handles.slider_dip, 'Val', handles.dip)
		set(handles.edit_rake,'String', handles.rake)
		set(handles.slider_rake, 'Val', handles.rake)
	end
	set(hObject,'Visible','on');

	[comp,dilat] = patch_meca(handles.strike, handles.dip, handles.rake);
	handles.hComp = patch(comp(:,1),comp(:,2), [0 0 0], 'Parent', handles.axes1);
	handles.hDilat = patch(dilat(:,1),dilat(:,2), [1 1 1], 'Parent', handles.axes1);
	set(handles.slider_strike,'SliderStep',[1/360 1/36])
	set(handles.slider_dip,'SliderStep',[1/90 1/9])
	set(handles.slider_rake,'SliderStep',[1/360 1/36])

	guidata(hObject, handles);
	set(hObject,'Visible','on');
	if (nargout),	varargout{1} = hObject;		end

% --------------------------------------------------------------------------
function slider_strike_CB(hObject, handles)
	val = get(hObject,'Value');
	set(handles.edit_strike,'String',num2str(val))
	handles.strike = val;
	update_ball(handles)
	guidata(handles.figure1, handles);

% --------------------------------------------------------------------------
function edit_strike_CB(hObject, handles)
	x = str2double(get(hObject,'String'));
	if (isnan(x) || x < 0 || x > 360)
		set(hObject,'String',handles.strike),	return
	end
	set(handles.slider_strike,'Value',x)
	handles.strike = x;
	update_ball(handles)
	guidata(handles.figure1, handles);

% --------------------------------------------------------------------------
function slider_dip_CB(hObject, handles)
	val = get(hObject,'Value');
	set(handles.edit_dip,'String',num2str(val))
	handles.dip = val;
	update_ball(handles)
	guidata(handles.figure1, handles);

% --------------------------------------------------------------------------
function edit_dip_CB(hObject, handles)
	x = str2double(get(hObject,'String'));
	if (isnan(x) || x < 0 || x > 90)
		set(hObject,'String',handles.dip),	return
	end
	set(handles.slider_dip,'Value',x)
	handles.dip = x;
	update_ball(handles)
	guidata(handles.figure1, handles);

% --------------------------------------------------------------------------
function slider_rake_CB(hObject, handles)
	val = get(hObject,'Value');
	set(handles.edit_rake,'String',num2str(val))
	handles.rake = val;
	update_ball(handles)
	guidata(handles.figure1, handles);

% --------------------------------------------------------------------------
function edit_rake_CB(hObject, handles)
	x = str2double(get(hObject,'String'));
	if (isnan(x) || x < -180 || x > 180)
		set(hObject,'String',handles.rake),	return
	end
	set(handles.slider_rake,'Value',x)
	handles.rake = x;
	update_ball(handles)
	guidata(handles.figure1, handles);

% --------------------------------------------------------------------------
function push_GMTcomm_CB(hObject, handles)
	str = ['echo 0.0 0.0 0.0 ' num2str(handles.strike) ' '  num2str(handles.dip) ' ' ...
			 num2str(handles.rake) ' 5 0 0 | psmeca -Sa2.5c -Gblack ' ...
			 '-R-1/1/-1/1 -JM8c -P -B0 > this_meca.ps'];
	 a = inputdlg({'Example psmeca command'},'GMT command',[1 110], {str});

% --------------------------------------------------------------------------
function update_ball(handles)
	[comp,dilat] = patch_meca(handles.strike, handles.dip, handles.rake);
	set(handles.hComp,'XData',comp(:,1), 'YData',comp(:,2))
	set(handles.hDilat,'XData',dilat(:,1), 'YData',dilat(:,2))


% --- Creates and returns a handle to the GUI figure. 
function meca_studio_LayoutFcn(h1)

set(h1,...
'Color',get(0,'factoryUicontrolBackgroundColor'),...
'MenuBar','none',...
'Name','Focal Meca Studio',...
'NumberTitle','off',...
'Position',[520 444 291 350],...
'Resize','off',...
'HandleVisibility','callback',...
'Tag','figure1');

uicontrol('Parent',h1,...
'BackgroundColor',[1 1 1],...
'Call',@meca_studio_uiCB,...
'Max',360,...
'Position',[8 329 231 15],...
'Style','slider',...
'Tag','slider_strike');

uicontrol('Parent',h1,...
'BackgroundColor',[1 1 1],...
'Call',@meca_studio_uiCB,...
'Position',[238 326 45 21],...
'String','0',...
'Style','edit',...
'Tag','edit_strike');

uicontrol('Parent',h1,...
'BackgroundColor',[1 1 1],...
'Call',@meca_studio_uiCB,...
'Max',90,...
'Position',[8 307 231 15],...
'Style','slider',...
'Value',90,...
'Tag','slider_dip');

uicontrol('Parent',h1,...
'BackgroundColor',[1 1 1],...
'Call',@meca_studio_uiCB,...
'Position',[238 304 45 21],...
'String','90',...
'Style','edit',...
'Tag','edit_dip');

uicontrol('Parent',h1,...
'BackgroundColor',[1 1 1],...
'Call',@meca_studio_uiCB,...
'Max',180,...
'Min',-180,...
'Position',[8 285 231 15],...
'Style','slider',...
'Value',180,...
'Tag','slider_rake');

uicontrol('Parent',h1,...
'BackgroundColor',[1 1 1],...
'Call',@meca_studio_uiCB,...
'Position',[238 282 45 21],...
'String','180',...
'Style','edit',...
'Tag','edit_rake');

axes('Parent',h1,...
'Units','pixels',...
'CameraPosition',[0 0 9.16025403784439],...
'Color',get(0,'defaultaxesColor'),...
'Position',[10 9 271 271],...
'XLim',[-1.01 1.01],...
'XLimMode','manual',...
'YLim',[-1.01 1.01],...
'YLimMode','manual',...
'Tag','axes1',...
'Visible','off');

uicontrol('Parent',h1,...
'Enable','inactive',...
'FontAngle','oblique',...
'FontName','Helvetica',...
'FontSize',10,...
'Position',[108 329 38 15],...
'String','Strike',...
'Style','text',...
'HitTest','off');

uicontrol('Parent',h1,...
'Enable','inactive',...
'FontAngle','oblique',...
'FontName','Helvetica',...
'FontSize',10,...
'Position',[114 307 26 15],...
'String','Dip',...
'Style','text',...
'HitTest','off');

uicontrol('Parent',h1,...
'Enable','inactive',...
'FontAngle','oblique',...
'FontName','Helvetica',...
'FontSize',10,...
'Position',[108 285 37 15],...
'String','Rake',...
'Style','text',...
'HitTest','off');

uicontrol('Parent',h1,...
'Call',@meca_studio_uiCB,...
'FontName','Helvetica',...
'Position',[217 7 66 21],...
'String','GMT comm',...
'Tooltip','Generate an example GMT command that reproduces this image',...
'Tag','push_GMTcomm');

function meca_studio_uiCB(hObject, eventdata)
% This function is executed by the callback and than the handles is allways updated.
	feval([get(hObject,'Tag') '_CB'],hObject, guidata(hObject));
