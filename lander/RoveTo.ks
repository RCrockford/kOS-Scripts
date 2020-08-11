@lazyglobal off.

parameter targetPoint is AllWaypoints()[0].
parameter maxSpeed is 10.
parameter minDist is 20.

local targetGeoPos is choose targetPoint:GeoPosition if targetPoint:IsType("WayPoint") else targetPoint.

local steerPid is PIDLoop(0.1, 0, 0.1, -1, 1).
local throttlePid is PIDLoop(0.2, 0.005, 0.15, -1, 1).

local statusGui is Gui(300).
set statusGui:X to 200.
set statusGui:Y to statusGui:Y + 80.

local mainBox is statusGui:AddHBox().
local labelBox is mainBox:AddVBox().
set labelBox:style:width to 150.
local statusBox is mainBox:AddVBox().
set statusBox:style:width to 150.

local guiStatus is lexicon().

local function createGuiInfo
{
    parameter tagStr.
    parameter lblStr.

    local ctrl is labelBox:AddLabel(lblStr).
    set ctrl:Style:Height to 25.

    set ctrl to statusBox:AddTextField("").
    set ctrl:Style:Height to 25.
    set ctrl:Enabled to false.

    guiStatus:add(tagStr, ctrl).
}

createGuiInfo("hdg", "Heading").
createGuiInfo("br", "Bearing").
createGuiInfo("dst", "Distance").

statusGui:Show().

brakes off.

until targetPoint:Distance < minDist
{
	set steerPid:kP to 0.02 / max(0.5, Ship:GroundSpeed / 4).
	set steerPid:kD to steerPid:kP * 2 / 3.
	
	set Ship:Control:WheelSteer to steerPid:update(time:seconds, targetPoint:Bearing).
	
	set Ship:Control:WheelThrottle to throttlePid:update(time:seconds, Ship:GroundSpeed - maxSpeed).
	if Ship:Control:WheelThrottle < 0.1
		brakes on.
	else
		brakes off.
	
	set guiStatus:hdg:text to round(targetPoint:Heading, 1) + "°".
	set guiStatus:br:text to round(targetPoint:Bearing, 1) + "°".
	if targetPoint:Distance > 5000
		set guiStatus:dst:text to round(targetPoint:Distance, 1) + " km".
	else if targetPoint:Distance > 1200
		set guiStatus:dst:text to round(targetPoint:Distance, 2) + " km".
	else
		set guiStatus:dst:text to round(targetPoint:Distance, 1) + " m".
}

set ship:control:neutralize to true.
brakes on.

clearGuis().
