@lazyglobal off.
parameter _0.
local _1 is 0.
local _2 is false.
local _3 is list().
runoncepath("/FCFuncs").
local _4 is LAS_GetStageEngines(_0).
for e in _4
{
if e:Ignitions<>0 or e:Ignition
{
_3:Add(e).
if e:Ullage
set _2 to true.
if not e:PressureFed
set _1 to max(_1,2.39).
else if e:Ullage
set _1 to max(_1,0.91).
}
}
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
parameter _p0 is 0.5.
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
for e in _3
e:Activate.
local t is time:seconds+3.
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
