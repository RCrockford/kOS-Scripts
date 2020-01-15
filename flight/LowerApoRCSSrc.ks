@lazyglobal off.

wait until Ship:Unpacked.

local p is readjson("1:/burn.json").

print "Align in " + round(Eta:Periapsis - p:t * 0.5 - 60, 1) + "s".

wait until Eta:Periapsis - p:t * 0.5 < 60.

print "Aligning ship".

local avionics is Ship:ModulesNamed("ModuleProceduralAvionics").

for a in avionics
    if a:HasEvent("activate avionics")
        a:DoEvent("activate avionics").
        
rcs on.
lock steering to LookDirUp(Retrograde:Vector, Facing:UpVector).

wait until Eta:Periapsis <= p:t * 0.5.

print "Starting burn".
set Ship:Control:Fore to 1.

wait until Ship:Obt:Apoapsis <= p:ap.

unlock steering.
set Ship:Control:Neutralize to true.
rcs off.

for a in avionics
    if a:HasEvent("shutdown avionics")
        a:DoEvent("shutdown avionics").

set core:bootfilename to "".
