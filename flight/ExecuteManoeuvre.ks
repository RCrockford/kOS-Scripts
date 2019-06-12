@lazyglobal off.
parameter _0 is true.
parameter _1 is false.
wait until Ship:Unpacked.
if not Addons:Principia:HasManoeuvre
{
print"No planned manoeuvres found.".
}
else
{
runpathonce("FCFunctions").
local _2 is Addons:Principia:NextManoeuvre.
print"Executing _2 in "+round(_2:eta,1)+" seconds, deltaV: "+round(_2:deltaV:Mag,1)+" m/s, duration: "+round(_2:duration,2)+" s.".
if _0
{
print"Rotating to _2 heading".
rcs on.
lock steering to _2:deltaV:Normalized.
wait until vdot(_2:deltaV:Normalized,Ship:Facing:ForeVector)>0.999 and Ship:AngularVel<0.001
rcs off.
}
if _2:eta>65 and Addons:Available("KAC")
{
Addons:KAC:AddAlarm("Raw",_2:eta-60+Time:Seconds,Ship:Name+" Manoeuvre",Ship:Name+" is nearing its next manoeuvre").
}
wait until _2:eta<30.
print"Manoeuvre in "+round(_2:eta,1)+" seconds, RCS on.".
local _3 is 0.
local _4 is list().
if not _1
{
runpath("flight/EngineManagement").
set _3 to EM_GetIgnitionTime().
set _4 to EM_GetManoeuvreEngines().
}
rcs on.
lock steering to _2:deltaV:Normalized.
wait until _2:eta<=_3.
local _5 is 0.
if not _4:empty
{
local _6 is EM_IgniteManoeuvreEngines().
set _5 to _6/Ship:Mass.
}
else
{
set Ship:Control:Fore to 1.
local _7 is _2:deltaV:Mag.
local t is Time:seconds.
wait 0.1.
set _5 to(_7-_2:deltaV:Mag)/(Time:Seconds-t).
}
print"Starting burn.".
until _2:deltaV:Mag<_5*0.05.
{
print"dV="+_2:deltaV+", t="+round(_2:duration,2).
if _2:duration>1
wait 1.
}
set Ship:Control:MainThrottle to 0.
for eng in _4
{
eng:Shutdown().
}
set Ship:Control:Neutralize to true.
rcs off.
}
