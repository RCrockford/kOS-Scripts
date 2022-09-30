@lazyglobal off.

// Clear storage
runpath("0:/localpack/installpack.ks", list()).

local filelist is list(
    "fcfuncs.ks",
    "lander/roveto.ks"
).

runpath("0:/localpack/installpack.ks", fileList).

if fileList[fileList:Length-1]
{
    print "Installed rover pack".
    switch to 1.
}
else
{
    print "Failed to install rover pack".
    switch to 0.
}
