% the cluster Fieldtrip functions necessary to look at how to combine channels
% were renamed with the prefix limo_ft_
%
% Note that these functions from FieldTrip are under GPL, while LIMO
% functions are under MIT - which limits how you can reuse them.
%
% LIMO_FT_PREPARE_LAYOUT calls:
%   LIMO_FT_WARP_APPLY
%   LIMO_FT_ELPROJ
%   LIMO_FT_CHANNELPOSITION
%   LIMO_FT_ROTATE
%   LIMO_FT_SENSTYPE
%   LIMO_FT_DIST
%
% LIMO_FT_SENSTYPE calls:
%   LIMO_FT_ISSUBFIELD
%   LIMO_FT_SENS_LABEL
% ------------------------------
%  Copyright (C) LIMO Team 2019

% v1: GAR, University of Glasgow, June 2010
