@lazyglobal off.
parameter _0.
parameter _1 is false.
parameter _2 is false.
parameter _3 is 0.
parameter _4 is 0.
parameter _5 is 0.
parameter _6 is 0.
wait until Ship:Unpacked.
if not HasNode
{
lock tVec to Ship:Prograde:Vector.
lock bVec to vcrs(tVec,ship:up:vector):Normalized.
lock nVec to vcrs(tVec,bVec):Normalized.
lock dV to _3*tVec+_4*nVec+_5*bVec.
set _6 to time:Seconds+_6.
lock burnEta to _6-time:Seconds.
}
else
{
lock dV to NextNode:DeltaV.
lock burnEta to NextNode:eta.
}
runoncepath("FCFuncs").
local _7 is _0.
local _8 is stage:Number.
local _9 is list().
local _10 is 1.
local lock _f0 to Ship:Control.
if not _1
{
if _2
set _8 to _8-1.
runpath("flight/EngineManagement",_8).
set _9 to EM_GetManoeuvreEngines().
if _9:Length=0
{
print"No active engines!".
}
else
{
local _11 is 0.
local _12 is 0.
for eng in _9
{
local _13 is eng:PossibleThrustAt(0).
set _11 to _11+_13/(Constant:g0*eng:VacuumIsp).
set _12 to _12+_13.
}
set _10 to constant:e^(dV:Mag*_11/_12).
local _14 is 0.
for shipPart in Ship:Parts
{
if shipPart:IsType("Decoupler")
{
if shipPart:Stage<_8
{
set _14 to _14+shipPart:Mass.
}
}
else if shipPart:DecoupledIn<_8
{
set _14 to _14+shipPart:Mass.
}
}
local _15 is _14/_10.
set _7 to(_14-_15)/_11.
}
}
print"Executing manoeuvre in "+round(burnEta,1)+" seconds.".
print" DeltaV: "+round(dV:Mag,1)+" m/s.".
print" Duration: "+round(_7,1)+" s.".
if _1
{
print" RCS burn.".
set _2 to false.
}
if _2
{
print" Inertial burn.".
}
if burnEta>120 and Addons:Available("KAC")
{
AddAlarm("Raw",burnEta-90+Time:Seconds,Ship:Name+" Manoeuvre",Ship:Name+" is nearing its next manoeuvre").
}
print"Waiting for manoeuvre".
wait until burnEta<60.
print"Aligning ship.".
local _16 is 0.
if not _1
{
set _16 to EM_GetIgnitionDelay().
}
rcs on.
lock steering to dV:Normalized.
if _2
{
set _f0:Roll to-1.
until burnEta<=_16
{
local _17 is vdot(Ship:Facing:Vector,Ship:AngularVel).
if abs(_17)>_0*1.25
{
set _f0:Roll to 0.1.
}
else if abs(_17)>_0 and abs(_17)<_0*1.2
{
set _f0:Roll to-0.1.
}
wait 0.
}
set _f0:Roll to-0.1.
}
else
{
wait until burnEta<=_16.
}
if not _9:empty
{
EM_IgniteManoeuvreEngines().
print"Starting engine burn.".
if _2 and Stage:Ready
{
unlock steering.
set _f0:Neutralize to true.
rcs off.
stage.
}
}
else
{
print"Starting RCS burn.".
set _f0:Fore to 1.
}
if _1
{
wait _7.
}
else
{
local _18 is ship:Mass/_10.
wait until Ship:Mass<=_18.
}
set shipCtrlMainThrottle to 0.
for eng in _9
{
eng:Shutdown().
}
if not _9:empty
print"MECO".
unlock steering.
set _f0:Neutralize to true.
rcs off.
