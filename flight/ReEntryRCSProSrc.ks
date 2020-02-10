@lazyglobal off.

wait until Ship:Unpacked.

local p is readjson("1:/burn.json").

rcs on.
lock steering to LookDirUp(Prograde:Vector, Facing:UpVector).

wait until abs(SteeringManager:AngleError) < 0.2.

set Ship:Control:Fore to -1.

local shipMass is Ship:mass.
until Ship:Obt:Periapsis <= p:pe
{
    wait 0.1.
    if shipMass = Ship:mass
    {
        print "Out of fuel.".
        break.
    }
    set shipMass to Ship:Mass.
}

unlock steering.
set Ship:Control:Neutralize to true.
rcs off.

wait until Ship:Altitude < Ship:Body:Atm:Height.

local chutesArmed is false.
for rc in Ship:ModulesNamed("RealChuteModule")
{
    if rc:HasEvent("arm parachute")
    {
        rc:DoEvent("arm parachute").
        set chutesArmed to true.
    }
}

if not chutesArmed
	chutes on.

print "Chutes armed.".

wait until Ship:Q > 1e-4.

rcs on.
lock steering to LookDirUp(SrfRetrograde:Vector, Facing:UpVector).

wait until Ship:AirSpeed < 1500.

unlock steering.
set Ship:Control:Neutralize to true.
rcs off.

set core:bootfilename to "".