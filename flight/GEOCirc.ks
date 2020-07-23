// GSO circularisation burn, raise Pe to 35,786 km and plane change at apoapsis.

@lazyglobal off.

// Wait for unpack
wait until Ship:Unpacked.

// Calc required dV
local currentV is VelocityAt(Ship, ETA:Apoapsis + Time:Seconds):Orbit.

local rVec is (PositionAt(Ship, ETA:Apoapsis + Time:Seconds) - Ship:Body:Position):Normalized.
local nVec is (LatLng(90,0):Position - Ship:Body:Position):Normalized.
local tVec is vcrs(rVec, nVec):Normalized.
local rVec is vcrs(nVec, tVec):Normalized.

local targetA is 35793171 + Ship:Body:Radius.
local targetEcc is 0.
local targetV is sqrt(Ship:Body:Mu * targetA * (1 - targetEcc^2)) / (Ship:Orbit:Apoapsis + Ship:Body:Radius) * tVec.

local deltaV is targetV - currentV.

runoncepath("0:/flight/FlightFuncs").
local burnDur is CalcBurnDuration(deltaV:Mag, true).

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
print "  Node ETA: " + FormatTime(nodeETA).

print "Executing manoeuvre at Node-" + round(burnDur:halfBurn, 1) + " seconds.".
print "  DeltaV: " + round(deltaV:Mag, 1) + " m/s.".
print "  Duration: " + round(burnDur:duration, 1) + " s.".

local burnEta is NodeETA - burnDur:halfBurn.
if burnEta > 240 and Addons:Available("KAC")
{
    // Add a KAC alarm.
    AddAlarm("Raw", burnEta - 180 + Time:Seconds, Ship:Name + " Manoeuvre", Ship:Name + " is nearing its next manoeuvre").
}

local burnParams is lexicon(
    "t", burnDur:halfBurn,
    "tV", targetV
).

runpath("0:/flight/SetupBurn", burnParams, list("flight/GEOCircBurn.ks", "FCFuncs.ks", "flight/FlightFuncs.ks", "flight/EngineMgmt.ks")).
