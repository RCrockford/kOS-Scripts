@lazyglobal off.
local _0 is 0.
local _1 is list().
set stageEngines to LAS_GetStageEngines().
for eng in stageEngines
{
if not eng:Title:Contains("Separation")and not eng:Tag:Contains("ullage")
{
if not eng:HasModule("ModuleEnginesRF")or eng:GetModule("ModuleEnginesRF"):GetField("ignitions remaining"):ToNumber(0)>0
{
_1:Add(eng).
}
}
}
for eng in _1
{
if not LAS_EngineIsSolidFuel(eng)
{
if LAS_EngineIsPressureFed(eng)
set _0 to max(_0,1).
else
set _0 to max(_0,3).
}
}
global function EM_GetIgnitionDelay
{
return _0.
}
global function EM_GetManoeuvreEngines
{
return _1.
}
global function EM_IgniteManoeuvreEngines
{
local _2 is 0.
if not _1:empty
{
print"Performing ullage for main engines".
rcs on.
set Ship:Control:Fore to 1.
local _3 is"Unstable".
wait until LAS_GetFuelStability(_1)>=99.
set Ship:Control:MainThrottle to 1.
for eng in _1
{
eng:Activate().
set _2 to _2+eng:PossibleThrust.
}
wait 0.
set Ship:Control:Fore to 0.
}
return _2.
}
