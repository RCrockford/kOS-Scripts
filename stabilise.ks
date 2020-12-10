@lazyglobal off.

// Wait for unpack
wait until Ship:Unpacked.
Core:Part:ControlFrom().

for a in Ship:ModulesNamed("ModuleProceduralAvionics")
{
	if a:HasEvent("activate avionics")
		a:DoEvent("activate avionics").
}

rcs on.
lock steering to LookDirUp(Ship:Up:Vector, Facing:UpVector).

wait 1.

// Maintain attitude control until ship settles to prevent roll overs.
wait until Ship:Velocity:Surface:SqrMagnitude < 0.01 and Ship:AngularVel:Mag < 0.005.

unlock steering.
set Ship:Control:Neutralize to true.
rcs off.

for a in Ship:ModulesNamed("ModuleProceduralAvionics")
{
	if a:HasEvent("shutdown avionics")
		a:DoEvent("shutdown avionics").
}
