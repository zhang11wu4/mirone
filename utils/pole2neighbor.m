function varargout = pole2neighbor(obj, evt, hLine, mode, opt)
% Compute finite poles from isochron N to isochron N+1 of the data/isochrons.dat file (must be loaded)

%	Copyright (c) 2004-2013 by J. Luis
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

% $Id$

	if (isempty(hLine)),	hLine = gco;	end
	hNext = hLine;
	if (strcmpi(mode, 'Bonin'))
		while (~isempty(hNext))
			hNext = compute_pole2neighbor_Bonin(hNext);
		end

	elseif (strcmpi(mode, 'anglefit'))
		if (nargin == 4)				% Make one full round on all poles in same plate of the seed
			nNewPoles = 0;
			hLine0 = find_ridge(hLine);
			hNext = hLine0;
			while (~isempty(hNext))
				[hNext, is_pole_new] = compute_pole2neighbor_newStage(hNext);
				nNewPoles = nNewPoles + is_pole_new;
			end
			secondLineInfo = getappdata(hLine0,'secondLineInfo');	% Only Ridge line may have this set
			if (~isempty(secondLineInfo))
				swap_lineInfo(hLine0)
				hNext = hLine0;
				while (~isempty(hNext))	% Make another full round on the conjugate plate
					[hNext, is_pole_new] = compute_pole2neighbor_newStage(hNext);
					nNewPoles = nNewPoles + is_pole_new;
				end
				swap_lineInfo(hLine0)	% Reset the original
			end
			fprintf('Computed %d new poles', nNewPoles)
		else							% Compute the pole of the seed isoc only, iterating OPT times or not improving
			n = 1;		is_pole_new = true;
			while (n <= opt && is_pole_new)
				[hNext, is_pole_new] = compute_pole2neighbor_newStage(hLine);
				n = n + 1;
			end
		end

	elseif (strcmpi(mode, 'best'))		% Best-fit (Brute-Force)
		if (nargin == 4)				% Make one full round on all poles in same plate of the seed
			nNewPoles = 0;
			while (~isempty(hNext))
				[hNext, is_pole_new] = compute_pole2neighbor_BruteForce(hNext);
				nNewPoles = nNewPoles + is_pole_new;
			end
			fprintf('Computed %d new poles', nNewPoles)
		else							% Compute the pole of the seed isoc only, iterating OPT times or not improving
			n = 1;		is_pole_new = true;
			while (n <= opt && is_pole_new)
				[hNext, is_pole_new] = compute_pole2neighbor_BruteForce(hLine);
				n = n + 1;
			end
		end

	elseif (strcmpi(mode, 'showresults'))
		out = get_all_stgs(hLine);
		setappdata(0, 'STGs', out)

	elseif (strcmpi(mode, 'stginfo'))	% Just get and return the STG pole requested in OPT (e.g. STG0, STG2 or STG3)
		if (strncmp(opt, 'STG', 3))
			varargout{1} = get_stg_pole(opt, getappdata(hLine,'LineInfo'));
		elseif (strncmp(opt, 'FIN', 3))
			p = parse_finite_pole(getappdata(hLine,'LineInfo'));
			if (isempty(p))
				varargout{1} = [];
			else
				varargout{1} = [p.lon p.lat p.age p.age p.ang NaN];	% Use the same output type as for the stage poles (+ residue)
			end
		else
			error('Wrong OPT argument in call to pole2neighbor')
		end

	elseif (strcmpi(mode, 'agegrid'))
		fill_age_grid(hLine)

	end

% -----------------------------------------------------------------------------------------------------------------
function [hNext, is_pole_new] = compute_pole2neighbor_newStage(hLine)
% Compute a new pole between isochrons (hLine) and its next older neighbor
% by brute-forcing only the angle and accepting the lon,lat.

	is_pole_new = false;		is_ridge = false;
	opt_D = '-D0/0/2';			opt_I = '-I1/1/201';	% Options for the compute_euler()
	[hNext, CA, CB] = find_closest_old(hLine);
	if (isempty(hNext)),	return,		end
	if (strcmp(CA, '0') && ~isappdata(hLine, 'secondLineInfo'))	% Do this only once
		lineInfo = getappdata(hNext, 'LineInfo');
		p2 = parse_finite_pole(lineInfo);
		lineInfo = getappdata(hLine, 'LineInfo');
		p = parse_finite_pole(lineInfo);
		pole = [p.lon p.lat p2.age 0 p.ang];		% For C0 we cannot compute a stage ... but we can set it
		is_ridge = true;
	else
		pole = get_true_stg(hLine, hNext);		% Get from header or compute (and insert in header) the true half-stage pole
	end
	xA = get(hLine, 'XData');	yA = get(hLine, 'YData');
	xB = get(hNext, 'XData');	yB = get(hNext, 'YData');
	new_pole = compute_euler([xA(:) yA(:)], [xB(:) yB(:)], pole(1,1), pole(1,2), pole(1,5), opt_D, opt_I);
	% new_pole = [pLon, pLat, pAng, resid]
	[lineInfo, is_pole_new] = set_stg_info('stagefit', hLine, [], new_pole(1), new_pole(2), new_pole(3), ...
                                           pole(1,4), pole(1,3), CA, CB, new_pole(4));
	if (is_ridge)		% Now that we have the STG3 pole we can set the secondLineInfo
		ind = strfind(lineInfo,'FIN"');
		[t, r] = strtok(lineInfo(1:ind-1));		% t is age
		r = ddewhite(r);
		ind2 = strfind(r, '/');
		new_lineInfo = ['0 ' r(ind2+1:end) '/' r(1:ind2-1) lineInfo(ind-1:end)];
		setappdata(hLine, 'secondLineInfo', new_lineInfo)
	end

