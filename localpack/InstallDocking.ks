@lazyglobal off.

// Clear storage
runpath("0:/localpack/InstallPack.ks", list()).

local filelist is list(
    "FCFuncs.ks",
    "flight/TuneSteering.ks",
    "flight/RCSPerf.ks",
    "flight/EngineMgmt.ks",
    "flight/FlightFuncs.ks",
    "flight/AlignTime.ks",
    "flight/DockActive.ks",
    "flight/Rendezvous.ks"
).

runpath("0:/localpack/InstallPack.ks", fileList).

if exists("1:/" + fileList[fileList:Length-1])
{
    print "Installed docking pack".
    switch to 1.
}
else
{
    print "Failed to install docking pack".
    switch to 0.
}
