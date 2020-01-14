// Minimal insertion burn - target <= 900 bytes
@lazyglobal off.

wait until Ship:Unpacked.

local p is readjson("1:/burn.json").

print "OrbIns waiting".

wait until Eta:Periapsis - p:t * 0.5 < 60.

local activeEngines is list().
list engines in activeEngines.

// Align
for a in Ship:ModulesNamed("ModuleProceduralAvionics")
    if a:HasEvent("activate avionics")
        a:DoEvent("activate avionics").

rcs on.
lock steering to Ship:Retrograde.

wait until Eta:Periapsis <= p:t * 0.5 + 1.

// Ullage
rcs on.
set Ship:Control:Fore to 1.
    
for e in activeEngines
    wait until e:FuelStability >= 0.99.

set Ship:Control:PilotMainThrottle to 1.

// Ignition
for e in activeEngines
    e:Activate.

wait 0.
set Ship:Control:Fore to 0.

wait until e[0]:Thrust <= 0.1.

// Cutoff engines
set Ship:Control:PilotMainThrottle to 0.
for e in activeEngines
    e:Shutdown.

unlock steering.
set Ship:Control:Neutralize to true.
rcs off.

for a in Ship:ModulesNamed("ModuleProceduralAvionics")
    if a:HasEvent("shutdown avionics")
        a:DoEvent("shutdown avionics").

set core:bootfilename to "".
