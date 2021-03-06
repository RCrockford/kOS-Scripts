@lazyglobal off.

// Wait for unpack
wait until Ship:Unpacked.

switch to scriptpath():volume.

parameter multiplier is 1.

runoncepath("0:/FCFuncs").

runpath("0:/flight/tunesteering").

LAS_Avionics("activate").

rcs on.
lock steering to lookdirup(Sun:Position * multiplier, Facing:UpVector).

local debugGui is GUI(300, 80).
set debugGui:X to 100.
set debugGui:Y to debugGui:Y + 300.
local mainBox is debugGui:AddVBox().
local debugStat is mainBox:AddLabel("").
debugGui:Show().

until abs(vdot(Sun:Position:Normalized, Facing:Vector)) > 0.99999 and abs(SteeringManager:AngleError) < 0.1 and Ship:AngularVel:Mag < 1e-3
{
	set debugStat:Text to "a = " + round(abs(SteeringManager:AngleError), 2) + " / 0.1   ω = " + round(Ship:AngularVel:Mag, 6).
	wait 0.
}

lock steering to "kill".

until Ship:AngularVel:Mag < 2e-4
{
	set debugStat:Text to "a = " + round(abs(SteeringManager:AngleError), 2) + " / 0.1   ω = " + round(Ship:AngularVel:Mag, 6).
	wait 0.
}

print "a = " + round(abs(SteeringManager:AngleError), 2) + " / 0.1  ω = " + round(Ship:AngularVel:Mag, 6).

unlock steering.
rcs off.
LAS_Avionics("shutdown").
ClearGUIs().
