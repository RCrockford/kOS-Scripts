@lazyglobal off.
parameter p.
parameter _0.
parameter dV.
_0:ClearAll().
local _1 is lexicon().
_1:Add("stat",_0:AddReadout("Status")).
_1:Add("m",_0:AddReadout("Mass")).
_1:Add("t",_0:AddReadout("Time")).
RGUI_SetText(_1:stat,"Ignition").
local _2 is constant:e^(dV:Mag*p:mFlow/p:thr).
local _3 is Ship:Mass.
EM_Ignition().
local _4 is Ship:Mass.
local _5 is 0.
if p:HasKey("spin")
{
wait until Stage:Ready.
unlock steering.
set Ship:Control:Neutralize to true.
rcs off.
stage.
set _3 to _3-(_4-Ship:Mass).
set _5 to(Velocity:Orbit+dV):Mag.
}
else if p:stage<stage:number
{
stage.
set _3 to _3-(_4-Ship:Mass).
}
if EM_GetEngines()[0]:HasGimbal
rcs off.
local _6 is Time:Seconds.
local _7 is _3/_2.
local _8 is Ship:Mass-_7.
until not EM_CheckThrust(0.1)
{
local _9 is Velocity:Orbit.
CheckHeading().
RollControl().
RGUI_SetText(_1:m,round(Ship:Mass*1000,1)+" / "+round(_7*1000,1)).
RGUI_SetText(_1:t,round(_8/p:mFlow,2)+"s").
wait 0.
set _8 to Ship:Mass-_7.
local _10 is(Velocity:Orbit-_9):Mag.
if(_8<=0)and(Velocity:Orbit:Mag+_10>=_5)
break.
}
if not EM_CheckThrust(0.1)
print"Fuel exhaustion".
EM_Shutdown().
