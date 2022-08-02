@lazyglobal off.

// Clear storage
runpath("0:/localpack/InstallPack.ks", list()).

local filelist is list(
    "FCFuncs.ks",
    "reentry/ReEntrySRB.ks",
    "reentry/ReEntryLanding.ks"
).

runpath("0:/localpack/InstallPack.ks", fileList).

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
