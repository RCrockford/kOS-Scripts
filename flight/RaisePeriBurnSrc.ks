@lazyglobal off.

wait until Ship:Unpacked.

local p is readjson("1:/burn.json").

runpath("/flight/EngineMgmt", stage:number).
local activeEngines is EM_GetEngines().
local ignitionTime is EM_IgDelay().

print "Align in " + round(Eta:Apoapsis - p:t * 0.5 - 60, 1) + "s".

wait until Eta:Apoapsis - p:t * 0.5 < 60.

print "Aligning ship".

LAS_Avionics("activate").

rcs on.
lock steering to Ship:Prograde.

wait until Eta:Apoapsis <= p:t * 0.5 + ignitionTime.

print "Starting burn".

EM_Ignition().

wait until Ship:Obt:Periapsis >= p:pe or activeEngines[0]:Thrust < activeEngines[0]:PossibleThrust * 0.1.

// Cutoff engines
set Ship:Control:PilotMainThrottle to 0.
for eng in activeEngines
{
    eng:Shutdown.
}

print "MECO".

unlock steering.
set Ship:Control:Neutralize to true.
rcs off.

LAS_Avionics("shutdown").