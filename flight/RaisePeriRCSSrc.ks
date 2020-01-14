@lazyglobal off.

wait until Ship:Unpacked.

local p is readjson("1:/burn.json").

print "Align in " + round(Eta:Apoapsis - p:t * 0.5 - 60, 1) + "s".

wait until Eta:Apoapsis - p:t * 0.5 < 60.

print "Aligning ship".

for a in Ship:ModulesNamed("ModuleProceduralAvionics")
    if a:HasEvent("activate avionics")
        a:DoEvent("activate avionics").

rcs on.
lock steering to Ship:Prograde.

wait until Eta:Apoapsis <= p:t * 0.5.

print "Starting burn".
set Ship:Control:Fore to 1.

wait until Ship:Obt:Periapsis >= p:pe.

unlock steering.
set Ship:Control:Neutralize to true.
rcs off.

for a in Ship:ModulesNamed("ModuleProceduralAvionics")
    if a:HasEvent("shutdown avionics")
        a:DoEvent("shutdown avionics").

set core:bootfilename to "".