% -----------------------------------------------------------------------------------------------------------------
function [hNext, is_pole_new] = compute_pole2neighbor_BruteForce(hLine)
% Compute a new pole between isochrons (hLine) and its next older neighbor
% by the pure brute force method. Parameters for brute force are hardwired here.

	[hNext, pole, lineInfo, p, p_closest, CA, CB] = compute_pole2neighbor_Bonin(hLine);
	if (isempty(hNext))		% Suposedly the oldest isochron in its town
		is_pole_new = false;
		return
	end

	% OK, brute force now it is
	opt_D = '-D10/10/0.1';
	opt_I = '-I101/101/11';
	xA = get(hLine, 'XData');	yA = get(hLine, 'YData');
	xB = get(hNext, 'XData');	yB = get(hNext, 'YData');
	new_pole = compute_euler([xA(:) yA(:)], [xB(:) yB(:)], pole(1), pole(2), pole(3), opt_D, opt_I);
	% new_pole is [pLon, pLat, pAng, resid]
	[lineInfo, is_pole_new] = set_stg_info('bestfit', hLine, lineInfo, new_pole(1), new_pole(2), new_pole(3), ...
                                           p, p_closest, CA, CB, new_pole(4));

% -----------------------------------------------------------------------------------------------------------------
function out = get_all_stgs(hLine)
% Fish the info about the the STG2 (Best-fit) and STG3 (true stage lon,lat bt bets fit angle)
% poles stored in isochron headers.
% HLINE is the handle of the 'seed' isochron. Only it and older isocs are analysed

	out = zeros(200,18);
	out(1,1:6)   = get_stg_pole('STG0', getappdata(hLine,'LineInfo'));
	out(1,7:12)  = get_stg_pole('STG2', getappdata(hLine,'LineInfo'));
	out(1,13:18) = get_stg_pole('STG3', getappdata(hLine,'LineInfo'));
	hNext = hLine;

	n = 2;
	while (~isempty(hNext))
		hNext = find_closest_old(hNext);
		if (~isempty(hNext))	% Must do this test again here because it's a new hNext
			out(n,1:6)   = get_stg_pole('STG0', getappdata(hNext,'LineInfo'));
			out(n,7:12)  = get_stg_pole('STG2', getappdata(hNext,'LineInfo'));
			out(n,13:18) = get_stg_pole('STG3', getappdata(hNext,'LineInfo'));
			n = n + 1;
		end
	end
	out(n-1:end,:) = [];		% These were allocated in excess

% -----------------------------------------------------------------------------------------------------------------
function [x_min, x_max, y_min, y_max, hLine0] = get_BB(hLine)
% Find the BoundingBox of all isocrons on the plate pair where hLine belongs

	hLine0 = find_ridge(hLine);					% Find the ridge of the hLine's plate pair
	if (isempty(hLine0))
		error('This Plate has no Ridge????????')
	end
	x_min = 1e3;	x_max = -1e3;
	y_min = 1e3;	y_max = -1e3;
	hNext = hLine0;
	while (~isempty(hNext))
		x = get(hNext, 'XData');	y = get(hNext, 'YData');
		x_min = min(x_min, min(x(1),x(end)));	x_max = max(x_max, max(x(1),x(end)));
		y_min = min(y_min, min(y(1),y(end)));	y_max = max(y_max, max(y(1),y(end)));
		hNext = find_closest_old(hNext);
	end

	% Now run the same for the conjugate plate
	swap_lineInfo(hLine0)
	hNext = hLine0;
	while (~isempty(hNext))
		x = get(hNext, 'XData');	y = get(hNext, 'YData');
		x_min = min(x_min, min(x(1),x(end)));	x_max = max(x_max, max(x(1),x(end)));
		y_min = min(y_min, min(y(1),y(end)));	y_max = max(y_max, max(y(1),y(end)));
		hNext = find_closest_old(hNext);
	end
	swap_lineInfo(hLine0)							% Reset

% -----------------------------------------------------------------------------------------------------------------
function swap_lineInfo(hLine)
% Swap the two appdatas with poles info respecting the ridge hLine

	lineInfo = getappdata(hLine, 'LineInfo');
	secondLineInfo = getappdata(hLine, 'secondLineInfo');
	if (isempty(secondLineInfo))					% See if we have poles info to run on conjugate plate
		pole2neighbor([], [], hLine, 'anglefit');	% This will set 'secondLineInfo'
		secondLineInfo = getappdata(hLine, 'secondLineInfo');
	end
	setappdata(hLine, 'LineInfo', secondLineInfo)
	setappdata(hLine, 'secondLineInfo', lineInfo)

