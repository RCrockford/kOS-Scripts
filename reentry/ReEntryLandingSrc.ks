@lazyglobal off.

wait until Ship:Unpacked.

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

wait until Ship:Q > 1e-5.

for a in Ship:ModulesNamed("ModuleProceduralAvionics")
{
	if a:HasEvent("activate avionics")
		a:DoEvent("activate avionics").
}

rcs on.
lock steering to LookDirUp(SrfRetrograde:Vector, Facing:UpVector).

wait until vdot(SrfRetrograde:Vector, Facing:Vector) > 0.9995.
wait 1.

unlock steering.
set Ship:Control:Neutralize to true.
rcs off.

for a in Ship:ModulesNamed("ModuleProceduralAvionics")
{
	if a:HasEvent("shutdown avionics")
		a:DoEvent("shutdown avionics").
}

set core:bootfilename to "".

wait until ship:airspeed < 50.

for hs in Ship:ModulesNamed("ModuleDecouple")
{
    if hs:HasEvent("jettison heat shield")
    {
        hs:DoEvent("jettison heat shield").
    }
}
