@lazyglobal off.

global LAS_TargetPe is 200.
global LAS_TargetAp is 200.

// Calc required inclination
runpath("0:/launch/CelestialLaunch").

runpath("0:/launch/LaunchAscentSystem.ks", -1, 0).