% -----------------------------------------------------------------------------------------------------------------
function fill_age_grid(hLine)
% ...

% 	lon_min = -49;		lat_min = 12;
% 	lon_max = -11;		lat_max = 40;
	[lon_min, lon_max, lat_min, lat_max, hLine] = get_BB(hLine);	% The returned hLine is the Ridge
	lon_min = floor(lon_min);	lon_max = ceil(lon_max);
	lat_min = floor(lat_min);	lat_max = ceil(lat_max);
	x_inc = 2/60;		y_inc = x_inc;
	n_cols = round((lon_max -lon_min) / x_inc) + 1;
	n_rows = round((lat_max -lat_min) / y_inc) + 1;
	grd = zeros(n_rows,n_cols)*NaN;

	hNext = hLine;
	first_plate = true;
	aguentabar(0,'title','Filling age cells (First plate)')
	while (~isempty(hNext))
		current_seed_hand = hNext;

		x  = get(current_seed_hand,'Xdata');	y  = get(current_seed_hand,'Ydata');
		lat_i = y(1:end-1);   lat_f = y(2:end);
		lon_i = x(1:end-1);   lon_f = x(2:end);
		tmp = vdist(lat_i,lon_i,lat_f,lon_f);
		r = [0; cumsum(tmp(:))] / 1852;			% Distance along isoc in Nautical Miles (~arc minutes)
		ind = (diff(r) == 0);
		if (any(ind))
			r(ind) = [];	x(ind) = [];	y(ind) = [];
		end
		x = interp1(r, x, [r(1):2:r(end) r(end)]);
		y = interp1(r, y, [r(1):2:r(end) r(end)]);

		[out, hNext, p1, p2, n_pts, ind_last, x2, y2] = get_arc_from_a2b(hNext, x, y);
		if (isempty(hNext) && first_plate)		% Done with first plate. Go for its conjugate
			swap_lineInfo(hLine)
			hNext = hLine;
			first_plate = false;
			aguentabar(0,'title','Filling age cells (Second Plate)')
			continue
		end
		if (isempty(out)),	continue,	end

		for (k = 1:numel(out.age))
			col = fix((out.lon(k) - lon_min) / x_inc) + 1;
			row = fix((out.lat(k) - lat_min) / y_inc) + 1;
			grd(row,col) = out.age(k);
		end
		max_age_so_far = max(out.age(1),out.age(end));
		while (ind_last < n_pts)				% Now do the rest of the vertex of this isochron
			[out, hNext, p1, p2, n_pts, ind_last] = get_arc_from_a2b(current_seed_hand, x, y, hNext, x2, y2, ind_last+1, p1, p2);
			if (isempty(out) || isempty(out.lon)),	continue,	end
			for (k = 1:numel(out.lon))
				col = fix((out.lon(k) - lon_min) / x_inc) + 1;
				row = fix((out.lat(k) - lat_min) / y_inc) + 1;
				grd(row,col) = out.age(k);
			end
		end
		aguentabar(max_age_so_far / 160)		% Crude estimation of advancing
	end
	swap_lineInfo(hLine)						% Reset
	aguentabar(1)

	G.z = grd;	G.n_columns = size(grd,2);	G.n_rows = size(grd,1);	G.range = [lon_min lon_max lat_min lat_max];
	G.head = [G.range 0 165 0 x_inc y_inc];	G.ProjectionRefPROJ4 = '';
	G.inc = [x_inc y_inc];		G.MinMax = [0 165];		G.registration = 0;
	mirone(G)

