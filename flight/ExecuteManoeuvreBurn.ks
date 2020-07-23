@lazyglobal off.
wait until Ship:Unpacked.
local p is readjson("1:/burn.json").
local lock _f0 to Prograde:Vector.
local lock _f1 to vcrs(_f0,up:vector):Normalized.
local lock _f2 to vcrs(_f0,_f1):Normalized.
local dV is v(0,0,0).
if HasNode
{
lock burnETA to NextNode:eta.
set dV to NextNode:deltaV.
}
else
{
lock burnETA to p:eta-Time:Seconds.
set dV to _f0*p:dV:x+_f2*pDv:y+_f1*p:dV:z.
}
print"Align in "+round(burnETA-60,0)+" seconds.".
wait until burnETA<60.
kUniverse:Timewarp:CancelWarp().
print"Aligning ship".
runoncepath("/FCFuncs").
runpath("flight/TuneSteering").
local _0 is 0.
if p:eng
{
runpath("/flight/EngineMgmt",p:stage).
set _0 to EM_IgDelay().
}
local function _f3
{
if HasNode and nextNode:eta<60
set dV to NextNode:deltaV.
else if p:haskey("dV")
set dV to _f0*p:dV:x+_f2*pDv:y+_f1*p:dV:z.
}
LAS_Avionics("activate").
_f3().
rcs on.
lock steering to LookDirUp(dV:Normalized,Facing:UpVector).
if p:inertial
{
until burnETA<=_0
{
if vdot(dV:Normalized,Facing:Vector)>0.99
{
local _1 is vdot(Facing:Vector,Ship:AngularVel).
if abs(_1)>p:spin*1.25
{
set Ship:Control:Roll to 0.1.
}
else if abs(_1)>p:spin and abs(_1)<p:spin*1.2
{
set Ship:Control:Roll to-0.1.
}
else
{
set Ship:Control:Roll to-1.
}
}
_f3().
wait 0.
}
set Ship:Control:Roll to-0.1.
}
else
{
wait until burnETA<=_0+5.
_f3().
wait until burnETA<=_0.
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
until _2:Amount<=_3 or not EM_CheckThrust(0.1)
{
_f3().
wait 0.
}
EM_Shutdown().
}
else
{
set Ship:Control:Fore to 1.
local _4 is Time:Seconds+p:t.
until _4<=Time:Seconds
{
_f3().
wait 0.
}
unlock steering.
set Ship:Control:Neutralize to true.
rcs off.
LAS_Avionics("shutdown").
}
