@lazyglobal off.
wait until Ship:Unpacked.
unlock steering.
set Ship:Control:Neutralize to true.
rcs off.
wait until Ship:Altitude<Ship:Body:Atm:Height.
local _0 is false.
for rc in Ship:ModulesNamed("RealChuteModule")
{
if rc:HasEvent("arm parachute")
{
rc:DoEvent("arm parachute").
set _0 to true.
}
}
if not _0
chutes on.
print"Chutes armed.".
wait until Ship:Q>1e-5.
for a in Ship:ModulesNamed("ModuleProceduralAvionics")
{
if a:HasEvent("activate avionics")
a:DoEvent("activate avionics").
}
rcs on.
lock steering to LookDirUp(SrfRetrograde:Vector,Facing:UpVector).
wait until Ship:Airspeed<2500.
unlock steering.
set Ship:Control:Neutralize to true.
rcs off.
for a in Ship:ModulesNamed("ModuleProceduralAvionics")
{
if a:HasEvent("shutdown avionics")
a:DoEvent("shutdown avionics").
}
set core:bootfilename to"".
wait until ship:airspeed<50.
for hs in Ship:ModulesNamed("ModuleDecouple")
{
if hs:HasEvent("jettison heat shield")
{
hs:DoEvent("jettison heat shield").
}
}
