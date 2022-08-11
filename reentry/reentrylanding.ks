@lazyglobal off.
wait until Ship:Unpacked.
unlock steering.
set Ship:Control:Neutralize to true.
rcs off.
local _0 is GUI(300,80).
set _0:X to 100.
set _0:Y to _0:Y+300.
local _1 is _0:AddVBox().
local _2 is _1:AddLabel("Waiting for atmospheric interface").
_0:Show().
print"Waiting for atmospheric interface".
wait until Ship:Altitude<Ship:Body:Atm:Height.
local _3 is false.
for rc in Ship:ModulesNamed("RealChuteModule")
{
if rc:HasEvent("arm parachute")
{
rc:DoEvent("arm parachute").
set _3 to true.
}
else if rc:HasEvent("deploy chute")
{
rc:DoEvent("deploy chute").
set _3 to true.
}
}
if not _3
chutes on.
print"Chutes armed.".
until Ship:Q>1e-5
{
set _2:Text to"Waiting for Q > 1: "+round(Ship:Q*Constant:AtmTokPa*1000,2)+" Pa".
wait 0.1.
}
set kUniverse:TimeWarp:Rate to 1.
for a in Ship:ModulesNamed("ModuleProceduralAvionics")
{
if a:HasEvent("activate avionics")
a:DoEvent("activate avionics").
}
rcs on.
lock steering to LookDirUp(SrfRetrograde:Vector,Facing:UpVector).
local _4 is Ship:Velocity:Surface:Mag.
local _5 is Time:Seconds.
until Ship:Velocity:Surface:Mag<1500
{
wait 0.1.
local _6 is(Ship:Velocity:Surface:Mag-_4)/(Time:Seconds-_5).
set _4 to Ship:Velocity:Surface:Mag.
set _5 to Time:Seconds.
set _2:Text to"Acceleration: "+round(_6,2)+" m/s²".
}
unlock steering.
set Ship:Control:Neutralize to true.
rcs off.
for a in Ship:ModulesNamed("ModuleProceduralAvionics")
{
if a:HasEvent("shutdown avionics")
a:DoEvent("shutdown avionics").
}
set core:bootfilename to"".
set kUniverse:TimeWarp:Mode to"Physics".
set kUniverse:TimeWarp:Rate to 1.
local _7 is false.
until Ship:Altitude-max(Ship:GeoPosition:TerrainHeight,0)<10
{
local _8 is Ship:Altitude-max(Ship:GeoPosition:TerrainHeight,0).
set _2:Text to"Landing ETA: "+round(_8/Ship:Velocity:Surface:Mag,1)+" s".
if Ship:Velocity:Surface:Mag<800
set kUniverse:TimeWarp:Rate to min(max(1,round(_8/50)),4).
if Ship:Velocity:Surface:Mag<50 and not _7
{
for hs in Ship:ModulesNamed("ModuleDecouple")
{
if hs:HasEvent("jettison heat shield")
{
hs:DoEvent("jettison heat shield").
}
}
set _7 to true.
}
wait 0.1.
}
clearGUIs().
