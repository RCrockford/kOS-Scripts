@lazyglobal off.

wait until Ship:Unpacked.

local p is lexicon(open("1:/burn.csv"):readall:string:split(",")).
for k in p:keys
    set p[k] to p[k]:ToScalar(0).

runpath("/flight/EngineMgmt", stage:number).
local ignitionTime is EM_IgDelay().

local lock burnEta to choose eta:Apoapsis if p:ap > 0 else eta:periapsis.

print "Align in " + round(burnEta - p:t - p:align, 1) + "s to " + (choose "Prograde" if p:sma >= Ship:Orbit:SemiMajorAxis else "Retrograde").

wait until burnEta - p:t <= p:align.

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