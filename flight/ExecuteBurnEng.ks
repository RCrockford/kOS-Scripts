@lazyglobal off.
parameter p.
parameter _0.
set _0:Text to"Ignition".
local _1 to p:t.
if p:int=0
set _1 to(ship:Mass-ship:Mass/p:mRatio)/p:mFlow.
local _2 is 0.
local _3 is 0.
for r in Ship:Resources
{
if r:Name=p:fuelN
{
set _2 to r.
set _3 to r:Amount-p:fFlow*_1.
}
}
local _4 is _2:Amount.
EM_Ignition().
if p:int>0
{
wait until Stage:Ready.
unlock steering.
set Ship:Control:Neutralize to true.
rcs off.
stage.
}
else if p:stage<stage:number
stage.
local _5 is Time:Seconds.
until _2:Amount<=_3 or not EM_CheckThrust(0.1)
{
local _6 is Time:Seconds.
CheckHeading().
RollControl().
set _0:Text to"Burning, Fuel: "+round(_2:Amount,2)+" / "+round(_3,2)+" ["+round((_2:Amount-_3)/p:fFlow,2)+"s]".
wait 0.
if _2:Amount-(p:fFlow*(Time:Seconds-_6))<=_3
break.
}
EM_Shutdown().
