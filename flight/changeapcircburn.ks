// Change apoapsis using RCS or engines for circular orbits

@lazyglobal off.

parameter targetAp.

wait until Ship:Unpacked.

runpath("/flight/enginemgmt", stage:number).
local ignitionTime is EM_IgDelay().

kUniverse:Timewarp:CancelWarp().
print "Aligning ship".

LAS_Avionics("activate").

rcs on.
lock steering to LookDirUp(Prograde:Vector, Facing:UpVector).

wait 0.

wait until steeringmanager:AngleError < 0.5.

print "Starting burn".

EM_Ignition().

wait until Ship:Orbit:Apoapsis >= targetAp * 1000 or not EM_CheckThrust(0.1).

EM_Shutdown().