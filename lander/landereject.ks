@lazyglobal off.

// Wait for unpack
wait until Ship:Unpacked.

switch to scriptpath():volume.
Core:Part:ControlFrom().

// Setup functions
runoncepath("/launch/lasfunctions").

print "Lifting off".

LAS_Avionics("activate").
rcs on.

lock Steering to LookDirUp(Up:Vector, Facing:UpVector).
set Ship:Control:PilotMainThrottle to 1.

stage.

wait until Ship:VerticalSpeed > 2.

legs off. gear off.

wait until (Ship:Altitude - Ship:GeoPosition:TerrainHeight) > 50.

lock steering to LookDirUp(-Up:Vector, Facing:UpVector).

wait until (Ship:Altitude - Ship:GeoPosition:TerrainHeight) < 10.