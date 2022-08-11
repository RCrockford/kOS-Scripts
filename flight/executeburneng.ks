@lazyglobal off.
parameter p.
parameter _0.
parameter dV.
set _0:Text to"Ignition".
local _1 is constant:e^(dV:Mag*p:mFlow/p:thr).
local _2 is Ship:Mass.
EM_Ignition().
local _3 is Ship:Mass.
local _4 is 0.
if p:HasKey("spin")
{
wait until Stage:Ready.
unlock steering.
set Ship:Control:Neutralize to true.
rcs off.
stage.
set _2 to _2-(_3-Ship:Mass).
set _4 to(Velocity:Orbit+dV):Mag.
}
else if p:stage<stage:number
{
stage.
set _2 to _2-(_3-Ship:Mass).
}
if EM_GetEngines()[0]:HasGimbal
rcs off.
local _5 is Time:Seconds.
local _6 is _2/_1.
local _7 is Ship:Mass-_6.
until not EM_CheckThrust(0.1)
{
local _8 is Velocity:Orbit.
CheckHeading().
RollControl().
set _0:Text to"Burning, Mass: "+round(Ship:Mass*1000,1)+" / "+round(_6*1000,1)+" ["+round(_7/p:mFlow,2)+"s]".
wait 0.
set _7 to Ship:Mass-_6.
local _9 is(Velocity:Orbit-_8):Mag.
if(_7<=0)and(Velocity:Orbit:Mag+_9>=_4)
break.
}
if not EM_CheckThrust(0.1)
print"Fuel exhaustion".
EM_Shutdown().
