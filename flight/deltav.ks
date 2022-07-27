@lazyglobal off.

wait until Ship:Unpacked.

runoncepath("0:/mgmt/ResourceWalk").

runpath("0:/flight/EngineMgmt", Stage:Number).
local activeEngines is EM_GetEngines().

local fuelName is 0.
local fuelTotal is 0.
local fuelCapacity is 0.
local maxFuelFlow is 0.
local massFlow is 0.
local burnThrust is 0.
local residuals is 0.

for eng in activeEngines
{
    set massFlow to massFlow + eng:MaxMassFlow.
    set burnThrust to burnThrust + eng:PossibleThrust.
    set residuals to max(residuals, eng:residuals).
}

local activeResources is GetConnectedResources(activeEngines[0]).

local maxFlow is 0.
for k in activeEngines[0]:ConsumedResources:keys
{
    local res is activeEngines[0]:ConsumedResources[k].
    if res:Density > 0 and activeResources:HasKey(res:Name) and res:Name = k
    {
        if res:MaxFuelFlow > maxFlow
        {
            set fuelName to res:Name.
            set fuelTotal to activeResources[res:Name]:Amount.
            set fuelCapacity to activeResources[res:Name]:Capacity.
            set maxFlow to res:MaxFuelFlow.
        }
    }
}

set maxFuelFlow to 0.
for eng in activeEngines
{
    if eng:ConsumedResources:HasKey(fuelName)
    {
        local res is eng:ConsumedResources[fuelName].
        set maxFuelFlow to maxFuelFlow + res:MaxFuelFlow.
    }
}

local duration is (fuelTotal - fuelCapacity * residuals) / maxFuelFlow.
local finalMass is ship:Mass - duration * massFlow.
local massRatio is ship:Mass / finalMass.
local dV is ln(massRatio) * burnThrust / massflow.

print "Delta V (safe): " + round(dV, 1) + " m/s".

set duration to fuelTotal / maxFuelFlow.
set finalMass to ship:Mass - duration * massFlow.
set massRatio to ship:Mass / finalMass.
set dV to ln(massRatio) * burnThrust / massflow.

print "Delta V (full): " + round(dV, 1) + " m/s".
