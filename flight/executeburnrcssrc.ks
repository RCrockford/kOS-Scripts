@lazyglobal off.

parameter p.
parameter readoutGui.

readoutGui:ClearAll().
local Readouts is lexicon().

Readouts:Add("stat", readoutGui:AddReadout("Status")).
Readouts:Add("t", readoutGui:AddReadout("Time")).

RGUI_SetText(Readouts:stat, "Thrusting").

set Ship:Control:Fore to 1.

local stopTime is Time:Seconds + p:t.
until stopTime <= Time:Seconds
{
    RGUI_SetText(Readouts:t, round(stopTime - Time:Seconds, 1) + "s").
    CheckHeading().
    RollControl().
    wait 0.
}

unlock steering.
set Ship:Control:Neutralize to true.
rcs off.

LAS_Avionics("shutdown").
