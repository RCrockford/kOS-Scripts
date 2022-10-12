@lazyglobal off.

if not HasTarget
{
    print "Waiting for target.".
    wait until hastarget.
}

switch to scriptpath():volume.
Core:Part:ControlFrom().

parameter steerSpeed is 1.
parameter flyHeight is 4.

local dockTarget is target.

print "Docking with " + dockTarget:Title.

runpath("/bases/dockmove", flyHeight, steerSpeed).

RGUI_SetText(Readouts:status, "Moving", RGUI_ColourNormal).

lock steering to lookdirup(Up:Vector, dockTarget:Facing:UpVector).

set FlyTarget to true.
local dist is 100.

until engineFailure or (dist < 0.2 and Ship:GroundSpeed < 0.1)
{
    set dist to ControlUpdate().
    wait 0.
}

RGUI_SetText(Readouts:status, "Docking", RGUI_ColourNormal).

set TargetHeight to 0.

local startElements is Ship:Elements:Length.

until engineFailure or (Ship:Elements:Length > startElements)
{
    set dist to ControlUpdate().
    wait 0.
}

DockShutdown().
