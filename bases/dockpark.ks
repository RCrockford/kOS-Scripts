@lazyglobal off.

if not HasTarget
{
    print "Waiting for target.".
    wait until hastarget.
}

switch to scriptpath():volume.
Core:Part:ControlFrom().

parameter parkDist is 10.
parameter steerSpeed is 1.
parameter flyHeight is 4.

local parkTarget is target.
print "Parking " + parkDist + "m from " + parkTarget:Name.

runpath("/bases/dockmove", flyHeight, steerSpeed).

RGUI_SetText(Readouts:status, "Moving", RGUI_ColourNormal).

set FlyTarget to true.
local dist is 100.
if abs(vdot(parkTarget:Facing:starvector, up:vector)) < 0.7
    set TargetOffs to vxcl(Up:Vector, parkTarget:Facing:starvector) * parkDist.
else if abs(vdot(parkTarget:Facing:topvector, up:vector)) < 0.7
    set TargetOffs to vxcl(Up:Vector, parkTarget:Facing:topvector) * parkDist.
else
    set TargetOffs to vxcl(Up:Vector, parkTarget:Facing:forevector) * parkDist.

until engineFailure or (dist < 0.2 and Ship:GroundSpeed < 0.1)
{
    set dist to ControlUpdate().
    wait 0.
}

RGUI_SetText(Readouts:status, "Landing", RGUI_ColourNormal).

gear on.

set TargetHeight to TargetHeight - Alt:Radar.

until engineFailure or (Ship:Status = "Landed" or Ship:Status = "Splashed")
{
    ControlUpdate().
    wait 0.
}

ladders on.

DockShutdown().
