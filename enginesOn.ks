@lazyglobal off.

// Wait for unpack
wait until Ship:Unpacked.

switch to scriptpath():volume.

runpath("/flight/EngineMgmt", stage:number).

lock throttle to 0.
for eng in EM_GetEngines()
{
    eng:Activate.
}

print "Engines active, press d to deactivate".

until false
{
    wait until Terminal:Input:HasChar.
    if Terminal:Input:GetChar() = "d"
        break.
}

for eng in EM_GetEngines()
{
    eng:Shutdown.
}

unlock throttle.
set ship:control:neutralize to true.