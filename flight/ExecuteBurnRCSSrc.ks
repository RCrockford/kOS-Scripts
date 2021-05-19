@lazyglobal off.

parameter p.
parameter debugStat.

set Ship:Control:Fore to 1.

local stopTime is Time:Seconds + p:t.
until stopTime <= Time:Seconds
{
    set debugStat:Text to "Burning, Cutoff: " + round(stopTime - Time:Seconds, 1) + " s".
    CheckHeading().
    RollControl().
    wait 0.
}

unlock steering.
set Ship:Control:Neutralize to true.
rcs off.

LAS_Avionics("shutdown").
