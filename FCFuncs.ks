@lazyglobal off.
global lock LAS_ShipPos to-Ship:Body:Position.
global function LAS_EngineIsUllage
{
parameter _p0.
return _p0:Title:Contains("Separation")or _p0:Title:Contains("Spin")or _p0:Tag:Contains("ullage").
}
global function LAS_GetStageEngines
{
parameter _p0 is Stage:Number.
parameter _p1 is false.
local _0 is list().
list engines in _0.
local _1 is list().
for e in _0
{
if e:Stage=_p0 and LAS_EngineIsUllage(e)=_p1 and not e:Name:Contains("vernier")and not e:Name:Contains("lr101")
_1:Add(e).
}
return _1.
}
global function LAS_Avionics
{
parameter _p0.
local evt is _p0+" avionics".
for a in Ship:ModulesNamed("ModuleProceduralAvionics")
{
if a:HasEvent(evt)
a:DoEvent(evt).
}
for a in Ship:ModulesNamed("ModuleAvionics")
{
if a:HasEvent(evt)
a:DoEvent(evt).
}
if _p0="shutdown"
set core:bootfilename to"".
}
