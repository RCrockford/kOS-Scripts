@lazyglobal off.

wait until Ship:Unpacked.

local p is readjson("1:/burn.json").

runpath("/flight/EngineMgmt", stage:number).
local ignitionTime is EM_IgDelay().

local lock NodeAngle to mod(360 - (Ship:Orbit:ArgumentOfPeriapsis + Ship:Orbit:TrueAnomaly), 180).
local NodeETA is NodeAngle * Ship:Orbit:Period / 360.

print "Align in " + round(NodeETA - p:t * 0.5 - 60, 1) + "s".

local alignAngle is (p:t * 0.5 + 60) * 180 / Ship:Orbit:Period.
local burnAngle is (p:t * 0.5 + ignitionTime) * 180 / Ship:Orbit:Period.

wait until NodeAngle <= alignAngle.

print "Aligning ship".

LAS_Avionics("activate").

rcs on.
lock steering to LookDirUp(Retrograde:Vector, Facing:UpVector).

wait until NodeAngle <= burnAngle.

print "Starting burn".

EM_Ignition().

wait until Ship:Obt:Apoapsis >= 35786000 or not EM_CheckThrust(0.1).

EM_Shutdown().
