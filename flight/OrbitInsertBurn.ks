@lazyglobal off.
wait until Ship:Unpacked.
local p is readjson("1:/burn.json").
print"OrbIns waiting".
wait until Eta:Periapsis-p:t*0.5<60.
local _0 is list().
list engines in _0.
for a in Ship:ModulesNamed("ModuleProceduralAvionics")
if a:HasEvent("activate avionics")
a:DoEvent("activate avionics").
rcs on.
lock steering to Ship:Retrograde.
wait until Eta:Periapsis<=p:t*0.5+1.
rcs on.
set Ship:Control:Fore to 1.
for e in _0
wait until e:FuelStability>=0.99.
set Ship:Control:PilotMainThrottle to 1.
for e in _0
e:Activate.
wait 0.
set Ship:Control:Fore to 0.
wait until e[0]:Thrust<=0.1.
set Ship:Control:PilotMainThrottle to 0.
for e in _0
e:Shutdown.
unlock steering.
set Ship:Control:Neutralize to true.
rcs off.
for a in Ship:ModulesNamed("ModuleProceduralAvionics")
if a:HasEvent("shutdown avionics")
a:DoEvent("shutdown avionics").
set core:bootfilename to"".
