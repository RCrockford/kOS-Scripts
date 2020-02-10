// GSO circularisation burn, raise Pe to 35,786 km and plane change at apoapsis.

@lazyglobal off.

// Wait for unpack
wait until Ship:Unpacked.

// Calc required dV
local currentV is VelocityAt(Ship, ETA:Apoapsis + Time:Seconds).

local rVec is (PositionAt(Ship, ETA:Apoapsis + Time:Seconds) - Ship:Body:Position):Normalized.
local tVec is vcrs(rVec, Ship:Body:Up:Vector).

local targetA is 35786000 + Ship:Body:Radius.
local targetEcc is 0.
local targetV is sqrt(Ship:Body:Mu * targetA * (1 - targetEcc^2)) / (Ship:Orbit:Apoapsis + Ship:Body:Radius) * tVec.

local deltaV is targetV - currentV.

print "dV=" + round(deltaV, 4).

local massFlow is 0.
local burnThrust is 0.

runpath("0:/flight/EngineMgmt", burnStage).
set activeEngines to EM_GetEngines().

for eng in activeEngines
{
    set massFlow to massFlow + eng:MaxMassFlow.
    set burnThrust to burnThrust + eng:PossibleThrust.
}

// Calc burn duration
local massRatio is constant:e ^ (deltaV:Mag * massflow / burnThrust).
local finalMass is Ship:Mass / massRatio.
local duration is (Ship:Mass - finalMass) / massflow.

// Time to next node
local NodeAngle is mod(360 - (Ship:Orbit:ArgumentOfPeriapsis + Ship:Orbit:TrueAnomaly), 180).
if Ship:Latitude > 0
    print "Next node is descending in " + round(NodeAngle, 1) "°".
else
    print "Next node is ascending in " + round(NodeAngle, 1) "°".

// Assume close enough to circular orbit to use fixed speed.
local NodeETA is NodeAngle * Ship:Orbit:Period / 360.
print "  Node ETA: " + round("NodeETA, 1) + " s".

print "Executing manoeuvre at Node-" + round(duration * 0.5, 1) + " seconds.".
print "  DeltaV: " + round(deltaV:Mag, 1) + " m/s.".
print "  Duration: " + round(duration, 1) + " s.".

local burnEta is NodeETA - duration * 0.5.
if burnEta > 240 and Addons:Available("KAC")
{
    // Add a KAC alarm.
    AddAlarm("Raw", burnEta - 180 + Time:Seconds, Ship:Name + " Manoeuvre", Ship:Name + " is nearing its next manoeuvre").
}

local burnParams is lexicon(
    "t", duration,
    "dV", deltaV
).

runpath("0:/flight/SetupBurn", burnParams, list("flight/GSOCircBurn.ks", "FCFuncs.ks", "flight/EngineMgmt.ks")).
