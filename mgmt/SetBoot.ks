@lazyglobal off.

parameter filename.

runpath("0:/localpack/InstallPack.ks", list(filename)).

if exists("1:/" + filename)
{
    print "Successfully set boot file".
    set core:bootfilename to "/" + filename.
    switch to 1.
}
else
{
    print "Could not set boot file".
    switch to 0.
}

runpath(filename).
