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

wait until Ship:Q > 1e-4.

rcs on.
lock steering to LookDirUp(SrfRetrograde:Vector, Facing:UpVector).

local debugGui is GUI(300, 80).
set debugGui:X to -150.
set debugGui:Y to debugGui:Y - 480.
local mainBox is debugGui:AddVBox().
local debugStat is mainBox:AddLabel("Liftoff").
debugGui:Show().

until vdot(SrfRetrograde:Vector, Facing:Vector) > 0.9995
{
	set debugStat:Text to vdot(SrfRetrograde:Vector, Facing:Vector) + " / " + 0.9995.
	wait 0.1.
}
//wait until vdot(SrfRetrograde:Vector, Facing:Vector) > 0.9995.

unlock steering.
set Ship:Control:Neutralize to true.
rcs off.

set core:bootfilename to "".

wait until ship:airspeed < 50.

for hs in Ship:ModulesNamed("ModuleDecouple")
{
    if hs:HasEvent("jettison heat shield")
    {
        hs:DoEvent("jettison heat shield").
    }
}
