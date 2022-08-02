@lazyglobal off.

// Clear storage
runpath("0:/localpack/installpack.ks", list()).

local filelist is list(
    "fcfuncs.ks",
    "flight/tunesteering.ks",
    "flight/rcsperf.ks",
    "flight/enginemgmt.ks",
    "flight/flightfuncs.ks",
    "flight/aligntime.ks",
    "mgmt/readoutgui.ks",
    "rdvz/dockactive.ks",
    "rdvz/rdvzfuncs.ks",
    "rdvz/rendezvous.ks"
).

runpath("0:/localpack/installpack.ks", fileList).

if fileList[fileList:Length-1]
{
    print "Installed docking pack".
    switch to 1.
}
else
{
    print "Failed to install docking pack".
    switch to 0.
}
