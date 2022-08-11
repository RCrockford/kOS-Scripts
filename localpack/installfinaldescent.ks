@lazyglobal off.

// Clear storage
runpath("0:/localpack/installpack.ks", list()).

local filelist is list(
    "fcfuncs.ks",
    "flight/tunesteering.ks",
    "flight/enginemgmt.ks",
    "lander/landersteering.ks",
    "lander/finaldescent.ks",
    "lander/landerthrottle.ks"
).

runpath("0:/localpack/installpack.ks", fileList).

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
