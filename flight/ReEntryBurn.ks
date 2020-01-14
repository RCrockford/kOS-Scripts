@lazyglobal off.
wait until Ship:Unpacked.
local p is readjson("1:/burn.json").
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
lock steering to Ship:Retrograde.
if abs(p:bLatLong)>180
{
wait until abs(SteeringManager:AngleError)<0.2 and(Ship:AngularVel:SqrMagnitude-(vdot(Ship:Facing:Vector,Ship:AngularVel)^2)<1e-4).
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
if p:engines
{
runpath("/flight/EngineMgmt",Stage:Number).
if not EM_Ignition()
{
set p:engines to false.
}
}
if not p:engines
set Ship:Control:Fore to 1.
local _0 is Ship:mass.
until Ship:Obt:Periapsis<=p:pe
{
wait 0.1.
if _0=Ship:mass
{
if p:engines
{
set Ship:Control:Fore to 1.
set p:engines to false.
}
else
{
print"Out of fuel, aborting burn.".
break.
}
}
set _0 to Ship:Mass.
}
}
unlock steering.
set Ship:Control:Neutralize to true.
rcs off.
wait until Ship:Altitude<Ship:Body:Atm:Height.
local _1 is false.
for rc in Ship:ModulesNamed("RealChuteModule")
{
if rc:HasEvent("arm parachute")
{
rc:DoEvent("arm parachute").
set _1 to true.
}
}
if not _1
chutes on.
print"Parachutes armed.".
wait until Ship:Q>1e-5.
rcs on.
lock steering to Ship:SrfRetrograde.
wait until Ship:Q>1e-3.
unlock steering.
set Ship:Control:Neutralize to true.
rcs off.
set core:bootfilename to"".
