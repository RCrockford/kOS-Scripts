@lazyglobal off.
parameter p.
parameter _0.
_0:ClearAll().
local _1 is lexicon().
_1:Add("stat",_0:AddReadout("Status")).
_1:Add("t",_0:AddReadout("Time")).
RGUI_SetText(_1:stat,"Thrusting").
set Ship:Control:Fore to 1.
local _2 is Time:Seconds+p:t.
until _2<=Time:Seconds
{
RGUI_SetText(_1:t,round(_2-Time:Seconds,1)+"s").
CheckHeading().
RollControl().
wait 0.
}
unlock steering.
set Ship:Control:Neutralize to true.
rcs off.
LAS_Avionics("shutdown").
