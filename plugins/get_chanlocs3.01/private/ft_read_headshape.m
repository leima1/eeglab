function [shape] = ft_read_headshape(filename, varargin)

% FT_READ_HEADSHAPE reads the fiducials and/or the measured headshape from a variety
% of files (like CTF and Polhemus). The headshape and fiducials can for example be
% used for coregistration.
%
% Use as
%   [shape] = ft_read_headshape(filename, ...)
% or
%   [shape] = ft_read_headshape({filename1, filename2}, ...)
%
% If you specify the filename as a cell-array, the following situations are supported:
%  - a two-element cell-array with the file names for the left and
%    right hemisphere, e.g. FreeSurfer's {'lh.orig' 'rh.orig'}, or
%    Caret's {'X.L.Y.Z.surf.gii' 'X.R.Y.Z.surf.gii'}
%  - a two-element cell-array points to files that represent
%    the coordinates and topology in separate files, e.g.
%    Caret's {'X.L.Y.Z.coord.gii' 'A.L.B.C.topo.gii'};
% By default all information from the two files will be concatenated (i.e. assumed to
% be the shape of left and right hemispeheres). The option 'concatenate' can be set
% to 'no' to prevent them from being concatenated in a single structure.
%
% Additional options should be specified in key-value pairs and can include
%   'unit'        = string, e.g. 'mm' (default is the native units of the file)
%   'image'       = path to .jpeg file
%
% Supported input file formats include
%   'obj'          Wavefront .obj file obtained with the structure.io
%
% See also FT_READ_VOL, FT_READ_SENS, FT_READ_ATLAS, FT_WRITE_HEADSHAPE

% Copyright (C) 2008-2017 Robert Oostenveld
%
% This file is part of FieldTrip, see http://www.fieldtriptoolbox.org
% for the documentation and details.
%
%    FieldTrip is free software: you can redistribute it and/or modify
%    it under the terms of the GNU General Public License as published by
%    the Free Software Foundation, either version 3 of the License, or
%    (at your option) any later version.
%
%    FieldTrip is distributed in the hope that it will be useful,
%    but WITHOUT ANY WARRANTY; without even the implied warranty of
%    MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
%    GNU General Public License for more details.
%
%    You should have received a copy of the GNU General Public License
%    along with FieldTrip. If not, see <http://www.gnu.org/licenses/>.
%
unit         = ft_getopt(varargin, 'unit');
grayTextures = ft_getopt(varargin, 'grayTextures');

pathstr = fileparts(filename);

% checks if there exists a .jpg file or if grayTexture override
if grayTextures
elseif isempty(dir([pathstr filesep '*.jpg']))
    warning('No .jpg texture file found! Proceeding with gray textures.')
    grayTextures = 1;
else 
    image   = fullfile(pathstr, getfield(dir([pathstr filesep '*.jpg']),'name'));
end

% Implemented for structure.io Scanner and itSeez3D .obj thus far
[shape.pos, shape.tri, texture, textureIdx] = read_obj(filename);
shape.pos     = shape.pos - repmat(sum(shape.pos)/length(shape.pos),[length(shape.pos),1]); %centering vertices

%Reorder textures according to face building instructions
f.vertInd = shape.tri; 
f.textInd = textureIdx;
if any(f.vertInd ~= f.textInd)
    orderedTexture = zeros(length(f.vertInd),2);
    for ii = 1:length(f.vertInd)
        orderedTexture(f.vertInd(ii,:),:) = texture(f.textInd(ii,:),:);
    end
    texture = orderedTexture;
end

%Refines the mesh and textures to increase resolution of the
%colormapping
if length(shape.tri) < 200000
    tic
    fprintf(['Mesh is composed of less than 200k polygons, \n'...
        'refining using FT implementation of Banks method...\n'])
    [shape.pos, shape.tri,texture] = refine(shape.pos,shape.tri,'banks',texture);
    fprintf('Mesh refinement took %f seconds\n', toc); 
end

if grayTextures
    color = 128*uint8(ones(length(shape.pos),3));
else
    picture     = imread(image);
    color = uint8(zeros(length(shape.pos),3));
    for i=1:length(shape.pos)
        if any(isnan(texture(i,:))) % holes in model stored as Nan?
            color(i,1:3) = [128 128 128]; 
        else
            color(i,1:3) = picture(round((1-texture(i,2))*length(picture)),1+floor(texture(i,1)*length(picture)),1:3);
        end
    end
end

shape = ft_convert_units(shape, unit);

