@lazyglobal off.

parameter burnParams.
parameter fileList.
parameter name is "manoeuvre".

// Clear storage
runpath("0:/localpack/InstallPack.ks", list()).

// Write to storage so it can be restored when switching to ship.
local burnStr is "".
for k in burnParams:keys
{
    set burnStr to burnStr + k + "," + burnParams[k] + ",".
}
create("1:/burn.csv"):write(burnStr:Substring(0, max(burnStr:Length-1, 0))).

runpath("0:/localpack/InstallPack.ks", fileList).

if exists("1:/" + fileList[fileList:Length-1])
{
    print "Waiting for " + name + " in autonomous mode".
    set core:bootfilename to "/" + fileList[0].
    switch to 1.
}
else
{
    print "Waiting for " + name + " in downlink mode".
    switch to 0.
}

runpath(fileList[0]).
