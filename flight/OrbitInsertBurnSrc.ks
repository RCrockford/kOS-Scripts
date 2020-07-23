// Minimal insertion burn - target <= 880 bytes
wait until Ship:Unpacked.

local p is readjson("1:/burn.json").

print "OrbInsWait".

wait until Eta:Periapsis - p:t * 0.5 < 60.

local n is list().
list engines in n.

local avionics is Ship:ModulesNamed("ModuleProceduralAvionics").

// Align
for a in avionics
    if a:HasEvent("activate avionics")
        a:DoEvent("activate avionics").

rcs on.
lock steering to LookDirUp(Retrograde:Vector, Facing:UpVector).

wait until Eta:Periapsis <= p:t * 0.5 + 1.

// Ullage
set Ship:Control:Fore to 1.
    
for e in n
    wait until e:FuelStability >= 0.99.
	
set Ship:Control:MainThrottle to 1.

// Ignition
for e in n
    e:Activate.

wait until n[0]:Thrust > (n[0]:PossibleThrust * 0.5).

set Ship:Control:Fore to 0.

wait until n[0]:Flameout.

// Cutoff engines
for e in n
    e:Shutdown.

unlock steering.
set Ship:Control:Neutralize to true.
rcs off.

for a in avionics
    if a:HasEvent("shutdown avionics")
        a:DoEvent("shutdown avionics").

set core:bootfilename to "".
