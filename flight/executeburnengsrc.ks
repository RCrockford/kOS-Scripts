@lazyglobal off.

parameter p.
parameter debugStat.
parameter dV.

set debugStat:Text to "Ignition".

local massRatio is constant:e ^ (dV:Mag * p:mFlow / p:thr).
local startMass is Ship:Mass.

EM_Ignition().

local preStageMass is Ship:Mass.
local minVel is 0.

// If this is a spun kick stage, then decouple it.
if p:HasKey("spin")
{
    wait until Stage:Ready.
    unlock steering.
    set Ship:Control:Neutralize to true.
    rcs off.
    stage.
    set startMass to startMass - (preStageMass - Ship:Mass).
    set minVel to (Velocity:Orbit + dV):Mag.
}
else if p:stage < stage:number
{
    stage.
    set startMass to startMass - (preStageMass - Ship:Mass).
}

if EM_GetEngines()[0]:HasGimbal
    rcs off.

local burnStart is Time:Seconds.
local finalMass is startMass / massRatio.
local burnMass is Ship:Mass - finalMass.

until not EM_CheckThrust(0.1)
{
    local prevVel is Velocity:Orbit.
    CheckHeading().
    RollControl().
    set debugStat:Text to "Burning, Mass: " + round(Ship:Mass * 1000, 1) + " / " + round(finalMass * 1000, 1) + " [" + round(burnMass / p:mFlow, 2) + "s]".
    wait 0.
    set burnMass to Ship:Mass - finalMass.
    local accel is (Velocity:Orbit - prevVel):Mag.
    // Break if we'll hit the target mass in one update.
    if (burnMass <= 0) and (Velocity:Orbit:Mag + accel >= minVel)
        break.
}

if not EM_CheckThrust(0.1)
    print "Fuel exhaustion".

EM_Shutdown().
