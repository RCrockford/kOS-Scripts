@lazyglobal off.

parameter trackShip is ship.
parameter wp is AllWaypoints()[0].

local debugGui is gui(180).
local debugText is debugGui:AddVBox():AddLabel("").
debugGui:Show().

until false 
{
	set debugText:Text to wp:Name + ": " + round((trackShip:geoposition:position - wp:geoposition:position):Mag, 1) + " m".
	wait 1.
}