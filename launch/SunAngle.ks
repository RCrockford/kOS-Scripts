@lazyglobal off.

clearguis().

local debugGui is GUI(300, 80).
set debugGui:X to 100.
set debugGui:Y to debugGui:Y + 300.
local mainBox is debugGui:AddVBox().
local debugStat is mainBox:AddLabel("").
local debugStat2 is mainBox:AddLabel("").
debugGui:Show().

until false
{
	local sunVec is (Sun:Position - Body:Position):Normalized.
    local sunTangVec is vxcl(Up:Vector, sunVec):Normalized.

	local sunUp is vdot(sunVec, Up:Vector).
    local sunEast is vdot(North:StarVector, sunTangVec).
	local launchAngle is arccos(abs(vdot(sunVec, sunTangVec))).
    
    // If sun is up and east, or down and west then we're just past the launch window
    if (sunUp > 0) = (sunEast > 0)
        set launchAngle to 180 - launchAngle.
	
	set debugStat:Text to "Sun up=" + round(sunUp, 4) + " east=" + round(sunEast, 4).
	set debugStat2:Text to "Launch Angle = " + round(launchAngle, 2) + "°".
	
	wait 1.
}
