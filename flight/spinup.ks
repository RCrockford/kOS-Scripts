@lazyglobal off.

// Wait for unpack
wait until Ship:Unpacked.

parameter maxRoll is 0.5.

switch to scriptpath():volume.

runoncepath("/fcfuncs").

runpath("/flight/tunesteering").

LAS_Avionics("activate").
rcs on.

local debugGui is GUI(300, 80).
set debugGui:X to 100.
set debugGui:Y to debugGui:Y + 300.
local mainBox is debugGui:AddVBox().
local debugStat is mainBox:AddLabel("").
debugGui:Show().

local rollRate is 0.
until rollRate >= maxRoll
{
    set debugStat:Text to "a = " + round(abs(SteeringManager:AngleError), 2) + "   ω = " + round(rollRate, 2) + " / " + round(maxRoll, 2).
    wait 0.
    set rollRate to vdot(Facing:Vector, Ship:AngularVel).
    if abs(SteeringManager:AngleError) > 0.1
        set ship:control:roll to 0.
    else
        set ship:control:roll to -maxRoll / abs(maxRoll).
}

set ship:control:neutralize to true.
unlock steering.
rcs off.
LAS_Avionics("shutdown").
ClearGUIs().
