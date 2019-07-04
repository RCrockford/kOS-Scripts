@lazyglobal off.
runoncepath("/FCFuncs").
global function LAS_GetStageParts
{
parameter _p0 is Stage:Number.
parameter _p1 is"".
local _0 is Ship:Parts.
local _1 is list().
for p in _0
{
if p:Stage=_p0
{
if _p1:Length=0 or p:HasModule(_p1)
{
_1:Add(p).
}
}
}
return _1.
}
global function LAS_GetPartParam
{
parameter _p0.
parameter _p1.
parameter _p2 is 0.
local _2 is _p2.
if _p0:Tag:Contains(_p1)
{
local f is _p0:Tag:Find(_p1)+_p1:Length.
set _2 to _p0:Tag:Substring(f,_p0:Tag:Length-f):Split(" ")[0]:ToNumber(_p2).
}
return _2.
}
local _3 is lexicon().
local _4 is lexicon().
{
local _5 is list().
list engines in _5.
for eng in _5
{
local _6 is LAS_GetPartParam(eng,"t=",-1).
set _3[eng]to _6.
set _4[eng]to-1.
}
}
global function LAS_GetEngineBurnTime
{
parameter _p0.
if _3:HasKey(_p0)and _3[_p0]>0
{
if _4[_p0]>=0
return max(_3[_p0]-(MissionTime-_4[_p0]),0).
else
return _3[_p0].
}
return-1.
}
global function LAS_IgniteEngine
{
parameter _p0.
set _4[_p0]to MissionTime.
_p0:Activate().
}
global function LAS_GetStageBurnTime
{
parameter _p0 is list().
if _p0:empty()
set _p0 to LAS_GetStageEngines().
local _7 is 0.
local _8 is 0.
for eng in _p0
{
local _9 is LAS_GetEngineBurnTime(eng).
if _9>=0
set _8 to max(_9,_8).
else
set _8 to 100000.
set _7 to _7+eng:FuelFlow.
}
if _7=0
return 0.
local _10 is Stage:ResourcesLex.
local _11 is 0.
for res in _10:Values
{
if res:Amount>0 and res:Amount<res:Capacity
{
set _11 to _11+res:Amount*res:Density*1000.
}
}
return min(_8,_11/_7).
}
global function LAS_FormatTime
{
parameter t.
local fmt is"".
if t>(30*3600)
set fmt to round(t/(24*3600),1):ToString()+" days.".
else if t>(90*60)
set fmt to round(t/3600,1):ToString()+" hours.".
else if t>90
set fmt to round(t/60,1):ToString()+" minutes.".
else
set fmt to round(t,0):ToString()+" seconds.".
return fmt.
}
