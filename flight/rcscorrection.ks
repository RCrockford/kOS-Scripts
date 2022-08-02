// Course correction manoeuvres using KSP flight planner and RCS

@lazyglobal off.

parameter tangent is 0.
parameter normal is 0.
parameter binormal is 0.
parameter burnStart is 0.

// Wait for unpack
wait until Ship:Unpacked.

switch to scriptpath():volume.

local dV is 0.

if not HasNode
{
    set dV to V(tangent, normal, binormal).
    set burnStart to time:Seconds + burnStart.
    lock burnEta to burnStart - time:Seconds.
}
else
{
    set dV to NextNode:DeltaV.
    lock burnEta to NextNode:eta.
}
runoncepath("0:/FCFuncs").
runoncepath("0:/flight/FlightFuncs").

runoncepath("0:/flight/RCSPerf.ks").
local RCSPerf is GetRCSPerf().

local maxThrust is RCSPerf:fore:thrust.
local minThrust is RCSPerf:fore:thrust.
local minFlow is RCSPerf:fore:massflow.

for r in RCSPerf:keys
{
    if RCSPerf[r]:IsType("lexicon")
    {
        if RCSPerf[r]:thrust < minThrust
        {
            set minThrust to RCSPerf[r]:thrust.
            set minFlow to RCSPerf[r]:massflow.
        }
        set maxThrust to max(maxThrust, RCSPerf[r]:thrust).
    }
}

if CheckControl()
{
    if minThrust < maxThrust * 0.1 or maxThrust < 1e-6
    {
        print "RCS thrust is too imbalanced for correction burn.".
        for r in RCSPerf:keys
            if RCSPerf[r]:IsType("lexicon")
                print "  " + r + " = " + RCSPerf[r]:thrust.
    }
    else
    {

        // Calc burn duration
        local massRatio is constant:e ^ (dV:Mag * minFlow / minThrust).
        local finalMass is Ship:Mass / massRatio.
        local duration is (Ship:Mass - finalMass) / minFlow.

        print "Executing manoeuvre in " + FormatTime(burnEta).
        print "  DeltaV: " + round(dV:Mag, 1) + " m/s.".
        print "  Duration: " + round(duration, 1) + " s.".

        if burnEta > 300 and Addons:Available("KAC")
        {
            // Add a KAC alarm.
            AddAlarm("Raw", burnEta - 60 + Time:Seconds, Ship:Name + " Manoeuvre", Ship:Name + " is nearing its next manoeuvre").
        }

        local burnParams is lexicon(
            "t", duration,
            "fth", minThrust / RCSPerf:fore:thrust,
            "ath", minThrust / RCSPerf:aft:thrust,
            "sth", minThrust / RCSPerf:star:thrust,
            "pth", minThrust / RCSPerf:port:thrust,
            "uth", minThrust / RCSPerf:up:thrust,
            "dth", minThrust / RCSPerf:down:thrust
        ).

        if not HasNode
        {
            burnParams:Add("eta", burnStart).
            burnParams:Add("dvx", dV:X).
            burnParams:Add("dvy", dV:Y).
            burnParams:Add("dvz", dV:Z).
        }

        local fileList is list("flight/RCSCorrectionBurn.ks", "FCFuncs.ks").

        runpath("0:/flight/SetupBurn", burnParams, fileList).
    }
}