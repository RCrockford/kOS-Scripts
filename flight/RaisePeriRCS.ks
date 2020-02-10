@lazyglobal off.
wait until Ship:Unpacked.
local p is readjson("1:/burn.json").
print"Align in "+round(Eta:Apoapsis-p:t*0.5-60,1)+"s".
wait until Eta:Apoapsis-p:t*0.5<60.
print"Aligning ship".
local _0 is Ship:ModulesNamed("ModuleProceduralAvionics").
for a in _0
if a:HasEvent("activate avionics")
a:DoEvent("activate avionics").
rcs on.
lock steering to LookDirUp(Prograde:Vector,Facing:UpVector).
wait until Eta:Apoapsis<=p:t*0.5.
print"Starting burn".
set Ship:Control:Fore to 1.
set Ship:Control:MainThrottle to 1.
wait until Ship:Obt:Periapsis>=p:pe.
unlock steering.
set Ship:Control:Neutralize to true.
rcs off.
for a in _0
if a:HasEvent("shutdown avionics")
a:DoEvent("shutdown avionics").
set core:bootfilename to"".
