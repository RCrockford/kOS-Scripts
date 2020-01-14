@lazyglobal off.
wait until Ship:Unpacked.
local p is readjson("1:/burn.json").
print"Align in "+round(p:eta-60,1)+" seconds.".
wait until p:eta<60.
print"Aligning ship".
local _0 is 0.
local _1 is list().
if p:eng
{
runpath("/flight/EngineMgmt",p:stage).
set _1 to EM_GetEngines().
set _0 to EM_IgDelay().
}
LAS_Avionics("activate").
rcs on.
lock steering to p:dV:Normalized.
if p:inertial
{
set Ship:Control:Roll to-1.
until p:eta<=_0
{
local _2 is vdot(Ship:Facing:Vector,Ship:AngularVel).
if abs(_2)>p:spin*1.25
{
set Ship:Control:Roll to 0.1.
}
else if abs(_2)>p:spin and abs(_2)<p:spin*1.2
{
set Ship:Control:Roll to-0.1.
}
wait 0.
}
set Ship:Control:Roll to-0.1.
}
else
{
wait until p:eta<=_0.
}
print"Starting burn".
if not _1:empty
{
local _3 is 0.
local _4 is 0.
for r in Ship:Resources
{
if r:Name=p:fuelN
{
set _3 to r.
set _4 to r:Amount-p:fuelA.
}
}
EM_Ignition().
if p:inertial
{
wait until Stage:Ready.
unlock steering.
set Ship:Control:Neutralize to true.
rcs off.
stage.
}
wait until _3:Amount<=_4.
}
else
{
set Ship:Control:Fore to 1.
wait p:t.
}
set Ship:Control:PilotMainThrottle to 0.
for eng in _1
{
eng:Shutdown.
}
if not _1:empty
print"MECO".
unlock steering.
set Ship:Control:Neutralize to true.
rcs off.
LAS_Avionics("shutdown").
