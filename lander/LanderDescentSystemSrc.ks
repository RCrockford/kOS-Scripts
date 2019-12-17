// Lander descent system, for safe(!) landings
// Two phase landing system, approach mode attempts to slow the craft to <20 m/s ground speed and targeted vertical speed in one full thrust burn.
// Descent phase attempts a soft landing on the ground.

@lazyglobal off.

// Wait for unpack
wait until Ship:Unpacked.

// Setup functions
runpathonce(".../FCFuncs").

local DescentEngines is LAS_GetStageEngines().
local enginesIgnited is false.

local function GetCurrentAccel
{
    parameter f.

    // Current ship accel
    local currentThrust is 0.
    for eng in DescentEngines
    {
        if enginesIgnited
            set currentThrust to currentThrust + eng:Thrust / Ship:Control:MainThrottle.
        else
            set currentThrust to currentThrust + eng:PossibleThrust.
    }

    local accel is V(0, currentThrust / Ship:Mass, 0).
    set accel.x to accel.y * vdot(f, LAS_ShipPos():Normalized).
    set accel.z to sqrt(max(accel.y * accel.y - accel.x * accel.x, 1e-4)).

    return accel.
}

if Ship:Status = "Flying" or Ship:Status = "Sub_Orbital"
{
    print "Lander descent system online.".

    // Target height and vertical velocity at approach terminus
    local rT is 50.
    local vT is -3.
    local f is Ship:Facing:ForeVector.

    local steeringControl is false.

    until Ship:GroundSpeed < 20
    {
        local accel is GetCurrentAccel(f).

        // Predicted terminal time
        local t is -Ship:GroundSpeed / accel.z.

        // Commanded vertical acceleration.
        local acgx is 12 * (rT - Alt:Radar) / (t*t) + 6 * (vT + Ship:VerticalSpeed) / t.

        // Calcuate new facing
        local fr is (acgx + Ship:Body:Mu / LAS_ShipPos():SqrMagnitude) / accel.y.
        set fr to min(max(fr, 0), 0.999).

        set f to fr * LAS_ShipPos():Normalized + sqrt(1 - fr * fr) * vxcl(Ship:SrfRetrograde:ForeVector, LAS_ShipPos():Normalized).

        // When the commanded attitude is sufficiently vertical, engage attitude control.
        // Allowing a free float before this reduces thruster propellant consumption.
        if not steeringControl
        {
            if fr > 0.3
            {
                print "Approach mode active".
                set steeringControl to true.
                lock steering to f.
            }
        }
        else
        {
            // If engines aren't lit and we're facing (more or less) in the correct direction, light them.
            if not enginesIgnited and vdot(f, Ship:Facing:ForeVector) > 0.998
            {
                set Ship:Control:MainThrottle to 1.

                for eng in DescentEngines
                {
                    eng:Activate.
                }

                set enginesIgnited to true.
            }
        }

        wait 0.1.
    }

    print "Descent mode active".
    // Touchdown speed
    set vT to 1.

    legs on.

    until Ship:Status = "Landed" or Ship:Status = "Splashed"
    {
        local accel is GetCurrentAccel(f).
        local localGrav is Ship:Body:Mu / LAS_ShipPos():SqrMagnitude.
        local targetAccel is -localGrav * 0.3.

        // Predicted landing time (this is a root of the vertical motion quadratic, with acceleration set to 30% of gravity).
        local t is (-Ship:VerticalSpeed - SQRT(Ship:VerticalSpeed * Ship:VerticalSpeed - 4 * Alt:Radar * targetAccel)) / (2 * targetAccel).

        // Commanded vertical acceleration.
        local acgx is (-((Alt:Radar^1.25) * 0.01 + vT) - Ship:VerticalSpeed) / t.

        // If we're still travelling at reasonable ground speed, fly to cancel it
        if Ship:GroundSpeed > abs(Ship:VerticalSpeed) * 0.1
        {
            // Commanded horziontal acceleration (aim to be horizontally stationary at 2 seconds before touchdown).
            local acgz is Ship:GroundSpeed / MAX(t - 2, 0.1).

            // Calcuate new facing
            local fr is (acgx + localGrav) / accel.y.
            set fr to min(max(fr, 0), 0.999).

            local acg is fr * LAS_ShipPos():Normalized + min(sqrt(1 - fr * fr), acgz) * vxcl(Ship:SrfRetrograde:ForeVector, LAS_ShipPos():Normalized).

            set Ship:Control:MainThrottle to acg:Mag.
            set f to acg:Normalized.
        }
        else
        {
            // Otherwise just use the current retrograde direction.
            set f to Ship:SrfRetrograde:ForeVector.

            set Ship:Control:MainThrottle to (acgx + localGrav) / accel.y.
        }
    }

    // Engines off
    set Ship:Control:MainThrottle to 0.

    for eng in DescentEngines
    {
        eng:Shutdown.
    }

    // Maximum angular velocity before attempting to brake rotation
    local maxAngVel is 1.

    // Maintain attitude control until ship settles to prevent roll overs.
    until Ship:Velocity:Surface:SqrMagnitude < 0.01 and Ship:AngularVel < 0.01
    {
        if vdot(Ship:Facing:ForeVector, LAS_ShipPos():Normalized) < 0.8 or Ship:AngularVel > maxAngVel
        {
            lock steering to LAS_ShipPos():Normalized.
            // a little hysteresis
            set maxAngVel to 0.8.
        }
        else
        {
            set Ship:Control:Neutralize to true.
            // a little hysteresis
            set maxAngVel to 1.
        }
        wait 0.1.
    }

    set Ship:Control:Neutralize to true.

    ladders on.

    print "Landing completed".
}
