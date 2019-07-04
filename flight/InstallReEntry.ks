@lazyglobal off.

local fileList is list().

fileList:Add("FCFuncs.ks").
fileList:Add("flight/EngineManagement.ks").
fileList:Add("flight/ReEntry.ks").

runpath("0:/localpack/InstallPack.ks", fileList).
