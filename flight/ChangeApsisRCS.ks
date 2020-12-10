@lazyglobal off.

wait until Ship:Unpacked.

local p is readjson("1:/burn.json").

local lock burnEta to choose eta:Apoapsis if p:ap else eta:periapsis.

print "Align in " + round(burnEta - p:t - p:align, 1) + "s to " + (choose "Prograde" if p:sma >= Ship:Orbit:SemiMajorAxis else "Retrograde").

wait until burnEta - p:t <= p:align.

kUniverse:Timewarp:CancelWarp().
print "Aligning ship".

local avionics is Ship:ModulesNamed("ModuleProceduralAvionics").

for a in avionics
    if a:HasEvent("activate avionics")
        a:DoEvent("activate avionics").

rcs on.
if p:sma >= Ship:Orbit:SemiMajorAxis
	lock steering to LookDirUp(Prograde:Vector, Facing:UpVector).
else
	lock steering to LookDirUp(Retrograde:Vector, Facing:UpVector).

wait until burnEta <= p:t.

print "Starting burn".
set Ship:Control:Fore to 1.
set Ship:Control:MainThrottle to 1.

if p:sma >= Ship:Orbit:SemiMajorAxis
	wait until Ship:Orbit:SemiMajorAxis >= p:sma.
else
	wait until Ship:Orbit:SemiMajorAxis <= p:sma.

unlock steering.
set Ship:Control:Neutralize to true.
rcs off.

for a in avionics
    if a:HasEvent("shutdown avionics")
        a:DoEvent("shutdown avionics").

set core:bootfilename to "".
