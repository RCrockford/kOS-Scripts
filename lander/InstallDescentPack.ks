@lazyglobal off.

local fileList is list().

fileList:Add("FCFuncs.ks").
fileList:Add("lander/LanderDescentSystem.ks").

runpath("0:/localpack/InstallPack.ks", fileList).