% ensure that vertex positions are given in pos, not in pnt
shape = fixpos(shape);
% ensure that the numerical arrays are represented in double precision and not as integers
shape = ft_struct2double(shape);

shape.color = color;

function [pntr, trir, texr] = refine(pnt, tri, method, texture, varargin)

% REFINE a 3D surface that is described by a triangulation
%
% Use as
%   [pnt, tri]          = refine(pnt, tri)
%   [pnt, tri]          = refine(pnt, tri, 'banks')
%   [pnt, tri]          = refine(pnt, tri, 'updown', numtri)
%   [pnt, tri, texture] = refine(pnt, tri, 'banks', texture) 
%
% If no method is specified, the default is to refine the mesh globally by bisecting
% each edge according to the algorithm described in Banks, 1983.
%
% The Banks method allows the specification of a subset of triangles to be refined
% according to Banks' algorithm. Adjacent triangles will be gracefully dealt with.
%
% The alternative 'updown' method refines the mesh a couple of times
% using Banks' algorithm, followed by a downsampling using the REDUCEPATCH
% function.
%
% If the textures of the vertices are specified, the textures for the new
% vertices are computed
%
% The Banks method is a memory efficient implementation which remembers the
% previously inserted vertices. The refinement algorithm executes in linear
% time with the number of triangles. It is mentioned in
% http://www.cs.rpi.edu/~flaherje/pdf/fea8.pdf, which also contains the original
% reference.

% Copyright (C) 2002-2014, Robert Oostenveld
%
% This file is part of FieldTrip, see http://www.fieldtriptoolbox.org
% for the documentation and details.
%
%    FieldTrip is free software: you can redistribute it and/or modify
%    it under the terms of the GNU General Public License as published by
%    the Free Software Foundation, either version 3 of the License, or
%    (at your option) any later version.
%
%    FieldTrip is distributed in the hope that it will be useful,
%    but WITHOUT ANY WARRANTY; without even the implied warranty of
%    MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
%    GNU General Public License for more details.
%
%    You should have received a copy of the GNU General Public License
%    along with FieldTrip. If not, see <http://www.gnu.org/licenses/>.

npnt   = size(pnt,1);
ntri   = size(tri,1);
ntex   = size(texture,1);
insert = spalloc(3*npnt,3*npnt,3*ntri);

trir  = zeros(4*ntri,3);      % allocate memory for the new triangles
pntr  = zeros(npnt+3*ntri,3); % allocate memory for the maximum number of new vertices
texr  = zeros(ntex+3*ntri,2);
pntr(1:npnt,:) = pnt;         % insert the original vertices
texr(1:ntex,:) = texture;
current = npnt;

for i=1:ntri
    
    if ~insert(tri(i,1),tri(i,2))
        current = current + 1;
        pntr(current,:) = (pnt(tri(i,1),:) + pnt(tri(i,2),:))/2;
        texr(current,:) = (texture(tri(i,1),:) + texture(tri(i,2),:))/2;
        insert(tri(i,1),tri(i,2)) = current;
        insert(tri(i,2),tri(i,1)) = current;
        v12 = current;
    else
        v12 = insert(tri(i,1),tri(i,2));
    end
    
    if ~insert(tri(i,2),tri(i,3))
        current = current + 1;
        pntr(current,:) = (pnt(tri(i,2),:) + pnt(tri(i,3),:))/2;
        texr(current,:) = (texture(tri(i,2),:) + texture(tri(i,3),:))/2;
        insert(tri(i,2),tri(i,3)) = current;
        insert(tri(i,3),tri(i,2)) = current;
        v23 = current;
    else
        v23 = insert(tri(i,2),tri(i,3));
    end
    
    if ~insert(tri(i,3),tri(i,1))
        current = current + 1;
        pntr(current,:) = (pnt(tri(i,3),:) + pnt(tri(i,1),:))/2;
        texr(current,:) = (texture(tri(i,3),:) + texture(tri(i,1),:))/2;
        insert(tri(i,3),tri(i,1)) = current;
        insert(tri(i,1),tri(i,3)) = current;
        v31 = current;
    else
        v31 = insert(tri(i,3),tri(i,1));
    end
    
    % add the 4 new triangles with the correct indices
    trir(4*(i-1)+1, :) = [tri(i,1) v12 v31];
    trir(4*(i-1)+2, :) = [tri(i,2) v23 v12];
    trir(4*(i-1)+3, :) = [tri(i,3) v31 v23];
    trir(4*(i-1)+4, :) = [v12 v23 v31];
    
end
pntr = pntr(1:current, :);
texr = texr(1:current, :);