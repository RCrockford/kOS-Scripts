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
wait until Ship:Q>1e-4.
rcs on.
lock steering to LookDirUp(SrfRetrograde:Vector,Facing:UpVector).
local _1 is GUI(300,80).
set _1:X to-150.
set _1:Y to _1:Y-480.
local _2 is _1:AddVBox().
local _3 is _2:AddLabel("Liftoff").
_1:Show().
until vdot(SrfRetrograde:Vector,Facing:Vector)>0.9995
{
set _3:Text to vdot(SrfRetrograde:Vector,Facing:Vector)+" / "+0.9995.
wait 0.1.
}
unlock steering.
set Ship:Control:Neutralize to true.
rcs off.
set core:bootfilename to"".
wait until ship:airspeed<50.
for hs in Ship:ModulesNamed("ModuleDecouple")
{
if hs:HasEvent("jettison heat shield")
{
hs:DoEvent("jettison heat shield").
}
}
