@lazyglobal off.
wait until Ship:Unpacked.
local p is lexicon(open("1:/burn.csv"):readall:string:split(",")).
for k in p:keys
set p[k]to p[k]:ToScalar(0).
if abs(p:oLatLong)<=180
{
print"Waiting for re-entry alignment: "+round(p:oLatLong,2).
if abs(Ship:Obt:Inclination)>60 and abs(Ship:Obt:Inclination)<120
{
wait until abs(Ship:Latitude-p:oLatLong)<0.5.
}
else
{
wait until abs(Ship:Longitude-p:oLatLong)<0.5.
}
}
runoncepath("/FCFuncs").
LAS_Avionics("activate").
rcs on.
lock steering to LookDirUp(Retrograde:Vector,Facing:UpVector).
if abs(p:bLatLong)>180
{
wait until vdot(Retrograde:Vector,Facing:Vector)>0.9999 and(Ship:AngularVel:SqrMagnitude-(vdot(Ship:Facing:Vector,Ship:AngularVel)^2)<1e-4).
}
else if abs(Ship:Obt:Inclination)>60 and abs(Ship:Obt:Inclination)<120
{
wait until abs(Ship:Latitude-p:bLatLong)<0.1.
}
else
{
wait until abs(Ship:Longitude-p:bLatLong)<0.1.
}
if Ship:Obt:Periapsis>p:pe
{
print"Commencing re-entry burn.".
if p:engines>0
{
runpath("/flight/EngineMgmt",Stage:Number).
EM_Ignition().
}
local _0 is Ship:mass.
until Ship:Obt:Periapsis<=p:pe
{
wait 0.1.
if p:engines>0
{
if Ship:Thrust=0
{
set Ship:Control:Fore to 1.
set p:engines to 0.
}
}
else
{
if _0=Ship:mass
{
print"Out of fuel, aborting burn.".
break.
}
set _0 to Ship:Mass.
}
}
}
set Ship:Control:PilotMainThrottle to 0.
runpath("/reentry/ReEntryLanding").
