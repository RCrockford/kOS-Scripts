@lazyglobal off.

global function SetupDiffThrottle
{
    parameter stageEngines.

    local diffEngines is list().
    local pitchTorque is 0.
    local yawTorque is 0.

    for eng in stageEngines
    {
        set eng:gimbal:lock to true.
        set eng:ThrustLimit to 100.
        
        local starF is vdot(eng:Position, Facing:StarVector).
        local topF is vdot(eng:Position, Facing:TopVector).
        local dist is sqrt(starF ^ 2 + topF ^ 2).
        
        if dist > eng:Bounds:Extents:Mag
        {
            local pRatio is -topF / dist.
            local yRatio is -starF / dist.
            local total is abs(pRatio) + abs(yRatio).
            
            set pRatio to pRatio / total.
            set yRatio to yRatio / total.

            set pitchTorque to pitchTorque + eng:PossibleThrust * abs(topF) * 0.5.
            set yawTorque to yawTorque + eng:PossibleThrust * abs(starF) * 0.5.
            
            diffEngines:Add(lexicon("eng", eng, "pitch", pRatio, "yaw", yRatio)).
        }
    }
    
    if diffEngines:Length > 0 and pitchTorque > 0 and yawTorque > 0
    {
        SteeringManager:ResetToDefault().
        set SteeringManager:PitchTorqueAdjust to pitchTorque * 0.5.
        set SteeringManager:YawTorqueAdjust to yawTorque * 0.5.
        set SteeringManager:MaxStoppingTime to 1.
    }
    else
    {
        print "Failed to configure differential throttle".
        print " pitch torque: " + round(pitchTorque, 4).
        print " yaw torque:   " + round(yawTorque, 4).
        diffEngines:Clear().
    }
    
    return diffEngines.
}
