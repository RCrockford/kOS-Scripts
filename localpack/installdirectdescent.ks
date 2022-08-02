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
    "lander/DDPack.ks"
).

runpath("0:/localpack/InstallPack.ks", fileList).

if fileList[fileList:Length-1]
{
    print "Installed direct descent pack".
    switch to 1.
}
else
{
    print "Failed to install direct descent pack".
    switch to 0.
}
