@lazyglobal off.
parameter _0.
local _1 is 0.
local _2 is list().
runoncepath("/FCFuncs").
local _3 is LAS_GetStageEngines(_0).
for e in _3
{
if e:Ignitions<>0 or e:Ignition
{
_2:Add(e).
if e:Ullage
{
if e:PressureFed
set _1 to max(_1,0.91).
else
set _1 to max(_1,2.39).
}
}
}
global function EM_IgDelay
{
return _1.
}
global function EM_GetEngines
{
return _2.
}
global function EM_CheckThrust
{
parameter p.
return _2[0]:Thrust>_2[0]:PossibleThrust*p.
}
global function EM_Ignition
{
if not _2:empty
{
for e in _2
e:Shutdown.
rcs on.
set Ship:Control:Fore to 1.
set Ship:Control:PilotMainThrottle to 1.
for e in _2
wait until e:FuelStability>=0.99.
for e in _2
e:Activate.
local t is time:seconds+3.
wait until EM_CheckThrust(0.5)or _2[0]:Flameout or time:seconds>t.
set Ship:Control:Fore to 0.
}
return not _2:empty.
}
global function EM_Shutdown
{
for e in _2
e:Shutdown.
if not _2:empty
print"MECO".
unlock steering.
set Ship:Control:Neutralize to true.
set Ship:Control:PilotMainThrottle to 0.
rcs off.
LAS_Avionics("shutdown").
}
