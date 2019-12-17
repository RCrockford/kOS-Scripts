@lazyglobal off.
parameter _0.
parameter _1.
parameter _2 is 90.
wait until Ship:Unpacked.
runpathonce("../launch/LASFunctions").
if Ship:Status="Landed"or Ship:Status="Splashed"
{
print"Lifting off".
ladders off.
lock Steering to Heading(_2,90).
set Ship:Control:MainThrottle to 1.
local _3 is LAS_GetStageEngines().
for eng in _3
{
if not eng:Ignition
LAS_IgniteEngine(eng).
}
wait until Alt:Radar>100 or Ship:VerticalSpeed>20.
}
if Ship:Status="Flying"or Ship:Status="Sub_Orbital"
{
legs off.
if defined LAS_TargetPe
set LAS_TargetPe to _1.
else
global LAS_TargetPe is _1.
if defined LAS_TargetAp
set LAS_TargetAp to _0.
else
global LAS_TargetAp is _0.
runpath("../launch/OrbitalGuidance").
if Ship:Body:Atm:Exists
{
set pitchOverSpeed to LAS_GetPartParam(Ship:RootPart,"spd=",100).
set pitchOverAngle to LAS_GetPartParam(Ship:RootPart,"ang=",4).
runpath("../launch/FlightControlPitchOver",pitchOverSpeed,pitchOverAngle,_2).
}
else
{
runpath("../launch/FlightControlNoAtm",_2).
}
}
