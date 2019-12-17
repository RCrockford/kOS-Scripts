lazyglobal off.

// Fly minimal AoA until Q < 0.1 and then engage guidance

// Set some fairly safe defaults
parameter pitchOverSpeed is 100.
parameter pitchOverAngle is 4.
parameter launchAzimuth is 90.
parameter targetInclination is -1.
parameter targetOrbitable is 0.

local pitchOverCosine is cos(pitchOverAngle).
local maxQ is Ship:Q.
local maxQset is false.

local lock velocityPitch to 90 - vang(Ship:up:vector, Ship:Velocity:Surface).
local lock shipPitch to 90 - vang(Ship:up:vector, Ship:facing:forevector).

// Flight phases
local c_PhaseLiftoff        is 0.
local c_PhasePitchOver      is 1.
local c_PhaseAeroFlight     is 2.
local c_PhaseGuidanceReady  is 3.
local c_PhaseGuidanceActive is 4.
local c_PhaseGuidanceKick   is 5.
local c_PhaseMECO           is 6.
local c_PhaseSuborbCoast    is 7.

local flightPhase is c_PhaseLiftoff.
local flightGuidance is V(0,0,0).
local guidanceThreshold is 0.995.
local nextStageIsGuided is true.

local suborbPitchPID is pidloop(1, 0.1, 1, -750, 250).

local function angle_off
{
	parameter a1, a2. // how far off is a2 from a1.

	local ret_val is a2 - a1.
	if ret_val < -180 {
		set ret_val to ret_val + 360.
	} else if ret_val > 180 {
		set ret_val to ret_val - 360.
	}
	return ret_val.
}

