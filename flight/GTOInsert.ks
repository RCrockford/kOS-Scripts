// GTO insertion burn, raise Ap to 35,786 km at orbital node.

@lazyglobal off.

// Wait for unpack
wait until Ship:Unpacked.

// Calc required dV
local currentV is sqrt(Ship:Body:Mu * Ship:Orbit:SemiMajorAxis * (1 - Ship:Orbit:Eccentricity^2)) / Ship:Orbit:SemiMajorAxis.

local targetAp is 35793171 + Ship:Body:Radius.

local targetA is (Ship:Orbit:SemiMajorAxis + targetAp) / 2.
local targetEcc is targetAp / targetA - 1.
local targetV is sqrt(Ship:Body:Mu * targetA * (1 - targetEcc^2)) / Ship:Orbit:SemiMajorAxis.

set targetAp to targetAp - Ship:Body:Radius.
local deltaV is targetV - currentV.

runpath("0:/flight/FlightFuncs").
runpath("0:/flight/TuneSteering").
local burnDur is CalcBurnDuration(deltaV, true).

// Calc alignment time
runpath("0:/flight/AlignTime").
local alignMargin is GetAlignTime().

// Time to next node
local NodeAngle is mod(Ship:Orbit:ArgumentOfPeriapsis + Ship:Orbit:TrueAnomaly + 360, 360).
if Ship:Latitude > 0
{
	set NodeAngle to 180 - NodeAngle.
    print "Next node is descending in " + round(NodeAngle, 1) + "°".
}
else
{
	set NodeAngle to 360 - NodeAngle.
    print "Next node is ascending in " + round(NodeAngle, 1) + "°".
}

local meanAnomDelta is CalcMeanAnom(Ship:Orbit:TrueAnomaly + NodeAngle) - CalcMeanAnom(Ship:Orbit:TrueAnomaly).

local NodeETA is meanAnomDelta * Ship:Orbit:Period / 360.
print "  Node ETA: " + FormatTime(NodeETA).

print "Executing manoeuvre at Node-" + round(burnDur:halfBurn, 1) + " seconds.".
print "  DeltaV: " + round(deltaV, 1) + " m/s.".
print "  Duration: " + round(burnDur:duration, 1) + " s.".
print "  Align at: T-" + round(alignMargin, 1) + " s.".

local burnEta is NodeETA - burnDur:halfBurn.
if burnEta > 1800 and Addons:Available("KAC")
{
    // Add a KAC alarm.
    AddAlarm("Raw", burnEta - alignMargin - 30 + Time:Seconds, Ship:Name + " Manoeuvre", Ship:Name + " is nearing its next manoeuvre").
}

local burnParams is lexicon(
    "t", burnDur:halfBurn,
    "align", alignMargin
).

runpath("0:/flight/SetupBurn", burnParams, list("flight/GTOInsertBurn.ks", "FCFuncs.ks", "flight/EngineMgmt.ks")).
