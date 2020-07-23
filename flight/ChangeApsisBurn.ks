@lazyglobal off.

wait until Ship:Unpacked.

local p is readjson("1:/burn.json").

runpath("/flight/EngineMgmt", stage:number).
local ignitionTime is EM_IgDelay().

local lock burnEta to choose eta:Apoapsis if p:ap else eta:periapsis.

print "Align in " + round(burnEta - p:t - 60, 1) + "s to " + (choose "Prograde" if p:sma >= Ship:Orbit:SemiMajorAxis else "Retrograde").

wait until burnEta - p:t < 60.

kUniverse:Timewarp:CancelWarp().
print "Aligning ship".

LAS_Avionics("activate").

rcs on.
if p:sma >= Ship:Orbit:SemiMajorAxis
	lock steering to LookDirUp(Prograde:Vector, Facing:UpVector).
else
	lock steering to LookDirUp(Retrograde:Vector, Facing:UpVector).

wait until burnEta <= p:t + ignitionTime.

print "Starting burn".

EM_Ignition().

if p:sma >= Ship:Orbit:SemiMajorAxis
	wait until Ship:Orbit:SemiMajorAxis >= p:sma or not EM_CheckThrust(0.1).
else
	wait until Ship:Orbit:SemiMajorAxis <= p:sma or not EM_CheckThrust(0.1).

EM_Shutdown().