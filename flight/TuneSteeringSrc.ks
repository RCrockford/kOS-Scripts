@lazyglobal off.

local allRCS is list().
list rcs in allRCS.

local upTorque is 0.
local upVec is Ship:ControlPart:Facing:TopVector.

for r in allRCS
{
	local thrustMul is 0.
	for t in r:ThrustVectors
	{
		set thrustMul to thrustMul + max(vdot(t, upVec), 0).
	}

	if thrustMul > 0.01
	{
		set upTorque to upTorque + r:AvailableThrust * min(thrustMul, 1) * r:position:mag.
	}
}

steeringmanager:resettodefault().

set steeringmanager:pitchtorqueadjust to upTorque * 0.25.
set steeringmanager:yawtorqueadjust to upTorque * 0.25.
set steeringmanager:pitchtorquefactor to 0.8.
set steeringmanager:yawtorquefactor to 0.8.