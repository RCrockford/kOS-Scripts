@lazyglobal off.
wait until Ship:Unpacked.
runpathonce(".../FCFuncs").
local _0 is LAS_GetStageEngines().
local _1 is false.
local function _f0
{
parameter f.
local _2 is 0.
for eng in _0
{
if _1
set _2 to _2+eng:Thrust/Ship:Control:PilotMainThrottle.
else
set _2 to _2+eng:PossibleThrust.
}
local _3 is V(0,_2/Ship:Mass,0).
set _3.x to _3.y*vdot(f,LAS_ShipPos():Normalized).
set _3.z to sqrt(max(_3.y*_3.y-_3.x*_3.x,1e-4)).
return _3.
}
if Ship:Status="Flying"or Ship:Status="Sub_Orbital"
{
print"Lander descent system online.".
local rT is 50.
local vT is-3.
local f is Ship:Facing:ForeVector.
local _4 is false.
until Ship:GroundSpeed<20
{
local _5 is _f0(f).
local t is-Ship:GroundSpeed/_5.z.
local _6 is 12*(rT-Alt:Radar)/(t*t)+6*(vT+Ship:VerticalSpeed)/t.
local fr is(_6+Ship:Body:Mu/LAS_ShipPos():SqrMagnitude)/_5.y.
set fr to min(max(fr,0),0.999).
set f to fr*LAS_ShipPos():Normalized+sqrt(1-fr*fr)*vxcl(Ship:SrfRetrograde:ForeVector,LAS_ShipPos():Normalized).
if not _4
{
if fr>0.3
{
print"Approach mode active".
set _4 to true.
lock steering to f.
}
}
else
{
if not _1 and vdot(f,Ship:Facing:ForeVector)>0.998
{
set Ship:Control:PilotMainThrottle to 1.
for eng in _0
{
eng:Activate.
}
set _1 to true.
}
}
wait 0.1.
}
print"Descent mode active".
set vT to 1.
legs on.
until Ship:Status="Landed"or Ship:Status="Splashed"
{
local _7 is _f0(f).
local _8 is Ship:Body:Mu/LAS_ShipPos():SqrMagnitude.
local _9 is-_8*0.3.
local t is(-Ship:VerticalSpeed-SQRT(Ship:VerticalSpeed*Ship:VerticalSpeed-4*Alt:Radar*_9))/(2*_9).
local _10 is(-((Alt:Radar^1.25)*0.01+vT)-Ship:VerticalSpeed)/t.
if Ship:GroundSpeed>abs(Ship:VerticalSpeed)*0.1
{
local _11 is Ship:GroundSpeed/MAX(t-2,0.1).
local fr is(_10+_8)/_7.y.
set fr to min(max(fr,0),0.999).
local acg is fr*LAS_ShipPos():Normalized+min(sqrt(1-fr*fr),_11)*vxcl(Ship:SrfRetrograde:ForeVector,LAS_ShipPos():Normalized).
set Ship:Control:PilotMainThrottle to acg:Mag.
set f to acg:Normalized.
}
else
{
set f to Ship:SrfRetrograde:ForeVector.
set Ship:Control:PilotMainThrottle to(_10+_8)/_7.y.
}
}
set Ship:Control:PilotMainThrottle to 0.
for eng in _0
{
eng:Shutdown.
}
local _12 is 1.
until Ship:Velocity:Surface:SqrMagnitude<0.01 and Ship:AngularVel<0.01
{
if vdot(Ship:Facing:ForeVector,LAS_ShipPos():Normalized)<0.8 or Ship:AngularVel>_12
{
lock steering to LAS_ShipPos():Normalized.
set _12 to 0.8.
}
else
{
set Ship:Control:Neutralize to true.
set _12 to 1.
}
wait 0.1.
}
set Ship:Control:Neutralize to true.
ladders on.
print"Landing completed".
}