% -----------------------------------------------------------------------------------------------------------------
function [out, hNext, p1, p2, n_pts, ind_last, x2, y2] = get_arc_from_a2b(hLine, x, y, hNext, x2, y2, k, p1, p2)
% Compute a arcuate path along a flow-line about the pole ...

	out = [];	ind_last = 1;	n_pts = 1;

	if (nargin == 3)			% Find closest old and intersection point
		x2 = [];	y2 = [];	% In case we need a premature return
		hNext = find_closest_old(hLine);
		if (isempty(hNext))
			p1 = [];	p2 = [];	return
		end
		%p1 = parse_finite_pole(getappdata(hLine,'LineInfo'));		% Get the Euler pole parameters of this isoc
		p1 = get_STG_pole(getappdata(hLine,'LineInfo'), 'STG3');	% Get the Euler pole parameters of this isoc
		if (isempty(p1))
			fprintf('This isoc has no STG3 pole info in it header\n%s\n', getappdata(hLine,'LineInfo'));
			p2 = [];				return
		end

		%p2 = parse_finite_pole(getappdata(hNext,'LineInfo'));
		p2 = get_STG_pole(getappdata(hNext,'LineInfo'), 'STG3');
		if (isempty(p2)),	return,	end		% Hopefully the last one on the run (those cannot have an STG)
		k = 1;

		% First time in this hNext line. Need to fetch the coords
		x2 = get(hNext,'XData');	y2 = get(hNext,'YData');
		if ( sign(y(end) - y(1)) ~= sign(y2(end) - y2(1)) )		% Lines have oposite orientation. Reverse one of them.
			x2 = x2(end:-1:1);		y2 = y2(end:-1:1);
		end
	end

	n_pts = numel(x);
	xc2 = [];		D2R = pi/180;
	% Find the first point in Working isoc whose circle about his Euler pole crosses its nearest (older) neighbor
	while (isempty(xc2))
		if (k > n_pts)			% Shit happened
			out = [];	ind_last = k;	return
		end
		c = sin(p1.lat*D2R)*sin(y(k)*D2R) + cos(p1.lat*D2R)*cos(y(k)*D2R)*cos( (p1.lon-x(k))*D2R );
		rad = acos(c) / D2R;		% Angular distance between pole and point k along younger isoc
		[latc,lonc] = circ_geo(p1.lat, p1.lon, rad, [], 720);
		[mimi,ii] = max(diff(lonc));			% Need to reorder array to [-180 180] to avoid bad surprises
		if (mimi > 100)
			lonc = [lonc(ii+1:end) lonc(1:ii)];
			latc = [latc(ii+1:end) latc(1:ii)];
		end
		% Clip lonc,latc to speed up and reduce the memory eatear monster in 'intersections'
		ind = (latc > max(y2(1),y2(end)) + 2) | (latc < min(y2(1),y2(end)) - 2) | ...
			(lonc > max(x2(1),x2(end)) + 5) | (lonc < min(x2(1),x2(end)) - 5);
		lonc(ind) = [];		latc(ind) = [];
		if (numel(lonc) < 2),	k = k + 1;	continue,	end
		[xc2,yc2] = intersections(lonc,latc,x2,y2);
		k = k + 1;
	end
	k = k - 1;
	az1 = azimuth_geo(p1.lat, p1.lon, y(k), x(k));
	az2 = azimuth_geo(p1.lat, p1.lon, yc2(1), xc2(1));		% <====== VERIFICAR ESTA MERDA
	daz = abs(az2-az1);
	if (daz > 180),		daz = daz - 360;	end		% Unlucky cases
	np = round(daz / (2/60) / sin(rad*D2R) * 2);
	reverse_age_sense = false;
	if (az1 > az2)
		tmp = az1;		az1 = az2;	az2 = tmp;	reverse_age_sense = true;
	end
	[latc,lonc] = circ_geo(p1.lat, p1.lon, rad, [az1 az2], np);
	out.lon = lonc;		out.lat = latc;

	% Make sure the age 'runs' in the same sense as that of the flowline (varies depending on pole position)
	if(reverse_age_sense)
		out.age = linspace(p2.age, p1.age, numel(lonc));
	else
		out.age = linspace(p1.age, p2.age, numel(lonc));
	end
	ind_last = k;

% -----------------------------------------------------------------------------------------------------------------
function hLine0 = find_ridge(hLine)
% Find the ridge (isochron 0) of the plate on which this hLine lies

	hLine0 = [];
	lineInfo = getappdata(hLine,'LineInfo');
	[t, r] = strtok(lineInfo);
	ind = strfind(r, 'FIN"');
	plates = ddewhite(r(1:ind-1));		% The plate pair
	hAllIsocs = findobj(get(hLine,'Parent'),'Tag', get(hLine,'Tag'));
	for (i = 1:numel(hAllIsocs))
		this_lineInfo = getappdata(hAllIsocs(i),'LineInfo');
		[this_isoc, r] = strtok(this_lineInfo);
		if (strcmp(this_isoc, '0'))
			ind = strfind(r, 'FIN"');
			this_plates = ddewhite(r(1:ind-1));		% The plate pair
			%if (strcmp(plates, this_plates))		% FOUND it
			if ( isequal(sort(double(this_plates)), sort(double(plates))) )
				hLine0 = hAllIsocs(i);
				break
			end
		end
	end

% -----------------------------------------------------------------------------------------------------------------
function [hNext, CA, CB] = find_closest_old(hLine)
% Find the closest older isochron to HLINE and return it in HNEXT or empty if not found
% CA & CB are strings with the names of both isochrons

	hNext = [];		CB = '';

	if (nargin == 0),		hLine = gco;	end
	this_lineInfo = getappdata(hLine,'LineInfo');
	[this_isoc, r] = strtok(this_lineInfo);
	[this_plate_pair, r] = strtok(r);
	this_plate_pair_first_name = '';
	if (strncmp(this_plate_pair,'NOR',3) || strncmp(this_plate_pair,'SOU',3))		% NORTH or SOUTH is no good
		this_plate_pair_first_name = this_plate_pair;		% Either 'NORTH' or 'SOUTH'
		this_plate_pair = strtok(r);
	end
	CA = this_isoc;								% A copy as a string for eventual use in Best-Fit info data
	this_isoc = get_isoc_numeric(this_isoc);	% Convert the isoc name into a numeric form

	hAllIsocs = findobj(get(hLine,'Parent'),'Tag', get(hLine,'Tag'));
	closest_so_far = 5000;			% Just a pretend-to-be oldest anomaly (must be > 1000 + oldest M)
	ind_closest = [];
	for (i = 1:numel(hAllIsocs))	% Loop to find the closest and older to currently active isoc
		lineInfo = getappdata(hAllIsocs(i),'LineInfo');
		if (isempty(lineInfo)),		continue,	end
		[isoc, r] = strtok(lineInfo);
		[plates, r] = strtok(r);
		if (strncmp(plates,'NOR',3) || strncmp(plates,'SOU',3))		% NORTH or SOUTH is no good, but wee need a further test
			if (~strcmp(this_plate_pair_first_name, plates)),	continue,	end		% A 'NORTH' and a 'SOUTH'
			plates = strtok(r);
		end
		if (~strcmp(this_plate_pair, plates)),	continue,	end		% This isoc is not in the same plate
		if (isoc(1) == 'A'),	continue,	end		% The ones named Axx are of no interest for the moment
		isocN = get_isoc_numeric(isoc);				% Convert the isoc name into a numeric form
		if (isocN <= this_isoc),	continue,	end	% We are only interested on older-than-this-isoc
		if (isocN < closest_so_far)
			closest_so_far = isocN;					% Note: for example C3a is given an age = 3.1 to tell from C3
			CB = isoc;								% A copy as a string for eventual use in Best-Fit info data
			ind_closest = i;
		end
	end

	if (~isempty(ind_closest))
		hNext = hAllIsocs(ind_closest);
	end

