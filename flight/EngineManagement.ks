@lazyglobal off.
parameter _0.
local _1 is 0.
local _2 is list().
local _3 is LAS_GetStageEngines(_0).
for eng in _3
{
if not eng:HasModule("ModuleEnginesRF")or eng:GetModule("ModuleEnginesRF"):GetField("ignitions remaining")>0
{
_2:Add(eng).
}
}
for eng in _2
{
if not LAS_EngineIsSolidFuel(eng)
{
if LAS_EngineIsPressureFed(eng)
set _1 to max(_1,1).
else
set _1 to max(_1,3).
}
}
global function EM_GetIgnitionDelay
{
return _1.
}
global function EM_GetManoeuvreEngines
{
return _2.
}
global function EM_IgniteManoeuvreEngines
{
if not _2:empty
{
rcs on.
set Ship:Control:Fore to 1.
print"Manoeuvre engine ullage".
wait until LAS_GetFuelStability(_2)>=99.
set Ship:Control:MainThrottle to 1.
for eng in _2
{
eng:Activate().
}
wait 0.
set Ship:Control:Fore to 0.
}
return not _2:empty.
}
