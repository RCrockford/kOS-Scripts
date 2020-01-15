@lazyglobal off.
wait until Ship:Unpacked.
local p is readjson("1:/burn.json").
local lock _f0 to burnETA-Time:Seconds.
print"Align in "+round(_f0-60,0)+" seconds.".
wait until _f0<60.
print"Aligning ship".
local _0 is 0.
if p:eng
{
runpath("/flight/EngineMgmt",p:stage).
set _0 to EM_IgDelay().
}
LAS_Avionics("activate").
rcs on.
lock steering to LookDirUp(p:dV:Normalized,Facing:UpVector).
if p:inertial
{
set Ship:Control:Roll to-1.
until _f0<=_0
{
local _1 is vdot(Ship:Facing:Vector,Ship:AngularVel).
if abs(_1)>p:spin*1.25
{
set Ship:Control:Roll to 0.1.
}
else if abs(_1)>p:spin and abs(_1)<p:spin*1.2
{
set Ship:Control:Roll to-0.1.
}
wait 0.
}
set Ship:Control:Roll to-0.1.
}
else
{
wait until _f0<=_0.
}
print"Starting burn".
if p:eng
{
local _2 is 0.
local _3 is 0.
for r in Ship:Resources
{
if r:Name=p:fuelN
{
set _2 to r.
set _3 to r:Amount-p:fuelA.
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
wait until _2:Amount<=_3 or not EM_CheckThrust(0.1).
}
else
{
set Ship:Control:Fore to 1.
wait p:t.
}
EM_Shutdown().
