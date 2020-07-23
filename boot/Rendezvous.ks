@lazyglobal off.

Core:DoEvent("Open Terminal").

// Wait for target to be set
print "Waiting for target.".
wait until hastarget.
local tOrbit is Target:Orbit.

// Orbital matching with target.
global LAS_TargetPe is (tOrbit:SemiMajorAxis - Ship:Body:Radius) * 0.8 / 1000.
set LAS_TargetPe to max(LAS_TargetPe, 150).
global LAS_TargetAp is LAS_TargetPe.

runpath("0:/launch/LaunchAscentSystem.ks", -1, tOrbit).