% -----------------------------------------------------------------------------------------------------------------
function [hNext, pole, lineInfo, p, p_closest, CA, CB] = compute_pole2neighbor_Bonin(hLine)
% Inserts/update the header line of current object (gco) or of HLINE
% HNEXT is the handle of nearest older isochron line
%
% However, if nargout > 1 return also the Bonin pole and the names of current and its
% closest old neighbor as strings CA & CB.
	
	hNext = [];		pole = [];	lineInfo = '';		p_closest = [];		CB = '';

	if (nargin == 0),		hLine = gco;	end
	this_lineInfo = getappdata(hLine,'LineInfo');
	[this_isoc, r] = strtok(this_lineInfo);
	[this_plate_pair, r] = strtok(r);
	this_plate_pair_first_name = '';
	if (strncmp(this_plate_pair,'NOR',3) || strncmp(this_plate_pair,'SOU',3))		% NORTH or SOUTH is no good
		this_plate_pair_first_name = this_plate_pair;		% Either 'NORTH' or 'SOUTH'
		this_plate_pair = strtok(r);
	end
	CA = this_isoc;								% A copy as a string for eventual use in Best-Fit info data
	this_isoc = get_isoc_numeric(this_isoc);	% Convert the isoc name into a numeric form

	p = parse_finite_pole(this_lineInfo);		% Get the Euler pole parameters of this isoc
	if (isempty(p))
		errordlg(sprintf('This line has no pole info. See:\n\n%s',this_lineInfo),'Error')
		return
	end

	hAllIsocs = findobj(get(hLine,'Parent'),'Tag', get(hLine,'Tag'));
	closest_so_far = 5000;			% Just a pretend-to-be oldest anomaly (must be > 1000 + oldest M)
	ind_closest = [];
	for (i = 1:numel(hAllIsocs))	% Loop to find the closest and older to currently active isoc
		lineInfo = getappdata(hAllIsocs(i),'LineInfo');
		if (isempty(lineInfo)),		continue,	end
		[isoc, r] = strtok(lineInfo);
		[plates, r] = strtok(r);
		if (strncmp(plates,'NOR',3) || strncmp(plates,'SOU',3))		% NORTH or SOUTH is no good, but wee need a further test
			if (~strcmp(this_plate_pair_first_name, plates)),	continue,	end		% A 'NORTH' and a 'SOUTH'
			plates = strtok(r);
		end
		if (~strcmp(this_plate_pair, plates)),	continue,	end		% This isoc is not in the same plate
		if (isoc(1) == 'A'),	continue,	end		% The ones named Axx are of no interest for the moment
		isocN = get_isoc_numeric(isoc);				% Convert the isoc name into a numeric form
		if (isocN <= this_isoc),	continue,	end	% We are only interested on older-than-this-isoc
		if (isocN < closest_so_far)
			closest_so_far = isocN;					% Note: for example C3a is given an age = 3.1 to tell from C3
			CB = isoc;								% A copy as a string for eventual use in Best-Fit info data
			ind_closest = i;
		end
	end

	if (isempty(ind_closest))		% If nothing older is found, we are done
		return
	end

	% ------------- OK, so here we are supposed to have found the next older isoc -------------------
	hNext = hAllIsocs(ind_closest);

	if (nargout > 1)
		[plon,plat,omega] = get_last_pole(this_lineInfo);
		if (~isempty(plon))				% Remember, this is the case where we are going to do Brute-Force
			pole = [plon,plat,omega];	% So if a previous pole exists it's all we want, OTHERWISE we must
			lineInfo = this_lineInfo;	% proceed till the end of this fucntion to compute a Bonin pole.
			return
		end
	end

	closest_lineInfo = getappdata(hNext,'LineInfo');
	disp(closest_lineInfo)
	x  = get(hLine,'Xdata');	y  = get(hLine,'Ydata');
	x2 = get(hNext,'XData');	y2 = get(hNext,'YData');
	n_pts = numel(x);
	inds = 1:fix(n_pts / 10):n_pts;		% Indices of one every other 10% of number of total points in working isoc

	xcFirst = [];		k = 0;
	D2R = pi/180;
	% Find the first point in Working isoc whose circle about his Euler pole crosses its nearest (older) neighbor
	while (isempty(xcFirst))
		k = k + 1;
		if (k > numel(inds))
			errordlg(sprintf('Something screw.\n\n%s\n\nand\n\n%s\n\n are clearly not neighbors', ...
				this_lineInfo,closest_lineInfo),'Error')
			return
		end
		indF = inds(k);
		c = sin(p.lat*D2R)*sin(y(indF)*D2R) + cos(p.lat*D2R)*cos(y(indF)*D2R)*cos( (p.lon-x(indF))*D2R );
		rad = acos(c) / D2R;
		[latc,lonc] = circ_geo(p.lat, p.lon, rad, [], 360);
		[lonc,I] = sort(lonc);	latc = latc(I);		% To avoid a false cross detection (due to circularity not taking into acount)
		[xcFirst,ycFirst] = intersections(lonc,latc,x2,y2);
	end

	% Now do the same but find last (but rounded to 10% N_pts) point in Working isoc that fills the same condition
	idr = numel(inds):-1:1;
	inds = inds(idr);			% Reversing oder makes our life easier
	xcLast = [];	k = 0;
	while (isempty(xcLast))
		k = k + 1;
		indL = inds(k);
		c = sin(p.lat*D2R)*sin(y(indL)*D2R) + cos(p.lat*D2R)*cos(y(indL)*D2R)*cos( (p.lon-x(indL))*D2R );
		rad = acos(c) / D2R;
		[latc,lonc] = circ_geo(p.lat, p.lon, rad, [], 360);
		[lonc,I] = sort(lonc);	latc = latc(I);
		[xcLast,ycLast] = intersections(lonc,latc,x2,y2);
	end

	% So at this point we should be able to get a first good estimate of the seeked rotation pole using Bonin Method
	[plon,plat,omega] = calc_bonin_euler_pole([x(indF); x(indL)],[y(indF); y(indL)],[xcFirst; xcLast],[ycFirst; ycLast]);
	%sprintf('Lon = %.1f  Lat = %.1f   Ang = %.3f', plon, plat, omega)

	% Get the neighbor pole parameters, though we will only use its age
	p_closest = parse_finite_pole(closest_lineInfo);	% Get the pole of neighbor because we need its age
	if (isempty(p_closest))
		errordlg(sprintf('This line has no pole info. See:\n\n%s',closest_lineInfo),'Error')
		return
	end

	new_lineInfo = set_stg_info('bonin', hLine, this_lineInfo, plon, plat, omega, p, p_closest);

	if (nargout > 1)
		[plon,plat,omega] = get_last_pole(new_lineInfo);
		pole = [plon,plat,omega];
		lineInfo = new_lineInfo;
	end

