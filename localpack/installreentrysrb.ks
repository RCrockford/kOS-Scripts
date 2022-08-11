@lazyglobal off.

// Clear storage
runpath("0:/localpack/installpack.ks", list()).

local filelist is list(
    "fcfuncs.ks",
    "reentry/reentrysrb.ks",
    "reentry/reentrylanding.ks"
).

runpath("0:/localpack/installpack.ks", fileList).

if fileList[fileList:Length-1]
{
    print "Installed reentry pack".
    switch to 1.
}
else
{
    print "Failed to install reentry pack".
    switch to 0.
}
