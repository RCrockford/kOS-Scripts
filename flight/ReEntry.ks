@lazyglobal off.
parameter _0 is 80.
parameter _1 is 160.
wait until Ship:Unpacked.
if Ship:Status="Sub_Orbital"or Ship:Status="Orbiting"
{
runpathonce("FCFunctions").
if abs(Ship:Obt:Inclination)>60 and abs(Ship:Obt:Inclination)<120
{
print"Re-entry at Lat: "+_1+", target Pe: "+round(_0,1)+" km.".
local _2 is _1-360*(30/Ship:Obt:Period).
if _2<-90
set _2 to-180-_2.
if targetLongitude>90
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
wait until Ship:Longitude>_3-0.5 and Ship:Longitude<_3+0.5.
}
set _0 to _0*1000.
rcs on.
lock steering to Ship:Retrograde.
if abs(Ship:Obt:Inclination)>60 and abs(Ship:Obt:Inclination)<120
{
wait until Ship:Latitude>_1-0.25 and Ship:Latitude<_1+0.25.
}
else
{
wait until Ship:Longitude>_1-0.25 and Ship:Longitude<_1+0.25.
}
if Ship:Obt:Periapsis>_0
{
print"Commencing re-entry burn.".
runpath("flight/EngineManagement").
if EM_IgniteManoeuvreEngines()=0
{
set Ship:Control:Fore to 1.
}
wait until Ship:Obt:Periapsis<=_0.
set Ship:Control:MainThrottle to 0.
}
set Ship:Control:Neutralize to true.
rcs off.
local _4 is false.
for p in Ship:Parts
{
if p:HasModule("RealChuteModule")
{
local _5 is p:GetModule("RealChuteModule").
if _5:HasEvent("arm parachute")
{
_5:DoEvent("arm parachute").
set _4 to true.
}
}
}
if not _4
chutes on.
print"Parachutes armed.".
}
