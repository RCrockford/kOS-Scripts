@lazyglobal off.
parameter p.
parameter _0.
set Ship:Control:Fore to 1.
local _1 is Time:Seconds+p:t.
until _1<=Time:Seconds
{
set _0:Text to"Burning, Cutoff: "+round(_1-Time:Seconds,1)+" s".
CheckHeading().
RollControl().
wait 0.
}
unlock steering.
set Ship:Control:Neutralize to true.
rcs off.
LAS_Avionics("shutdown").
