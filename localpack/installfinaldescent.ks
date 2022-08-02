@lazyglobal off.

// Clear storage
runpath("0:/localpack/InstallPack.ks", list()).

local filelist is list(
    "FCFuncs.ks",
    "flight/TuneSteering.ks",
    "flight/EngineMgmt.ks",
    "lander/LanderSteering.ks",
    "lander/FinalDescent.ks",
    "lander/LanderThrottle.ks"
).

runpath("0:/localpack/InstallPack.ks", fileList).

if fileList[fileList:Length-1]
{
    print "Installed final descent pack".
    switch to 1.
}
else
{
    print "Failed to install final descent pack".
    switch to 0.
}
