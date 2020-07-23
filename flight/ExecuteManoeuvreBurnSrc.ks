@lazyglobal off.

wait until Ship:Unpacked.

local p is readjson("1:/burn.json").

local lock tVec to Prograde:Vector.
local lock bVec to vcrs(tVec, up:vector):Normalized.
local lock nVec to vcrs(tVec, bVec):Normalized.

local dV is v(0,0,0).
if HasNode
{
    lock burnETA to NextNode:eta.
	set dV to NextNode:deltaV.
}
else
{
	lock burnETA to p:eta - Time:Seconds.
	set dV to tVec * p:dV:x + nVec * pDv:y + bVec * p:dV:z.
}

print "Align in " + round(burnETA - 60, 0) + " seconds.".

wait until burnETA < 60.

kUniverse:Timewarp:CancelWarp().
print "Aligning ship".

runoncepath("/FCFuncs").
runpath("flight/TuneSteering").

local ignitionTime is 0.
if p:eng
{
    runpath("/flight/EngineMgmt", p:stage).
    set ignitionTime to EM_IgDelay().
}

local function CheckHeading
{
	if HasNode and nextNode:eta < 60
		set dV to NextNode:deltaV.
	else if p:haskey("dV")
		set dV to tVec * p:dV:x + nVec * pDv:y + bVec * p:dV:z.
}

LAS_Avionics("activate").
CheckHeading().

rcs on.
lock steering to LookDirUp(dV:Normalized, Facing:UpVector).

if p:inertial
{
    // spin up
    until burnETA <= ignitionTime
    {
		if vdot(dV:Normalized, Facing:Vector) > 0.99
		{
			local rollRate is vdot(Facing:Vector, Ship:AngularVel).
			if abs(rollRate) > p:spin * 1.25
			{
				set Ship:Control:Roll to 0.1.
			}
			else if abs(rollRate) > p:spin and abs(rollRate) < p:spin * 1.2
			{
				set Ship:Control:Roll to -0.1.
			}
			else
			{
				set Ship:Control:Roll to -1.
			}
		}

		CheckHeading().
        wait 0.
    }

    set Ship:Control:Roll to -0.1.
}
else
{
    wait until burnETA <= ignitionTime + 5.
	CheckHeading().
	wait until burnETA <= ignitionTime.
}

print "Starting burn".

// If we have engines, ignite them.
if p:eng
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

    until fuelRes:Amount <= fuelTarget or not EM_CheckThrust(0.1)
	{
		CheckHeading().
		wait 0.
	}

    EM_Shutdown().
}
else
{
    // Otherwise assume this is an RCS burn
    set Ship:Control:Fore to 1.

	local stopTime is Time:Seconds + p:t.
	until stopTime <= Time:Seconds
	{
		CheckHeading().
		wait 0.
	}

    unlock steering.
    set Ship:Control:Neutralize to true.
    rcs off.

    LAS_Avionics("shutdown").
}
