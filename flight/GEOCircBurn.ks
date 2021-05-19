@lazyglobal off.

wait until Ship:Unpacked.

local p is lexicon(open("1:/burn.csv"):readall:string:split(",")).
for k in p:keys
    set p[k] to p[k]:ToScalar(0).

runoncepath("0:/flight/FlightFuncs").
runpath("/flight/EngineMgmt", stage:number).
local ignitionTime is EM_IgDelay().

local lock tVec is vcrs(-Ship:Body:Position, Body:AngularVel):Normalized.

local lock NodeAngle to (choose 180 if Ship:Latitude > 0 else 360) - mod(Ship:Orbit:ArgumentOfPeriapsis + Ship:Orbit:TrueAnomaly + 360, 360).
local lock meanAnomDelta to mod(CalcMeanAnom(Ship:Orbit:TrueAnomaly + NodeAngle) - CalcMeanAnom(Ship:Orbit:TrueAnomaly) + 360, 360).

local alignAngle is (p:t + p:align) * 360 / Ship:Orbit:Period.
local burnAngle is (p:t + ignitionTime) * 360 / Ship:Orbit:Period.

print "Align angle " + round(alignAngle, 2) + "°".
print "Burn angle " + round(burnAngle, 2) + "°".

local debugGui is GUI(300, 80).
set debugGui:X to 100.
set debugGui:Y to debugGui:Y + 220.
local mainBox is debugGui:AddVBox().
local debugStat is mainBox:AddLabel("Liftoff").
debugGui:Show().

until meanAnomDelta <= alignAngle
{
	set debugStat:Text to round(meanAnomDelta, 2) + "°".
    if meanAnomDelta < alignAngle + 1 and kUniverse:Timewarp:Rate > 10
        set kUniverse:Timewarp:Rate to 10.
	wait 0.1.
}

kUniverse:Timewarp:CancelWarp().
print "Aligning ship".

LAS_Avionics("activate").

local lock deltaV to p:tV * tVec - Ship:Velocity:Orbit.

rcs on.
lock steering to LookDirUp(deltaV:Normalized, Facing:UpVector).

until meanAnomDelta <= burnAngle
{
	set debugStat:Text to round(meanAnomDelta, 2) + "°".
	wait 0.1.
}

print "Starting burn".

ClearGUIs().

EM_Ignition().
rcs off.

wait until Ship:Obt:SemiMajorAxis >= (35793170 + Ship:Body:Radius) or not EM_CheckThrust(0.1).

EM_Shutdown().
