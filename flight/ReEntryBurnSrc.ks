@lazyglobal off.

wait until Ship:Unpacked.

local p is readjson("1:/burn.json").

if abs(p:oLatLong) <= 180
{
    print "Waiting for re-entry alignment: " + round(p:oLatLong, 2).

	if abs(Ship:Obt:Inclination) > 60 and abs(Ship:Obt:Inclination) < 120
	{
		wait until abs(Ship:Latitude - p:oLatLong) < 0.5.
	}
	else
	{
		wait until abs(Ship:Longitude - p:oLatLong) < 0.5.
	}
}

runoncepath("/FCFuncs").

LAS_Avionics("activate").

rcs on.
lock steering to LookDirUp(Retrograde:Vector, Facing:UpVector).

if abs(p:bLatLong) > 180
{
	wait until abs(SteeringManager:AngleError) < 0.2 and (Ship:AngularVel:SqrMagnitude - (vdot(Ship:Facing:Vector, Ship:AngularVel)^2) < 1e-4).
}
else if abs(Ship:Obt:Inclination) > 60 and abs(Ship:Obt:Inclination) < 120
{
	wait until abs(Ship:Latitude - p:bLatLong) < 0.1.
}
else
{
	wait until abs(Ship:Longitude - p:bLatLong) < 0.1.
}

if Ship:Obt:Periapsis > p:pe
{
	print "Commencing re-entry burn.".

    if p:engines
    {
        runpath("/flight/EngineMgmt", Stage:Number).
        if not EM_Ignition()
        {
            set p:engines to false.
        }
    }
    if not p:engines
        set Ship:Control:Fore to 1.

	local shipMass is Ship:mass.
	until Ship:Obt:Periapsis <= p:pe
	{
		wait 0.1.
		if shipMass = Ship:mass
		{
			if p:engines
			{
				set Ship:Control:Fore to 1.
				set p:engines to false.
			}
			else
			{
				print "Out of fuel, aborting burn.".
				break.
			}
		}
		set shipMass to Ship:Mass.
	}
}

set Ship:Control:PilotMainThrottle to 0.

runoncepath("/flight/ReEntryLanding").
