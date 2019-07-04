@lazyglobal off.

local fileList is list().

fileList:Add("FCFuncs.ks").
fileList:Add("flight/EngineManagement.ks").
fileList:Add("flight/ExecuteManoeuvre.ks").
if Career():CanMakeNodes
{
    fileList:Add("flight/StdBurn.ks").
    fileList:Add("flight/RCSBurn.ks").
    fileList:Add("flight/SpinBurn.ks").
}
else
{
    fileList:Add("flight/StdBurnM.ks").
    fileList:Add("flight/RCSBurnM.ks").
    fileList:Add("flight/SpinBurnM.ks").
}

runpath("0:/localpack/InstallPack.ks", fileList).
