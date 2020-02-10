// GTO insertion burn, raise Ap to 35,786 km at orbital node.

@lazyglobal off.

// Wait for unpack
wait until Ship:Unpacked.

// Calc required dV
local currentV is sqrt(Ship:Body:Mu * Ship:Orbit:SemiMajorAxis * (1 - Ship:Orbit:Eccentricity^2)) / Ship:Orbit:SemiMajorAxis.

set targetAp to 35786000 + Ship:Body:Radius.

local targetA is (Ship:Orbit:SemiMajorAxis + targetAp) / 2.
local targetEcc is targetAp / targetA - 1.
local targetV is sqrt(Ship:Body:Mu * targetA * (1 - targetEcc^2)) / aveR.

set targetAp to targetAp - Ship:Body:Radius.
local deltaV is targetV - currentV.

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
local massRatio is constant:e ^ (deltaV * massflow / burnThrust).
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
print "  DeltaV: " + round(deltaV, 1) + " m/s.".
print "  Duration: " + round(duration, 1) + " s.".

local burnEta is NodeETA - duration * 0.5.
if burnEta > 240 and Addons:Available("KAC")
{
    // Add a KAC alarm.
    AddAlarm("Raw", burnEta - 180 + Time:Seconds, Ship:Name + " Manoeuvre", Ship:Name + " is nearing its next manoeuvre").
}

local burnParams is lexicon(
    "t", duration
).

runpath("0:/flight/SetupBurn", burnParams, list("flight/GTOInsertBurn.ks", "FCFuncs.ks", "flight/EngineMgmt.ks")).
