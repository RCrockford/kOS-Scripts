@lazyglobal off.

// Wait for unpack
wait until Ship:Unpacked.

switch to scriptpath():volume.
Core:Part:ControlFrom().

parameter doUndock is false.

// Setup functions
runoncepath("/launch/lasfunctions").
runoncepath("/mgmt/resourcewalk").

LAS_Avionics("activate").
rcs on.

lock Steering to LookDirUp(Up:Vector, Facing:UpVector).
set Ship:Control:PilotMainThrottle to 1.

local canEject is false.

if doUndock
{
    local portList is GetConnectedParts(core:part, "DockingPort").
    
    for p in portList
    {
        if p:State:Substring(0,6) = "docked"
        {
            print "Undocking " + p:Title.
            p:undock.
            set canEject to true.
            break.
        }
    }
}
else
{
    print "Lifting off".
    stage.
    set canEject to true.
}

if canEject
{
    for eng in ship:engines
        eng:Activate.

    wait until Ship:VerticalSpeed > 2.

    legs off. gear off.

    wait until (Ship:Altitude - Ship:GeoPosition:TerrainHeight) > 50.

    lock steering to LookDirUp(-Up:Vector, Facing:UpVector).

    wait until (Ship:Altitude - Ship:GeoPosition:TerrainHeight) < 10.
}
else
{
    unlock Steering.
    set Ship:Control:PilotMainThrottle to 0.
    rcs off.
    LAS_Avionics("shutdown").
}