% -----------------------------------------------------------------------------------------------------------------
function [new_lineInfo, is_pole_new] = set_stg_info(mode, hLine, lineInfo, plon, plat, omega, p, p_closest, CA, CB, residue)
% Update (or insert) the stage pole info in the isochron header data.
% MODE = 'bonin' insert/update the bonin type pole
% MODE = 'whatever' insert/update the Best-Fit type pole
% Actually the pole is a finite pole but due to how it was compute ... it is fact a stage pole (not convinced?)
%
% P & P_CLOSEST are structures with the finite poles of isochron CA and CB. Only P.AGE is used here
% CA, CB, RESIDUE are used only with the second generation Brute-Force (best-fit) poles and denote
% the isochron names the best fit residue
%
% On output NEW_LINEINFO holds the eventualy updated pole info (if a better best-fit pole was achieved)
%           IS_NEW_POLE -> true if the new best-fit pole has lower residue and hence used to update NEW_LINEINFO

	is_pole_new = false;
	if (isempty(lineInfo)),		lineInfo = getappdata(hLine,'LineInfo');	end
	new_lineInfo = lineInfo;

	if (strcmpi(mode,'bonin'))
		indS = strfind(lineInfo, 'STG1"');			% See if we aready have one INSITU STG
		if (isempty(indS))							% No, create one
			new_lineInfo = sprintf('%s STG1"%.1f %.1f %.1f %.2f %.3f"', lineInfo, plon, plat, p_closest.age, p.age, omega);
		else										% Yes, update it
			ind2 = strfind(lineInfo(indS+5:end),'"') + indS + 5 - 1;	% So that indS refers to string start too
			str = sprintf('%.1f %.1f %.1f %.2f %.3f', plon, plat, p_closest.age, p.age, omega);
			new_lineInfo = [lineInfo(1:indS+4) str lineInfo(ind2(1):end)];
		end

	elseif (strcmpi(mode,'stagefit'))				% Set/Update the FIT true STAGE (half) pole
		indS = strfind(lineInfo, 'STG');			% See if we aready have an true STG
		if (~isempty(indS) && lineInfo(indS(1)+3) == ' ') % The annoying old STG not quoted case. Strip it.
			indS = indS(2:end);
		end

		% Get chron ages from lineInfo in the FIN(ite) pole
		ind2 = strfind(lineInfo(indS(end):end), '"') + indS(end) - 1;
		[t, r] = strtok(lineInfo(ind2(1)+1:end));
		[t, r] = strtok(r);
		[t, r] = strtok(r);		ageB = t;
		t = strtok(r);			ageA = t;

		indS = strfind(lineInfo, 'STG3');			% Does a previous STG3 exists?
		if (isempty(indS))							% No. Append one at the end
			new_lineInfo = sprintf('%s STG3_%s-%s"%.1f %.1f %s %s %.3f %.3f"', ...
				lineInfo, CA, CB, plon, plat, ageB, ageA, omega, residue);
		else
			ind2 = (strfind(lineInfo(indS(1):end), '"') + indS(1) - 1); % Indices of the '"' pair
			ind2 = ind2(2) - 1;		ind1 = ind2;
			while (lineInfo(ind1) ~= ' '),	ind1 = ind1 - 1;	end
			old_res = str2double(lineInfo(ind1:ind2));	% Get old residue
			if ( (old_res - residue) < 1e-3 )			% Old one is better, don't change it
				return
			end
			fprintf('Anom --> %s  Res antes = %.6f  Res depois = %.6f\n',CA, old_res, residue)
			str = sprintf('"%.1f %.1f %s %s %.3f %.3f"', plon, plat, ageB, ageA, omega, residue);
			new_lineInfo = [lineInfo(1:indS+3) sprintf('_%s-%s', CA, CB) str];
			if (numel(lineInfo) > ind2+2)			% +1 to compensate the above - 1 and the other for the space
				 new_lineInfo = [new_lineInfo lineInfo(ind2+2:end)];
			end
		end
		is_pole_new = true;

	else											% Set/update the Best-Fit pole info
		indS = strfind(lineInfo, 'STG');
		if (numel(indS) > 1 && lineInfo(indS(1)+3) == ' ') % The annoying old STG not quoted case. Strip it.
			indS = indS(2:end);
		end

		% We don't always know the age of the older chron sent as argument (p_closest) so get it directly from lineInfo
		ind2 = strfind(lineInfo(indS(end):end), '"') + indS(end) - 1;
		[t, r] = strtok(lineInfo(ind2(1)+1:end));
		[t, r] = strtok(r);
		[t, r] = strtok(r);		ageB = t;
		t = strtok(r);			ageA = t;

		if (numel(indS) == 1)							% --- Only a Bonin type STG, insert the new Brute-Force one
			new_lineInfo = sprintf('%s STG2_%s-%s"%.1f %.1f %s %s %.3f %.3f"', ...
				lineInfo, CA, CB, plon, plat, ageB, ageA, omega, residue);
		else											% --- Already have a Brute-Force type STG, update it
			% the following gymnastic is because the STG string has the form STGXX_YY-ZZ"
			indS = indS(end);
			ind2 = ind2(2) - 1;		ind1 = ind2;
			while (lineInfo(ind1) ~= ' '),	ind1 = ind1 - 1;	end
			old_res = str2double(lineInfo(ind1:ind2));	% Get old residue
			if ( (old_res - residue) < 1e-3 )			% Old one is better, don't change it
				return
			end
			fprintf('Anom --> %s  Res antes = %.6f  Res depois = %.6f\n',CA, old_res, residue)
			str = sprintf('"%.1f %.1f %s %s %.3f %.3f"', plon, plat, ageB, ageA, omega, residue);
			new_lineInfo = [lineInfo(1:indS+2) sprintf('2_%s-%s', CA, CB) str];
			if (numel(lineInfo) > ind2+2)			% +1 to compensate the above - 1 and the other for the space
				 new_lineInfo = [new_lineInfo lineInfo(ind2+2:end)];
			end
		end	
		is_pole_new = true;
	end
	setappdata(hLine,'LineInfo',new_lineInfo)			% Update this isoc with just computed STG pole

