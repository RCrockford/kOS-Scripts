@lazyglobal off.

// Clear storage
runpath("0:/localpack/InstallPack.ks", list()).

local filelist is list(
    "FCFuncs.ks",
    "flight/TuneSteering.ks",
    "flight/EngineMgmt.ks",
    "lander/LanderSteering.ks",
    "lander/FinalDescent.ks",
    "lander/LanderThrottle.ks",
    "lander/MarsDescent.ks"
).

runpath("0:/localpack/InstallPack.ks", fileList).

if fileList[fileList:Length-1]
{
    print "Installed Mars descent pack".
    switch to 1.
}
else
{
    print "Failed to install Mars descent pack".
    switch to 0.
}
