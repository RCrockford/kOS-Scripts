@lazyglobal off.

parameter p.
parameter debugStat.

set debugStat:Text to "Ignition".

local duration to p:t.
if p:int = 0
    set duration to (ship:Mass - ship:Mass / p:mRatio) / p:mFlow.

local fuelRes is 0.
local fuelTarget is 0.
for r in Ship:Resources
{
    if r:Name = p:fuelN
    {
        set fuelRes to r.
        // Wait until we have burned the right amount of fuel.
        set fuelTarget to r:Amount -  p:fFlow * duration.
    }
}
local fuelStart is fuelRes:Amount.

EM_Ignition().

// If this is a spun kick stage, then decouple it.
if p:int > 0
{
    wait until Stage:Ready.
    unlock steering.
    set Ship:Control:Neutralize to true.
    rcs off.
    stage.
}
else if p:stage < stage:number
    stage.

local burnStart is Time:Seconds.

until fuelRes:Amount <= fuelTarget or not EM_CheckThrust(0.1)
{
    local prevUpdate is Time:Seconds.
    CheckHeading().
    RollControl().
    set debugStat:Text to "Burning, Fuel: " + round(fuelRes:Amount, 2) + " / " + round(fuelTarget, 2) + " [" + round((fuelRes:Amount - fuelTarget) / p:fFlow, 2) + "s]".
    wait 0.
    // Break if we'll hit the target fuel in one update.
    if fuelRes:Amount - (p:fFlow * (Time:Seconds - prevUpdate)) <= fuelTarget
        break.
}

EM_Shutdown().
