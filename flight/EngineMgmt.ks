@lazyglobal off.
parameter _0.
local _1 is 0.
local _2 is list().
runoncepath("/FCFuncs").
local _3 is LAS_GetStageEngines(_0).
for e in _3
{
if e:Ignitions<>0
{
_2:Add(e).
if e:Ullage
{
if e:PressureFed
set _1 to max(_1,1).
else
set _1 to max(_1,3).
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
global function EM_Ignition
{
if not _2:empty
{
rcs on.
set Ship:Control:Fore to 1.
for e in _2
wait until e:FuelStability>=0.99.
set Ship:Control:PilotMainThrottle to 1.
for e in _2
e:Activate.
wait 0.
set Ship:Control:Fore to 0.
}
return not _2:empty.
}
