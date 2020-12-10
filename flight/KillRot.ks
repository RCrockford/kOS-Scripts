@lazyglobal off.

// Wait for unpack
wait until Ship:Unpacked.

switch to scriptpath():volume.

runoncepath("/FCFuncs").

runpath("/flight/tunesteering").

LAS_Avionics("activate").

rcs on.

local debugGui is GUI(300, 80).
set debugGui:X to 100.
set debugGui:Y to debugGui:Y + 300.
local mainBox is debugGui:AddVBox().
local debugStat is mainBox:AddLabel("").
debugGui:Show().

lock steering to "kill".

until Ship:AngularVel:Mag < 2e-4
{
	set debugStat:Text to "avm = " + round(Ship:AngularVel:Mag, 6).
	wait 0.
}

unlock steering.
rcs off.
LAS_Avionics("shutdown").
ClearGUIs().
