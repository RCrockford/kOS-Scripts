wait until Ship:Unpacked.
local p is readjson("1:/burn.json").
print"OrbInsWait".
wait until Eta:Periapsis-p:t*0.5<60.
local n is list().
list engines in n.
local _0 is Ship:ModulesNamed("ModuleProceduralAvionics").
for a in _0
if a:HasEvent("activate avionics")
a:DoEvent("activate avionics").
rcs on.
lock steering to LookDirUp(Retrograde:Vector,Facing:UpVector).
wait until Eta:Periapsis<=p:t*0.5+1.
set Ship:Control:Fore to 1.
for e in n
wait until e:FuelStability>=0.99.
set Ship:Control:MainThrottle to 1.
for e in n
e:Activate.
wait until n[0]:Thrust>n[0]:PossibleThrust*0.5 or n[0]:Flameout.
set Ship:Control:Fore to 0.
wait until n[0]:Flameout.
for e in n
e:Shutdown.
unlock steering.
set Ship:Control:Neutralize to true.
rcs off.
for a in _0
if a:HasEvent("shutdown avionics")
a:DoEvent("shutdown avionics").
set core:bootfilename to"".
