@lazyglobal off.

global function GetRCSForePerf
{
	local perfStats is lexicon().
	perfStats:add("thrust", 0).
	perfStats:add("massflow", 0).

    local allRCS is list().
    list rcs in allRCS.

    for r in allRCS
    {
        local thrustMul is 0.
        for t in r:ThrustVectors
        {
            set thrustMul to thrustMul + max(vdot(t, -Ship:ControlPart:Facing:ForeVector), 0).
        }

        if thrustMul > 0.01
        {
            set perfStats:thrust to perfStats:thrust + r:AvailableThrust * min(thrustMul, 1).
            set perfStats:massflow to perfStats:massflow + r:MaxMassFlow.
        }
	}

	return perfStats.
}

global function GetRCSAftPerf
{
	local perfStats is lexicon().
	perfStats:add("thrust", 0).
	perfStats:add("massflow", 0).

    local allRCS is list().
    list rcs in allRCS.

    for r in allRCS
    {
        local thrustMul is 0.
        for t in r:ThrustVectors
        {
            set thrustMul to thrustMul + max(vdot(t, Ship:ControlPart:Facing:ForeVector), 0).
        }

        if thrustMul > 0.01
        {
            set perfStats:thrust to perfStats:thrust + r:AvailableThrust * min(thrustMul, 1).
            set perfStats:massflow to perfStats:massflow + r:MaxMassFlow.
        }
	}

	return perfStats.
}
