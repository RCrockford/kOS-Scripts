@lazyglobal off.

// 200 km circular orbit, orbital matching with Moon.
global LAS_TargetPe is 200.
global LAS_TargetAp is 200.
global LAS_LastStage is 2.

runpath("0:/launch/LaunchAscentSystem.ks", -1, Moon:Orbit).
