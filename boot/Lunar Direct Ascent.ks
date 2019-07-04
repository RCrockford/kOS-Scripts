@lazyglobal off.

global LAS_TargetPe is 200.

// Estimated flight time of 68 hours.
runpath("0:/launch/LaunchWindow", Moon, 68 * 3600).

// Get current altitude of Moon, assume that's approximately correct for impact time.
global LAS_TargetAp is Moon:Altitude / 1000.

runpath("0:/launch/LaunchAscentSystem.ks", -1, Moon).
