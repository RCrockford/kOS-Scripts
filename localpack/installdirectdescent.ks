@lazyglobal off.

// Clear storage
runpath("0:/localpack/installpack.ks", list()).

local filelist is list(
    "fcfuncs.ks",
    "flight/tunesteering.ks",
    "flight/enginemgmt.ks",
    "lander/landersteering.ks",
    "lander/finaldescent.ks",
    "lander/landerthrottle.ks",
    "lander/ddpack.ks"
).

runpath("0:/localpack/installpack.ks", fileList).

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
