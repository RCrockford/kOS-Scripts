@lazyglobal off.

// Lift off then just turn 30 degrees and wait for guidance to become active

// Set some fairly safe defaults
parameter launchAzimuth is 90.

local pitchOverSpeed is 20.
local pitchOverAngle is 30.

local pitchOverCosine is cos(pitchOverAngle).

local lock velocityPitch to 90 - vang(Ship:up:vector, Ship:Velocity:Surface).

// Flight phases
local c_PhaseLiftoff        is 0.
local c_PhasePitchOver      is 1.
local c_PhaseGuidanceReady  is 2.
local c_PhaseGuidanceActive is 3.
local c_PhaseMECO           is 4.

local flightPhase is c_PhaseLiftoff.

local function checkAscent
{
    if flightPhase >= c_PhaseGuidanceReady
    {
        LAS_UpdateGuidance().
        
        local guidance is LAS_GetGuidanceAim().
        // If guidance is valid then it is a unit vector
        
        if flightPhase = c_PhaseGuidanceReady
        {
            if guidance:SqrMagnitude > 0.9
            {
                // Check guidance pitch, when guidance is saying pitch down relative to open loop, engage guidance.
                local upVec is LAS_ShipPos():Normalized.
                if vdot(upVec, guidance) <= vdot(upVec, Ship:Velocity:Surface:Normalized)
                {
                    flightPhase = c_PhaseGuidanceActive.
                    lock Steering to guidance.
                    print "Orbital guidance mode active".
                }
            }
        }
        else
        {
            if guidance:SqrMagnitude > 0.9
                lock Steering to guidance.
            
            if LAS_GuidanceCutOff()
            {
                print "Main engine cutoff".
                set Ship:Control:PilotMainThrottle to 0.
                
                local mainEngines is LAS_GetStageEngines().
                for eng in mainEngines
                {
                    if eng:AllowShutdown
                        eng:Shutdown().
                }
                
                set flightPhase to c_PhaseMECO.
            }
        }
    }
    else if Ship:VerticalSpeed >= pitchOverSpeed
    {
        if vdot(Ship:SrfPrograde:ForeVector, LAS_ShipPos():Normalized) > pitchOverCosine
        {
            set flightPhase to c_PhasePitchOver.
        }
        else
        {
            if LAS_StartGuidance(Stage:Number, -1, 0, launchAzimuth)
                set flightPhase to c_PhaseGuidanceReady.
        }
        lock Steering to Heading(launchAzimuth, min(90 - pitchOverAngle, velocityPitch)).
    }
    else
    {
        // If we're not going up, thrust vertically until we are.
        lock Steering to LookDirUp(Ship:Up:Vector, Ship:Facing:TopVector).
    }
}

until flightPhase = c_PhaseMECO
{
    checkAscent().
    wait 0.
}

// Release control
set Ship:Control:Neutralize to true.
