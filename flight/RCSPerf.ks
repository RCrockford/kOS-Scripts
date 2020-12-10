@lazyglobal off.

global function GetRCSForePerf
{
    local perfStats is lexicon("thrust", 0, "massflow", 0).

    local allRCS is list().
    list rcs in allRCS.

    for r in allRCS
    {
        if r:HasSuffix("ThrustVectors") and r:Enabled
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
    }

    return perfStats.
}

global function GetRCSAftPerf
{
    local perfStats is lexicon("thrust", 0, "massflow", 0).

    local allRCS is list().
    list rcs in allRCS.

    for r in allRCS
    {
        if r:HasSuffix("ThrustVectors") and r:Enabled
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
    }

    return perfStats.
}

global function GetRCSPerf
{
    local allRCS is list().
    list rcs in allRCS.

    local shipAxes is list(list("fore", Ship:ControlPart:Facing:ForeVector, Ship:ControlPart:Facing:TopVector), list("aft", -Ship:ControlPart:Facing:ForeVector, -Ship:ControlPart:Facing:TopVector),
                           list("star", Ship:ControlPart:Facing:StarVector), list("port", -Ship:ControlPart:Facing:StarVector),
                           list("up", Ship:ControlPart:Facing:TopVector), list("down", -Ship:ControlPart:Facing:TopVector)).

    local perfStats is lexicon().
    for a in shipAxes
    {
        perfStats:add(a[0], lexicon("thrust", 0, "massflow", 0, "torque", 0)).
    }

    for r in allRCS
    {
        if r:HasSuffix("ThrustVectors") and r:Enabled
        {
            for a in shipAxes
            {
                local thrustMul is 0.
                for t in r:ThrustVectors
                {
                    set thrustMul to thrustMul + max(vdot(t, a[1]), 0).
                }

                if thrustMul > 0.01
                {
                    set perfStats[a[0]]:thrust to perfStats[a[0]]:thrust + r:AvailableThrust * min(thrustMul, 1).
                    set perfStats[a[0]]:massflow to perfStats[a[0]]:massflow + r:MaxMassFlow.
                }

                set thrustMul to 0.
                for t in r:ThrustVectors
                {
                    set thrustMul to thrustMul + max(vdot(vcrs(r:position, t), a[1]), 0).
                }

                if thrustMul > 0.001
                {
                    set perfStats[a[0]]:torque to perfStats[a[0]]:torque + r:AvailableThrust * thrustMul.
                }
            }
        }
    }

    return perfStats.
}
