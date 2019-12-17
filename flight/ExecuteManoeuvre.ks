@lazyglobal off.
parameter _0.
parameter _1 is false.
parameter _2 is false.
parameter _3 is 0.
parameter _4 is 0.
parameter _5 is 0.
parameter _6 is 0.
parameter _7 is 0.
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
local _8 is _0.
local _9 is stage:Number.
local _10 is list().
local _11 is 1.
if not _1
{
if _2
set _9 to _9-1.
runpath("flight/EngineManagement",_9).
set _10 to EM_GetManoeuvreEngines().
if _10:Length=0
{
print"No active engines!".
}
else
{
local _12 is 0.
local _13 is 0.
for eng in _10
{
local _14 is eng:PossibleThrustAt(0).
set _12 to _12+_14/(Constant:g0*eng:VacuumIsp).
set _13 to _13+_14.
}
set _11 to constant:e^(dV:Mag*_12/_13).
local _15 is 0.
for shipPart in Ship:Parts
{
if shipPart:IsType("Decoupler")
{
if shipPart:Stage<_9
{
set _15 to _15+shipPart:Mass.
}
}
else if shipPart:DecoupledIn<_9
{
set _15 to _15+shipPart:Mass.
}
}
local _16 is _15/_11.
set _8 to(_15-_16)/_12.
}
}
print"Executing manoeuvre in "+round(burnEta,1)+" seconds.".
print" DeltaV: "+round(dV:Mag,1)+" m/s.".
print" Duration: "+round(_8,1)+" s.".
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
local _17 is 0.
if not _1
{
set _17 to EM_GetIgnitionDelay().
}
rcs on.
lock steering to dV:Normalized.
if _2
{
set Ship:Control:Roll to-1.
until burnEta<=_17
{
local _18 is vdot(Ship:Facing:Vector,Ship:AngularVel).
if abs(_18)>_0*1.25
{
set Ship:Control:Roll to 0.1.
}
else if abs(_18)>_0 and abs(_18)<_0*1.2
{
set Ship:Control:Roll to-0.1.
}
wait 0.
}
set Ship:Control:Roll to-0.1.
}
else
{
wait until burnEta<=_17.
}
if not _10:empty
{
EM_IgniteManoeuvreEngines().
print"Starting engine burn.".
if _2 and Stage:Ready
{
unlock steering.
set Ship:Control:Neutralize to true.
rcs off.
stage.
}
}
else
{
print"Starting RCS burn.".
set Ship:Control:Fore to 1.
}
if _1
{
wait _8.
}
else
{
local _19 is ship:Mass/_11.
wait until Ship:Mass<=_19 and Ship:Orbit:Apoapsis>=_7.
}
set Ship:Control:PilotMainThrottle to 0.
for eng in _10
{
eng:Shutdown().
}
if not _10:empty
print"MECO".
unlock steering.
set Ship:Control:Neutralize to true.
rcs off.
