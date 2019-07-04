@lazyglobal off.
parameter _0 is 80.
parameter _1 is 200.
wait until Ship:Unpacked.
if Ship:Status="Sub_Orbital"or Ship:Status="Orbiting"
{
runoncepath("FCFuncs").
if abs(_1)>180
{
print"Re-entry immediately, target Pe: "+round(_0,1)+" km.".
}
else if abs(Ship:Obt:Inclination)>60 and abs(Ship:Obt:Inclination)<120
{
print"Re-entry at Lat: "+_1+", target Pe: "+round(_0,1)+" km.".
local _2 is _1-360*(30/Ship:Obt:Period).
if _2<-90
set _2 to-180-_2.
if _2>90
set _2 to 180-_2.
wait until Ship:Latitude>_2-0.5 and Ship:Latitude<_2+0.5.
}
else
{
print"Re-entry at Long: "+_1+", target Pe: "+round(_0,1)+" km.".
local _3 is _1-360*(30/Ship:Obt:Period).
if _3<-180
set _3 to _3+360.
if _3>180
set _3 to _3-360.
print"Orient at Long: "+_3.
wait until Ship:Longitude>_3-0.5 and Ship:Longitude<_3+0.5.
}
set _0 to _0*1000.
rcs on.
lock steering to Ship:Retrograde.
if abs(_1)>180
{
wait until abs(SteeringManager:AngleError)<0.2 and(Ship:AngularVel:SqrMagnitude-(vdot(Ship:Facing:Vector,Ship:AngularVel)^2)<1e-4).
}
else if abs(Ship:Obt:Inclination)>60 and abs(Ship:Obt:Inclination)<120
{
wait until Ship:Latitude>_1-0.1 and Ship:Latitude<_1+0.1.
}
else
{
wait until Ship:Longitude>_1-0.1 and Ship:Longitude<_1+0.1.
}
if Ship:Obt:Periapsis>_0
{
print"Commencing re-entry burn.".
runpath("flight/EngineManagement",Stage:Number).
local _4 is false.
if not EM_IgniteManoeuvreEngines()
{
set Ship:Control:Fore to 1.
set _4 to true.
}
local _5 is Ship:mass.
until Ship:Obt:Periapsis<=_0
{
wait 0.1.
if _5=Ship:mass
{
print"Out of fuel, aborting burn.".
break.
}
set _5 to Ship:Mass.
}
set Ship:Control:Fore to 0.
set Ship:Control:MainThrottle to 0.
}
set Ship:Control:Neutralize to true.
rcs off.
local _6 is false.
for p in Ship:Parts
{
if p:HasModule("RealChuteModule")
{
local _7 is p:GetModule("RealChuteModule").
if _7:HasEvent("arm parachute")
{
_7:DoEvent("arm parachute").
set _6 to true.
}
}
}
if not _6
chutes on.
print"Parachutes armed.".
}
