@lazyglobal off.

local fileList is list().

fileList:Add("FCFuncs.ks").

fileList:Add("launch/LASFunctions.ks").
fileList:Add("launch/FlightControlNoAtm.ks").
fileList:Add("launch/OrbitalGuidance.ks").

fileList:Add("lander/LanderAscentSystem.ks").
fileList:Add("lander/LanderDescentSystem.ks").

runpath("0:/localpack/InstallPack.ks", fileList).
