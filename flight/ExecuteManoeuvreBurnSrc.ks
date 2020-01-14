@lazyglobal off.

wait until Ship:Unpacked.

local p is readjson("1:/burn.json").

print "Align in " + round(p:eta - 60, 1) + " seconds.".

wait until p:eta < 60.

print "Aligning ship".

local ignitionTime is 0.
local activeEngines is list().
if p:eng
{
    runpath("/flight/EngineMgmt", p:stage).
    set activeEngines to EM_GetEngines().
    set ignitionTime to EM_IgDelay().
}

LAS_Avionics("activate").

rcs on.
lock steering to p:dV:Normalized.

if p:inertial
{
    // spin up
    set Ship:Control:Roll to -1.
    until p:eta <= ignitionTime
    {
        local rollRate is vdot(Ship:Facing:Vector, Ship:AngularVel).
        if abs(rollRate) > p:spin * 1.25
        {
            set Ship:Control:Roll to 0.1.
        }
        else if abs(rollRate) > p:spin and abs(rollRate) < p:spin * 1.2
        {
            set Ship:Control:Roll to -0.1.
        }

        wait 0.
    }

    set Ship:Control:Roll to -0.1.
}
else
{
    wait until p:eta <= ignitionTime.
}

print "Starting burn".

// If we have engines, prep them to ignite.
if not activeEngines:empty
{
    local fuelRes is 0.
    local fuelTarget is 0.
	for r in Ship:Resources
	{
		if r:Name = p:fuelN
		{
			set fuelRes to r.
            // Wait until we have burned the right amount of fuel.
            set fuelTarget to r:Amount - p:fuelA.
		}
	}

    EM_Ignition().

    // If this is a spun kick stage, then decouple it.
    if p:inertial
    {
        wait until Stage:Ready.
        unlock steering.
        set Ship:Control:Neutralize to true.
        rcs off.
        stage.
    }

    wait until fuelRes:Amount <= fuelTarget.
}
else
{
    // Otherwise assume this is an RCS burn
    set Ship:Control:Fore to 1.

    wait p:t.
}

// Cutoff engines
set Ship:Control:PilotMainThrottle to 0.
for eng in activeEngines
{
    eng:Shutdown.
}
if not activeEngines:empty
    print "MECO".

unlock steering.
set Ship:Control:Neutralize to true.
rcs off.

LAS_Avionics("shutdown").
