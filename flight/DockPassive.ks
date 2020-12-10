// Docking passive side
@lazyglobal off.

if not HasTarget
{
    print "Waiting for target.".
    wait until hastarget.
}

parameter minDist is 50.
local tShip is target.

// Wait for unpack
wait until Ship:Unpacked.

wait until tShip:Position:Mag < minDist.

switch to scriptpath():volume.
runoncepath("/FCFuncs").
runpath("flight/TuneSteering").

LAS_Avionics("activate").

local port is 0.
for p in Ship:Parts
{
    if p:IsType("DockingPort")
    {
        set port to p.
        break.
    }
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

rcs on.
lock steering to lookdirup(tShip:Position:Normalized, Facing:UpVector).

local startElements is Ship:Elements:Length.
wait until (port:IsType("DockingPort") and port:State <> "Ready") or Ship:Elements:Length > startElements.

unlock steering.
set Ship:Control:Neutralize to true.
rcs off.
LAS_Avionics("shutdown").
