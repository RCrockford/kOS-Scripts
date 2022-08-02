// Docking passive side
@lazyglobal off.

if not HasTarget
{
    print "Waiting for target.".
    wait until hastarget.
}

parameter minDist is 100.
parameter portIdx is -1.
local tShip is target.

// Wait for unpack
wait until Ship:Unpacked.

switch to scriptpath():volume.
runoncepath("/FCFuncs").
runpath("flight/TuneSteering").

LAS_Avionics("activate").

local port is 0.

if Ship:DockingPorts:Length > 0
{
    if portIdx < 0 or portIdx >= Ship:DockingPorts:Length
    {
        print "Selecting first port from list: ".
        for p in Ship:DockingPorts
            print "  " + p:Title.
        set portIdx to 0.
    }
    set port to Ship:DockingPorts[portIdx].
}

if port:IsType("DockingPort")
{
    print "Controlling from " + port:Title.
    port:ControlFrom().
}
else
{
    set port to Ship:rootpart.
}

wait until tShip:Position:Mag < minDist.

rcs on.
lock steering to lookdirup(tShip:Position:Normalized, Facing:UpVector).

local startElements is Ship:Elements:Length.
wait until Ship:Elements:Length > startElements.

unlock steering.
set Ship:Control:Neutralize to true.
rcs off.
LAS_Avionics("shutdown").