% -----------------------------------------------------------------------------------------------------------------
function stage = get_true_stg (hLineA, hLineB)
% Search the info header of both line handles hLineA, hLineB for the FIN(ite) pole and:
%   Search for an existing STG0 in lineInfo and read the stage pole from it
% or
%   If not found STG0, compute the half stage pole and update the LineInfo

	lineInfoA = getappdata(hLineA,'LineInfo');
	lineInfoB = getappdata(hLineB,'LineInfo');

	pA = parse_finite_pole(lineInfoA);
	pB = parse_finite_pole(lineInfoB);

	indS = strfind(lineInfoA, 'STG0"');			% See if we already have one true (half) STG
	if (isempty(indS))							% No, create one
		stage = finite2stages([pA.lon; pB.lon], [pA.lat; pB.lat], [pA.ang; pB.ang], [pA.age; pB.age], 2, 1);
		ind =  strfind(lineInfoA, 'FIN"');
		ind2 = strfind(lineInfoA(ind:end), '"') + ind - 1;	% Find the pair of '"' indices
		new_lineInfo = sprintf('%s STG0"%.1f %.1f %.1f %.1f %.3f%s', lineInfoA(1:ind2(2)), stage(1,1), stage(1,2), ...
			stage(1,3), stage(1,4), stage(1,5), lineInfoA(ind2(2):end) );
		setappdata(hLineA,'LineInfo', new_lineInfo);
	else										% Yes, read it and send it back to caller
		ind2 = strfind(lineInfoA(indS:end), '"') + indS - 1;	% Find the pair of '"' indices
		stage = zeros(1,5);
		[t, r] = strtok( lineInfoA(ind2(1)+1:ind2(2)-1) );
		stage(1) = str2double(t);
		[t, r] = strtok(r);			stage(2) = str2double(t);	% Lat
		[t, r] = strtok(r);			stage(3) = str2double(t);	% Age older (t_start)
		[t, r] = strtok(r);			stage(4) = str2double(t);	% Age newer (t_end)
		t      = strtok(r);			stage(5) = str2double(t);	% Ang
	end

