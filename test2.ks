@lazyglobal off.

// Wait for unpack
wait until Ship:Unpacked.

local useDiffThrottle is false.

local METString is "".

local function SetupDiffThrottle
{
    parameter mainEngines.

    local pitchTorque is 0.
    local yawTorque is 0.
    
    print "Setup diff throttle".

    for eng in mainEngines
    {
        local starF is vdot(eng:Position, Facing:StarVector).
        local topF is vdot(eng:Position, Facing:TopVector).
        local dist is sqrt(starF ^ 2 + topF ^ 2).
        
        print "engine at " + round(starF, 2) + ", " + round(topF, 2).
        
        if dist > eng:Bounds:Extents:Mag
        {
            local pRatio is topF / dist.
            local yRatio is starF / dist.
            local total is abs(pRatio) + abs(yRatio).
            
            set pRatio to pRatio / total.
            set yRatio to yRatio / total.
            
            print "  pitch ratio: " + round(pRatio, 4).
            print "  yaw ratio: " + round(yRatio, 4).

            set pitchTorque to pitchTorque + eng:PossibleThrust * abs(topF) * 0.1.
            set yawTorque to yawTorque + eng:PossibleThrust * abs(starF) * 0.1.
        }
        else
        {
            print "  neutral".
        }
    }
    
    print "pitch torque: " + round(pitchTorque, 4).
    print "yaw torque:   " + round(yawTorque, 4).
    
    set useDiffThrottle to pitchTorque > 0 and yawTorque > 0.
    
    if useDiffThrottle
    {
        set SteeringManager:PitchTorqueAdjust to pitchTorque.
        set SteeringManager:YawTorqueAdjust to yawTorque.
        print METString + " Differential throttle configured.".
    }
    else
    {
        print METString + " Differential throttle missing required engines.".
    }
}

local alleng is list().
list engines in alleng.

local mainEngines is list().
local s is stage:number + 1.
until mainEngines:length > 0 or s = 0
{
    set s to s - 1.
    for eng in alleng
        if eng:Stage >= s
            mainEngines:Add(eng).
}

SetupDiffThrottle(mainEngines).