local function checkAscent
{
    local cutoff is false.

    if flightPhase = c_PhaseGuidanceKick
    {
        // unguided kick stage, just check for valid Pe
        if Ship:Orbit:Periapsis >= (LAS_TargetPe * 1000 - 250) and Ship:Orbit:Apoapsis >= (LAS_TargetAp * 1000)
        {
            set cutoff to true.
        }
    }
	else if flightPhase >= c_PhaseGuidanceReady
    {
        LAS_GuidanceUpdate().
        
        local guidance is LAS_GetGuidanceAim().
        // If guidance is valid then it is a unit vector
        
        // Make sure dynamic pressure is low enough to start manoeuvres
        if flightPhase = c_PhaseGuidanceReady
        {
            if guidance:SqrMagnitude > 0.9 and Ship:Q < 0.1
            {
                // Check guidance pitch, when guidance is saying pitch down relative to open loop, engage guidance.
                // Alternatively, if Q is at ~3 kPa, engage guidance.
                local upVec is LAS_ShipPos():Normalized.
                if vdot(upVec, guidance) <= vdot(upVec, Ship:Velocity:Surface:Normalized) or Ship:Q < 0.05
                {
                    set flightPhase to c_PhaseGuidanceActive.
                    set flightGuidance to guidance.
                    set guidanceThreshold to 0.995.
                    lock Steering to flightGuidance.
                    print "Orbital guidance mode active".
                }
            }
        }
        else
        {
            if guidance:SqrMagnitude > 0.9
            {
                // Ignore guidance if it's commanding a large change.
                if vdot(guidance, flightGuidance) > guidanceThreshold
                {
                    set flightGuidance to guidance.
                    set guidanceThreshold to 0.995.
                }
                else
                {
                    set guidanceThreshold to guidanceThreshold * 0.995.
                    if guidanceThreshold < 0.9
                        set guidanceThreshold to 0.
                }
            }
            
            if not nextStageIsGuided
            {
                if LAS_GetStageBurnTime() < 2
                {
                    // Turn prograde for kick
                    lock Steering to Ship:Velocity:Orbit.
                    set flightPhase to c_PhaseGuidanceKick.
                    print "Setting up unguided kick".
                }
            }
            
            if LAS_GuidanceCutOff() and Ship:Orbit:Periapsis >= (LAS_TargetPe * 1000 - 250)
                set cutoff to true.
        }
    }
    else if Ship:AirSpeed >= pitchOverSpeed
    {
        if vdot(Ship:SrfPrograde:ForeVector, LAS_ShipPos():Normalized) > pitchOverCosine
        {
            if flightPhase < c_PhasePitchOver
            {
                print "Beginning pitch over".
                set flightPhase to c_PhasePitchOver.
            }
            lock Steering to Heading(launchAzimuth, min(90 - pitchOverAngle, velocityPitch)).
        }
        else
        {
            if flightPhase < c_PhaseAeroFlight
            {
                print "Minimal AoA flight mode active".
				lock Steering to Heading(launchAzimuth, min(90 - pitchOverAngle, velocityPitch)).
                set flightPhase to c_PhaseAeroFlight.
            }
			
			// Don't setup guidance until we're past maxQ
            if maxQset and Ship:Q < 0.1
            {
				kUniverse:TimeWarp:CancelWarp().
			
				if LAS_StartGuidance(targetInclination, targetOrbitable)
					set flightPhase to c_PhaseGuidanceReady.
            }
        }
    }
    
    if cutoff
    {
        print "Sustainer engine cutoff".
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

local function checkMaxQ
{
    if not maxQset
    {
        if maxQ > Ship:Q and Ship:Altitude > 5000
        {
            print "Max Q " + round(maxQ * constant:AtmToKPa, 2) + " kPa.".
            set maxQset to true.
        }
        else
        {
            set maxQ to Ship:Q.
        }
    }
}

local PL_Fairings is list().
local PL_FairingsJettisoned is false.
local PL_PanelsExtended is false.

local function checkPayload
{
    if not maxQset
        return.

    if not PL_FairingsJettisoned
    {
        if Ship:Q < 0.001
        {
            // Jettison fairings
			local jettisoned is false.
            for f in PL_Fairings
            {
                if f:HasEvent("jettison fairing")
				{
                    f:DoEvent("jettison fairing").
					set jettisoned to true.
				}
            }
            
            if jettisoned
                print "Fairings jettisoned".
            
            set PL_FairingsJettisoned to true.
        }
    }
    else if not PL_PanelsExtended
    {
        if Ship:Q < 1e-5
        {
            Panels on.
            set PL_PanelsExtended to true.
        }
    }
}

lock Steering to Heading(launchAzimuth, 90).

local stageChecked is false.
local flameoutTimer is MissionTime + 5.

for shipPart in Ship:Parts
{
    if shipPart:HasModule("ProceduralFairingDecoupler")
    {
        PL_Fairings:Add(shipPart:GetModule("ProceduralFairingDecoupler")).
    }
}

until flightPhase = c_PhaseMECO
{
    checkMaxQ().
    if flightPhase < c_PhaseMECO
        checkAscent().
    checkPayload().
    
    if LAS_CheckStaging()
    {
        // Reset torque
        set SteeringManager:RollTorqueFactor to 1.
        set stageChecked to false.
        set flameoutTimer to MissionTime + 5.
    }
    
    if not stageChecked and LAS_FinalStage()
	{
		local haveControl is false.
		local mainEngines is LAS_GetStageEngines().
		for eng in mainEngines
		{
			if eng:HasGimbal
            {
				set haveControl to true.
                break.
            }
		}
        
        if not haveControl
        {
            local stageRCS is LAS_GetStageParts(Stage:Number, "ModuleRCSFX").
            for p in stageRCS
            {
                if p:GetModule("ModuleRCSFX"):GetField("RCS")
                {
                    set haveControl to true.
                    break.
                }
            }
        }
		
		if not haveControl
		{
			print "No attitude control, aborting guidance.".
            if flightPhase = c_PhaseGuidanceActive
                set flightPhase to c_PhaseGuidanceKick.
            else
                break.
		}
        
        set stageChecked to true.
	}
    
    if flightPhase < c_PhaseMECO and LAS_TargetPe < 100 and MissionTime > flameoutTimer
    {
   		local mainEngines is LAS_GetStageEngines().
        local flamedOut is true.
		for eng in mainEngines
		{
			if not eng:FlameOut
            {
				set flamedOut to false.
                break.
            }
		}

        if flamedOut
        {
            set flightPhase to c_PhaseSuborbCoast.
            print "Sustainer engine burnout".
            set Ship:Control:PilotMainThrottle to 0.
            unlock Steering.
            set Ship:Control:Neutralize to true.
            rcs off.
            ClearGUIs().
        }
        
        set flameoutTimer to MissionTime + 0.5.
    }
    
    wait 0.
}

// Release control
unlock Steering.
set Ship:Control:Neutralize to true.

ClearGUIs().

if flightPhase = c_PhaseMECO
{
	runpath("0:/flight/InstallManoeuvre.ks").
	switch to 1.
}