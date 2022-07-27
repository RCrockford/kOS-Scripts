@lazyglobal off.

wait until Ship:Unpacked.

unlock steering.
set Ship:Control:Neutralize to true.
rcs off.

local debugGui is GUI(300, 80).
set debugGui:X to 100.
set debugGui:Y to debugGui:Y + 300.
local mainBox is debugGui:AddVBox().
local debugStat1 is mainBox:AddLabel("Waiting for atmospheric interface").
debugGui:Show().

print "Waiting for atmospheric interface".

wait until Ship:Altitude < Ship:Body:Atm:Height.

local chutesArmed is false.
for rc in Ship:ModulesNamed("RealChuteModule")
{
    if rc:HasEvent("arm parachute")
    {
        rc:DoEvent("arm parachute").
        set chutesArmed to true.
    }
    else if rc:HasEvent("deploy chute")
    {
        rc:DoEvent("deploy chute").
        set chutesArmed to true.
    }
}

if not chutesArmed
	chutes on.

print "Chutes armed.".

until Ship:Q > 1e-5
{
    set debugStat1:Text to "Waiting for Q > 1: " + round(Ship:Q * Constant:AtmTokPa * 1000, 2) + " Pa".
    wait 0.1.
}

set kUniverse:TimeWarp:Rate to 1.

for a in Ship:ModulesNamed("ModuleProceduralAvionics")
{
	if a:HasEvent("activate avionics")
		a:DoEvent("activate avionics").
}

rcs on.
lock steering to LookDirUp(SrfRetrograde:Vector, Facing:UpVector).

local currentSpeed is Ship:Velocity:Surface:Mag.
local currentTime is Time:Seconds.

until Ship:Velocity:Surface:Mag < 1500
{
    wait 0.1.
	local accel is (Ship:Velocity:Surface:Mag - currentSpeed) / (Time:Seconds - currentTime).
	set currentSpeed to Ship:Velocity:Surface:Mag.
	set currentTime to Time:Seconds.

	set debugStat1:Text to "Acceleration: " + round(accel, 2) + " m/s²".
}

unlock steering.
set Ship:Control:Neutralize to true.
rcs off.

for a in Ship:ModulesNamed("ModuleProceduralAvionics")
{
	if a:HasEvent("shutdown avionics")
		a:DoEvent("shutdown avionics").
}

set core:bootfilename to "".

set kUniverse:TimeWarp:Mode to "Physics".
set kUniverse:TimeWarp:Rate to 1.

local droppedHS is false.

until Ship:Altitude - max(Ship:GeoPosition:TerrainHeight, 0) < 10
{
    local radarAlt is Ship:Altitude - max(Ship:GeoPosition:TerrainHeight, 0).
	set debugStat1:Text to "Landing ETA: " + round(radarAlt / Ship:Velocity:Surface:Mag, 1) + " s".
    if Ship:Velocity:Surface:Mag < 800
        set kUniverse:TimeWarp:Rate to min(max(1, round(radarAlt / 50)), 4).
        
    if Ship:Velocity:Surface:Mag < 50 and not droppedHS
    {
        for hs in Ship:ModulesNamed("ModuleDecouple")
        {
            if hs:HasEvent("jettison heat shield")
            {
                hs:DoEvent("jettison heat shield").
            }
        }
        set droppedHS to true.
    }
    
    wait 0.1.
}

clearGUIs().

