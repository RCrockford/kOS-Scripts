@lazyglobal off.

local debugGui is GUI(300, 80).
set debugGui:X to 100.
set debugGui:Y to debugGui:Y + 300.
local mainBox is debugGui:AddVBox().
local debugStat is mainBox:AddLabel("").
debugGui:Show().

until false
{
	set debugStat:Text to "Sun Angle = " + vang(Sun:Position - Body:Position, -Body:Position) + "°".
	wait 1.
}