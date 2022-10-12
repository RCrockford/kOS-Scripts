@lazyglobal off.

if not HasTarget
{
    print "Waiting for target.".
    wait until hastarget and target:IsType("DockingPort").
}

switch to scriptpath():volume.
Core:Part:ControlFrom().

parameter steerSpeed is 1.

local heightOffset is 0.
local alignAngle is 0.
local dockPort is Ship:DockingPorts[0].
local dockTarget is target.

for port in Ship:DockingPorts
{
    if abs(vdot(port:Facing:Vector, Facing:Vector)) < 0.1
    {
        if port:nodetype = dockTarget:nodetype
        {
            set dockPort to port.
            print "Using port: " + port:Title.
            set HeightOffset to -vdot(port:position, Facing:Vector).
            set alignAngle to vang(port:portfacing:Vector, Facing:UpVector).
            if vdot(angleaxis(alignAngle, Facing:Vector) * Facing:UpVector, port:facing:Vector) > vdot(angleaxis(-alignAngle, Facing:Vector) * Facing:UpVector, port:facing:Vector)
                set alignAngle to -alignAngle.
            break.
        }
    }
}

print "Docking with " + dockTarget:Title.

local lock flightHeight to HeightOffset + (choose 2 if vdot(dockTarget:facing:vector, dockTarget:position) < 0.5 else 8).
runpath("/bases/dockmove", flightHeight, steerSpeed).

RGUI_SetText(Readouts:status, "Moving", RGUI_ColourNormal).

set FlyTarget to true.
local dist is 100.
set TargetOffs to dockTarget:portfacing:vector * 5.

until engineFailure or (dist < 0.5 and Ship:GroundSpeed < 0.2)
{
    set dist to ControlUpdate().
    set TargetHeight to flightHeight.
    wait 0.
}

RGUI_SetText(Readouts:status, "Aligning", RGUI_ColourNormal).

set TargetHeight to HeightOffset.
lock steering to lookdirup(Up:Vector, angleaxis(alignAngle, Facing:Vector) * dockTarget:Position).

until engineFailure or (vang(dockPort:portfacing:Vector, dockTarget:Position:Normalized) < 20 and abs(Ship:VerticalSpeed) < 0.1)
{
    ControlUpdate().
    wait 0.
}

RGUI_SetText(Readouts:status, "Docking", RGUI_ColourNormal).

set TargetOffs to -vxcl(Facing:Vector, dockPort:position).
set JitterPos to true.

local startElements is Ship:Elements:Length.

until engineFailure or (Ship:Elements:Length > startElements)
{
    ControlUpdate().
    wait 0.
}

DockShutdown().
