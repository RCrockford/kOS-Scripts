// GSO circularisation burn, raise Pe to 35,786 km and plane change at apoapsis.

@lazyglobal off.

// Wait for unpack
wait until Ship:Unpacked.

// Calc required dV
if HasNode and NextNode:ETA <= ETA:Apoapsis
    print "Manoeuvre node occurs before apogee, results may be inaccurate".

local deltaV is -VelocityAt(Ship, ETA:Apoapsis + Time:Seconds):Surface.

switch to 0.

runoncepath("0:/flight/FlightFuncs").
runpath("0:/flight/TuneSteering").
local burnDur is CalcBurnDuration(deltaV:Mag, true).

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

if CheckControl()
{
    local meanAnomDelta is CalcMeanAnom(Ship:Orbit:TrueAnomaly + NodeAngle) - CalcMeanAnom(Ship:Orbit:TrueAnomaly).
    set meanAnomDelta to mod(meanAnomDelta + 360, 360).

    local NodeETA is meanAnomDelta * Ship:Orbit:Period / 360.
    print "  Node ETA: " + FormatTime(nodeETA).

    print "Executing manoeuvre at Node-" + round(burnDur:halfBurn, 1) + " seconds.".
    print "  DeltaV: " + round(deltaV:Mag, 1) + " m/s.".
    print "  Duration: " + round(burnDur:duration, 1) + " s.".
    print "  Align at: T-" + round(alignMargin, 1) + " s.".

    local burnEta is NodeETA - burnDur:halfBurn.
    if burnEta - alignMargin > 300 and Addons:Available("KAC")
    {
        // Add a KAC alarm.
        AddAlarm("Raw", burnEta - alignMargin - 60 + Time:Seconds, Ship:Name + " Manoeuvre", Ship:Name + " is nearing its next manoeuvre").
    }

    local burnParams is lexicon(
        "t", burnDur:halfBurn,
        "align", alignMargin
    ).

    runpath("0:/flight/SetupBurn", burnParams, list("flight/GEOCircBurn.ks", "FCFuncs.ks", "flight/FlightFuncs.ks", "flight/EngineMgmt.ks")).
}