% -----------------------------------------------------------------------------------------------------------------
function stage = get_stg_pole(stg, lineInfo)
% Parse the string starting at STG?_XX-XX" and read the stage pole parameters
% Also tries to get the residue, which will be NaN if it doesn't exist

	stage = (1:6)* NaN;			% Make sure the 6 elements are always return
	if (isempty(lineInfo)),		return,		end
	indS = strfind(lineInfo, stg);
	if (isempty(indS)),			return,		end
	ind2 = strfind(lineInfo(indS:end), '"') + indS - 1;	% Find the pair of '"' indices
	[t, r] = strtok( lineInfo(ind2(1)+1:ind2(2)-1) );
	stage(1) = str2double(t);
	[t, r] = strtok(r);			stage(2) = str2double(t);	% Lat
	[t, r] = strtok(r);			stage(3) = str2double(t);	% Age older (t_start)
	[t, r] = strtok(r);			stage(4) = str2double(t);	% Age newer (t_end)
	[t, r] = strtok(r);			stage(5) = str2double(t);	% Ang
	t      = strtok(r);			stage(6) = str2double(t);	% Residue

% -----------------------------------------------------------------------------------------------------------------
function [plon,plat,ang] = get_last_pole(lineInfo)
% Get the finite pole parameters from the pseudo stage pole stored in STGXX
% By getting the last STG in lineInfo we are getting the most updated.

	indS = strfind(lineInfo, 'STG');
	if (isempty(indS) || ((numel(indS) == 1) && (lineInfo(indS+3) == ' ')) )
		% An old STG not quoted case (to be deleted some time later)
		indS = indS(2:end);
	end

	str = lineInfo(indS(end):end);		% This now has only the STGXX_??"....." string
	ind2 = strfind(str,'"') + 1;		% Add 1 to start after the quote
	[plon, r] = strtok(str(ind2(1):end));
	[plat, r] = strtok(r);
	[t, r] = strtok(r);
	[t, r] = strtok(r);
	ang = strtok(r);
	if (ang(end) == '"'),	ang(end) = [];	end		% STG1 doesn't have the last element as residue, hence the '"'
	plon = str2double(plon);
	plat = str2double(plat);
	ang = str2double(ang);

% -----------------------------------------------------------------------------------------------------------------
function p = get_STG_pole(lineInfo, stg)
% Get the finite pole parameters from the pseudo stage pole stored in STGX
% Returns the result in a structure as parse_finite_pole, or empty if not found

	p = [];

	indS = strfind(lineInfo, stg);
	if (isempty(indS))
		fprintf('The requested pole, %s does not exist in this isochron header\n%s\n', stg, lineInfo);
		return
	end

	ind2 = strfind(lineInfo(indS:end),'"') + indS - 1;			% It starts after the quote
	[t, r] = strtok(lineInfo(ind2(1)+1:ind2(2)-1));				p.lon = sscanf(t, '%f');
	[t, r] = strtok(r);			p.lat  = sscanf(t, '%f');
	[t, r] = strtok(r);			p.ageB = sscanf(t, '%f');		% Call it ageB 
	[t, r] = strtok(r);			p.age  = sscanf(t, '%f');		% Call it simply 'age' to go along with the FIN(ite) pole
	p.ang = sscanf(strtok(r), '%f');

% -----------------------------------------------------------------------------------------------------------------
function p = parse_finite_pole(lineInfo)
% Find the Euler pole parameters from the header line of an isochron
	indF = strfind(lineInfo, 'FIN"');
	if (isempty(indF)),		p = [];		return,		end
	ind2 = strfind(lineInfo(indF+4:end),'"') + indF + 4 - 1;	% So that ind refers to the begining string too
	[t, r] = strtok(lineInfo(indF(1)+4:ind2(1)-1));
	p.lon = sscanf(t, '%f');
	[t, r] = strtok(r);			p.lat = sscanf(t, '%f');
	[t, r] = strtok(r);			p.ang = sscanf(t, '%f');
	t      = strtok(r);			p.age = sscanf(t, '%f');

% -----------------------------------------------------------------------------------------------------------------
function isoc = get_isoc_numeric(isoc_str)
% Get the isoc name in numeric form. We need a fun because isoc names sometimes have letters
	if (isoc_str(end) == 'a' || isoc_str(end) == 'r')		% We have 4a, 33r, etc...
		isoc_str = [isoc_str(1:end-1) '.1'];	% Just to be older than the corresponding 'no a' version
	end
	if (isoc_str(1) == 'M'),	isoc_str = ['10' isoc_str(2:end)];	end		% The M's are older. Pretend it's 100, etc.
	isoc = str2double(isoc_str);

