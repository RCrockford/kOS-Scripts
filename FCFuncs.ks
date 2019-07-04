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
local function _f0
{
parameter _p0.
return _p0:Title:Contains("Separation")or _p0:Title:Contains("Spin")or _p0:Tag:Contains("ullage").
}
global function LAS_GetStageEngines
{
parameter _p0 is Stage:Number.
parameter _p1 is false.
local _1 is list().
list engines in _1.
if Ship:Status="PreLaunch"
set _p0 to min(_p0,Stage:Number-1).
local _2 is list().
for eng in _1
{
if eng:Stage=_p0 and _f0(eng)=_p1
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
