@lazyglobal off.
parameter _0.
local _1 is 0.
local _2 is false.
local _3 is list().
runoncepath("/fcfuncs").
global function EM_CalcSpoolTime
{
parameter _p0.
if _p0:HasModule("ModuleEnginesRF")
{
local _4 is _p0:GetModule("ModuleEnginesRF").
return _4:Getfield("effective spool-up time").
}
return 0.1.
}
global function EM_ResetEngines
{
parameter _p0.
set _0 to _p0.
local _5 is LAS_GetStageEngines(_0).
set _2 to false.
set _1 to 0.
_3:Clear().
for e in _5
{
if e:Ignitions<>0 or e:Ignition
{
_3:Add(e).
if e:Ullage
set _2 to true.
if e:Ullage or not e:PressureFed
set _1 to EM_CalcSpoolTime(e).
}
}
}
EM_ResetEngines(_0).
global function EM_IgDelay
{
return _1.
}
global function EM_GetEngines
{
return _3.
}
global function EM_CheckThrust
{
parameter p.
return _3[0]:Thrust>_3[0]:PossibleThrust*p.
}
global function EM_Ignition
{
parameter _p0 is 0.25.
if not _3:empty
{
for e in _3
e:Shutdown.
if _2
{
rcs on.
set Ship:Control:Fore to 1.
}
set Ship:Control:PilotMainThrottle to 1.
for e in _3
wait until e:FuelStability>=0.99.
local t is time:seconds+0.2.
for e in _3
{
e:Activate.
set t to max(t,time:seconds+EM_CalcSpoolTime(e)*2).
}
wait until EM_CheckThrust(_p0)or _3[0]:Flameout or time:seconds>t.
set Ship:Control:Fore to 0.
}
return not _3:empty.
}
global function EM_Shutdown
{
for e in _3
e:Shutdown.
if not _3:empty
print"MECO".
unlock steering.
set Ship:Control:Neutralize to true.
set Ship:Control:PilotMainThrottle to 0.
rcs off.
LAS_Avionics("shutdown").
}
