@lazyglobal off.
global lock LAS_ShipPos to-Ship:Body:Position.
global function LAS_EngineIsSolidFuel
{
parameter _p0.
return not _p0:AllowShutdown.
}
global function LAS_EngineIsPressureFed
{
parameter _p0.
if _p0:HasModule("ModuleEnginesRF")
{
local _0 is _p0:GetModule("ModuleEnginesRF").
if _0:HasField("pressurefed")
return _0:GetField("pressurefed").
if _p0:HasModule("ModuleTagEngineLiquidPF")
return true.
}
return false.
}
global function LAS_GetStageEngines
{
parameter _p0 is Stage:Number.
local _1 is list().
list engines in _1.
if Ship:Status="PreLaunch"
set _p0 to _p0-1.
local _2 is list().
for eng in _1
{
if eng:Stage=_p0
{
_2:Add(eng).
}
}
return _2.
}
global function LAS_GetFuelStability
{
parameter _p0.
local _3 is"(99%)".
for eng in _p0
{
if not LAS_EngineIsSolidFuel(eng)and eng:HasModule("ModuleEnginesRF")
{
local _4 is eng:GetModule("ModuleEnginesRF").
if _4:HasField("propellant")
{
set _3 to _4:GetField("propellant").
break.
}
}
}
if _3:Contains("(")
{
local f is _3:Find("(")+1.
set _3 to _3:Substring(f,_3:Length-f):Split("%")[0]:ToNumber(-1).
}
else
{
set _3 to 0.
}
return _3.
}
