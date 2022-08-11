// Minimal insertion burn - target <= 880 bytes
wait until Ship:Unpacked.

local n is list().
list engines in n.

local debugGui is GUI(300, 80).
set debugGui:X to -150.
set debugGui:Y to debugGui:Y - 480.
local mainBox is debugGui:AddVBox().

local debugStat is mainBox:AddLabel("Fuel Stability:").
debugGui:Show().

until false
{
	set debugStat:Text to "Fuel Stability: " + round(100 * n[0]:FuelStability, 1) + "%".
	wait 0.
}
