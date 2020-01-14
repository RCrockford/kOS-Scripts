// Lower apoapsis using RCS or engines

@lazyglobal off.

parameter targetAp.
parameter useEngines is false.

// Wait for unpack
wait until Ship:Unpacked.

// Calc required dV
local currentV is sqrt(Ship:Body:Mu * Ship:Orbit:SemiMajorAxis * (1 - Ship:Orbit:Eccentricity^2)) / (Ship:Orbit:Periapsis + Ship:Body:Radius).

set targetAp to targetAp * 1000 + Ship:Body:Radius.

local targetA is (Ship:Orbit:Periapsis + Ship:Body:Radius + targetAp) / 2.
local targetEcc is targetAp / targetA - 1.
local targetV is sqrt(Ship:Body:Mu * targetA * (1 - targetEcc^2)) / (Ship:Orbit:Periapsis + Ship:Body:Radius).

set targetAp to targetAp - Ship:Body:Radius.
local deltaV is targetV - currentV.

local massFlow is 0.
local burnThrust is 0.

if useEngines
{
    runpath("0:/flight/EngineMgmt", burnStage).
    set activeEngines to EM_GetEngines().

    for eng in activeEngines
    {
        set massFlow to massFlow + eng:MaxMassFlow.
        set burnThrust to burnThrust + eng:PossibleThrust.
    }
}
else
{
    // Get RCS stats
    runoncepath("0:/flight/RCSPerf.ks").
    local RCSPerf is GetRCSForePerf().
    set massFlow to RCSPerf:massflow.
    set burnThrust to RCSPerf:thrust.
}

// Calc burn duration
local massRatio is constant:e ^ (deltaV * massflow / burnThrust).
local finalMass is Ship:Mass / massRatio.
local duration is (Ship:Mass - finalMass) / massflow.

print "Executing manoeuvre at Pe-" + round(duration * 0.5, 1) + " seconds.".
print "  DeltaV: " + round(deltaV, 1) + " m/s.".
print "  Duration: " + round(duration, 1) + " s.".

local burnEta is Eta:Periapsis - duration * 0.5.
if burnEta > 240 and Addons:Available("KAC")
{
    // Add a KAC alarm.
    AddAlarm("Raw", burnEta - 180 + Time:Seconds, Ship:Name + " Manoeuvre", Ship:Name + " is nearing its next manoeuvre").
}

local burnParams is lexicon(
    "ap", targetAp",
    "t", duration
).

if useEngines
    runpath("0:/flight/SetupBurn", burnParams, list("flight/LowerApoBurn.ks", "FCFuncs.ks" "flight/EngineMgmt.ks")).
else
    runpath("0:/flight/SetupBurn", burnParams, list("flight/LowerApoRCS.ks")).
