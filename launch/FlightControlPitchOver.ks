@lazyglobal off.

// Fly minimal AoA until Q < maxQ*0.1 and then engage guidance

// Set some fairly safe defaults
parameter pitchOverSpeed is 100.
parameter pitchOverAngle is 4.
parameter launchAzimuth is 90.
parameter targetInclination is -1.

local pitchOverCosine is cos(pitchOverAngle).
local maxQ is Ship:Q.
local maxQset is false.

local lock velocityPitch to 90 - vang(Ship:up:vector, Ship:Velocity:Surface).

// Flight phases
local c_PhaseLiftoff        is 0.
local c_PhasePitchOver      is 1.
local c_PhaseAeroFlight     is 2.
local c_PhaseGuidanceReady  is 3.
local c_PhaseGuidanceActive is 4.
local c_PhaseGuidanceSubOrb is 5.
local c_PhaseMECO           is 6.

local flightPhase is c_PhaseLiftoff.

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
    // If we're launching to a particular inclination, check for dogleg.
    if flightPhase < c_PhaseGuidanceActive and targetInclination >= 0
    {
        if angle_off(Ship:Orbit:Inclination, targetInclination) < 0.1
        {
            set launchAzimuth to 90 - targetInclination.
            if launchAzimuth < 0
                set launchAzimuth to launchAzimuth + 360.
            lock Steering to Heading(launchAzimuth, velocityPitch).
        }
    }

	if flightPhase = c_PhaseGuidanceSubOrb
    {
        lock Steering to Ship:Velocity:Surface.
	}
    else if flightPhase >= c_PhaseGuidanceReady
    {
        LAS_GuidanceUpdate().
        
        local guidance is LAS_GetGuidanceAim().
        // If guidance is valid then it is a unit vector
        
        // Make sure dynamic pressure is low enough to start manoeuvres
        if flightPhase = c_PhaseGuidanceReady
        {
            if guidance:SqrMagnitude > 0.9 and Ship:Q < 0.05
            {
                // Check guidance pitch, when guidance is saying pitch down relative to open loop, engage guidance.
                // Alternatively, if Q is at ~1 kPa, engage guidance.
                local upVec is LAS_ShipPos():Normalized.
                if vdot(upVec, guidance) <= vdot(upVec, Ship:Velocity:Surface:Normalized) or Ship:Q < 0.01
                {
                    set flightPhase to c_PhaseGuidanceActive.
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
                set Ship:Control:MainThrottle to 0.
                
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
    else if Ship:AirSpeed >= pitchOverSpeed
    {
        if vdot(Ship:SrfPrograde:ForeVector, LAS_ShipPos():Normalized) > pitchOverCosine
        {
            if flightPhase < c_PhasePitchOver
            {
                print "Beginning pitch over".
                set flightPhase to c_PhasePitchOver.
            }
            lock Steering to Heading(launchAzimuth, min(90 - pitchOverAngle + 0.5, velocityPitch)).
        }
        else
        {
            if flightPhase < c_PhaseAeroFlight
            {
                print "Minimal AoA flight mode active".
                set flightPhase to c_PhaseAeroFlight.
            }

            // Don't setup guidance until we're past maxQ
            if maxQset and Ship:Q < 0.16
            {
				if LAS_TargetPe < 100000
				{					
					set flightPhase to c_PhaseGuidanceSubOrb.
                    print "Suborbital guidance mode active".
				}
				else
				{
					LAS_StartGuidance().
					set flightPhase to c_PhaseGuidanceReady.
				}
            }
        }
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
        if Ship:Q < 1e-5
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
        if Ship:Q < 2e-6
        {
            Panels on.
            set PL_PanelsExtended to true.
        }
    }
}

lock Steering to Heading(launchAzimuth, 90).

// Turn RCS on so attitude thrusters work.
rcs on.

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
    checkAscent().
    checkPayload().
    
    LAS_CheckStaging().
	
	if LAS_FinalStage()
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
            local stageParts is LAS_GetStageParts().
            for p in stageParts
            {
                if p:HasModule("ModuleRCS")
                {
                    if p:GetModule("ModuleRCS"):GetField("Enabled") = "true"
                    {
                        set haveControl to true.
                        break.
                    }
                }
            }
        }
		
		if not haveControl
		{
			print "No attitude control, aborting guidance.".
			set Ship:Control:PilotMainThrottle to 1.
			break.
		}
	}
    
    wait 0.
}

// Release control
unlock steering.
set Ship:Control:Neutralize to true.

if flightPhase = c_PhaseMECO
{
	runpath("0:/flight/InstallFlightPack.ks").
	switch to 1.
}