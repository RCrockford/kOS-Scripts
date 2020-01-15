// Lander direct descent system, for safe(!) landings
// Two phase landing system, braking burn attempts to slow the craft to targeted vertical speed in one full thrust burn.
// Descent phase attempts a soft landing on the ground.

@lazyglobal off.

// Wait for unpack
wait until Ship:Unpacked.

// Setup functions
runpathonce("/FCFuncs").

local DescentEngines is LAS_GetStageEngines().

local burnThrust is 0.
local massFlow is 0.
for eng in DescentEngines
{
    set burnThrust to burnThrust + eng:PossibleThrust.
    set massflow to massFlow + eng:MaxMassFlow.
}

// Estimates burn altitude to brake to a stop at sea level
local function EstimateBrakingBurnAlt
{
    parameter vInitial.
    
    // Initial conditions, 
    local accel is -burnThrust / Ship:Mass.
    local t is -vInitial / accel.
    local prevT is 0.
    // Surface gravity
    local g1 is Ship:Body:Mu / Ship:Body:Radius^2.
    // burn start altitude
    local d is vInitial * t + accel * t^2 / 2.
    
    until abs(t - prevT) < 0.01
    {
        // burn start gravity
        local g0 is Ship:Body:Mu / (d + Ship:Body:Radius)^2.
        
        // final mass
        local mf is Ship:Mass - masFlow * t.
        
        // accel at start and end of burn
        local a0 is (burnThrust / Ship:Mass - g0)^2.
        local a1 is (burnThrust / mf - g1)^2.
        
        // Root of harmonic mean of squares
        set accel to -sqrt(2 * a0 * a1 / (a0 + a1)).
        
        // New time estimate
        set prevT to t.
        set t to -vInitial / accel.
        
        // New distance estimate
        set d to vInitial * t + accel * t^2 / 2.
    }
    
    return d.
}

if Ship:Status = "Flying" or Ship:Status = "Sub_Orbital"
{
    print "Direct descent system online.".
    
    // Calculate when to start braking burn
    local vInitial is Ship:Velocity:Surface:Mag.
    local dInitial is LAS_ShipPos():Mag - Ship:Body:Radius.

    local prevD is 0.
    local d is EstimateBrakingBurnAlt(vInitial).
    
    until abs(d - prevD) < 50
    {
        // coast gravity
        local g is 0.5 * (Ship:Body:Mu / LAS_ShipPos():SqrMagnitude + Ship:Body:Mu / (d + Ship:Body:Radius)^2).
        
        // Root of the equation of ship motion under average gravity
        local t is (-vInitial + sqrt(vInitial^2 - 2 * g * (d - dInitial))) / g.
        
        set d to EstimateBrakingBurnAlt(vInitial + t * g).
    }
    
    // Allow 5000m margin
    set d to d + 5000.
    
    print "Braking alt: " + round(d * 0.001, 1) + "km".
    
    // 10 second alignment margin
    wait until Alt:Radar < d + Ship:Velocity:Surface:Mag * 10.
    
    // Full retrograde burn until vertical velocity is under 50 (or fuel exhaustion).
    print "Beginning braking burn".
    
    LAS_Avionics("activate").
    rcs on.
    lock steering to LookDirUp(SrfRetrograde:Vector, Facing:UpVector).
    
    wait until Alt:Radar < d.

    set Ship:Control:PilotMainThrottle to 1.

    for eng in DescentEngines
    {
        eng:Activate.
    }

    wait until Ship:Velocity:Surface:Mag < 50.
    
    // Jettison braking stage
    set Ship:Control:PilotMainThrottle to 0.
    stage.
    
    // Cache ship bounds
    local shipBounds is Ship:Bounds.
    
    // Calculate new thrust
    set DescentEngines to LAS_GetStageEngines().

    set burnThrust to 0.
    for eng in DescentEngines
    {
        set burnThrust to burnThrust + eng:PossibleThrust.
    }

    print "Descent mode active".
    
    // Touchdown speed
    local vT is 1.

    when Alt:Radar < 100 { legs on. }
    
    // For throttling engines
    //local hFactor is MIN(1+(4-sqrt(minThrottle))/h^0.33,1.4)
    
    // For non-throttling engines
    local twr is burnThrust / (Ship:Mass * Ship:Body:Mu / LAS_ShipPos():SqrMagnitude).
    local hFactor is 1 + 3.4 / h^(0.7 / twr).

    until Ship:Status = "Landed" or Ship:Status = "Splashed"
    {
        local accel is burnThrust / Ship:Mass.
        local localGrav is Ship:Body:Mu / LAS_ShipPos():SqrMagnitude.
        local targetAccel is -localGrav.
        local h is shipBounds:BottomAltRadar.

        // Predicted landing time (this is a root of the vertical motion quadratic, with acceleration set to gravity).
        local t is (-Ship:VerticalSpeed - SQRT(Ship:VerticalSpeed^2 - 2 * h * targetAccel)) / targetAccel.

        // Commanded vertical acceleration.
        local acgx is (-((h^hFactor) * 0.01 + vT) - Ship:VerticalSpeed) / t.
        
        // Thrust if commanded accel is high enough
        local fr is (acgx + localGrav) / accel.
        // A little hysteresis
        if fr > (0.9 - Ship:Control:Fore * 0.05)
            set Ship:Control:Fore to 1.
        else
            set Ship:Control:Fore to 0.
    }
    
    set Ship:Control:Fore to 0.

    // Maximum angular velocity before attempting to brake rotation
    local maxAngVel is 1.

    // Maintain attitude control until ship settles to prevent roll overs.
    until Ship:Velocity:Surface:SqrMagnitude < 0.01 and Ship:AngularVel < 0.01
    {
        if vdot(Ship:Facing:ForeVector, LAS_ShipPos():Normalized) < 0.8 or Ship:AngularVel > maxAngVel
        {
            lock steering to LookDirUp(Up:Vector, Facing:UpVector).
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

    print "Landing completed".
}
