@lazyglobal off.

parameter dV.

// Wait for unpack
wait until Ship:Unpacked.

switch to scriptpath():volume.

runoncepath("/flight/rcsperf.ks").

local perf is GetRCSForePerf().

local mf is perf:massFlow.
local thr is perf:thrust.

local mr is constant:e ^ (abs(dV) * mf / thr).
local fm is ship:Mass / mr.
local t is (ship:Mass - fm) / mf.

print "Duration:" + round(t, 1) + "s".

rcs on.
set Ship:Control:Fore to choose 1 if dV >= 0 else -1.

local st is Time:Seconds + t.
until st <= Time:Seconds
{
    print "Burning, Cutoff: " + round(st - Time:Seconds, 1) + " s" at (0,0).
    wait 0.
}

set Ship:Control:Neutralize to true.
rcs off.
