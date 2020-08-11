@lazyglobal off.

// Lift off then just turn 30 degrees and wait for guidance to become active

// Set some fairly safe defaults
parameter launchAzimuth is 90.

local pitchOverSpeed is 25.
local pitchOverAngle is 10 * Ship:MaxThrust / (Ship:Mass * Ship:Body:Mu / Body:Position:SqrMagnitude).

local pitchOverCosine is cos(pitchOverAngle).

local lock velocityPitch to 90 - vang(Ship:up:vector, Ship:Velocity:Surface).

// Flight phases
local c_PhaseLiftoff        is 0.
local c_PhasePitchOver      is 1.
local c_PhaseGuidanceReady  is 2.
local c_PhaseGuidanceActive is 3.
local c_PhaseMECO           is 4.

local flightPhase is c_PhaseLiftoff.
local guidanceMinV is LAS_GuidanceTargetVTheta() * 0.2.
local minPitch is 30.
local guidance is v(0,0,0).

lock Steering to LookDirUp(Ship:Up:Vector, Ship:Facing:TopVector).

local debugGui is GUI(300, 80).
set debugGui:X to -150.
set debugGui:Y to debugGui:Y - 480.
local mainBox is debugGui:AddVBox().

local debugStat is mainBox:AddLabel("Liftoff").
debugGui:Show().

local function checkAscent
{
    if flightPhase >= c_PhaseGuidanceReady
    {
        LAS_GuidanceUpdate(stage:number).
        
        local newGuidance to LAS_GetGuidanceAim(stage:number).
        // If guidance is valid then it is a unit vector
		
		if newGuidance:SqrMagnitude < 0.9
		{
			set flightPhase to c_PhaseLiftoff.
			set guidanceMinV to guidanceMinV + LAS_GuidanceTargetVTheta() * 0.025.
		}
        else
		{
			set guidance to Heading(launchAzimuth, min(minPitch, 90 - arccos(vdot(newGuidance, Ship:Up:Vector)))):Vector.
			if flightPhase = c_PhaseGuidanceReady
			{
				set flightPhase to c_PhaseGuidanceActive.
				lock Steering to guidance.
				set Ship:Control:PilotMainThrottle to 1.
				print "Orbital guidance mode active".
			}
			else
			{
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
    }
    else if flightPhase = c_PhaseLiftoff
    {
        if Ship:VerticalSpeed >= pitchOverSpeed
        {
            set flightPhase to c_PhasePitchOver.
			lock Steering to Heading(launchAzimuth, max(minPitch, min(90 - pitchOverAngle, velocityPitch))).
        }
	}
	else if flightPhase = c_PhasePitchOver
	{
        if vdot(Ship:SrfPrograde:ForeVector, LAS_ShipPos():Normalized) <= pitchOverCosine
        {
			local r is LAS_ShipPos():Mag.
            local h is vcrs(LAS_ShipPos(), Ship:Velocity:Orbit):Mag.
            local vTheta is h / r.

            if vTheta >= guidanceMinV
			{
				if LAS_StartGuidance(Stage:Number, -1, 0, launchAzimuth)
					set flightPhase to c_PhaseGuidanceReady.
				else
					set guidanceMinV to guidanceMinV + LAS_GuidanceTargetVTheta() * 0.025.
			}
        }
    }
	
	if flightPhase < c_PhaseGuidanceReady
	{
        local h is vcrs(LAS_ShipPos(), Ship:Velocity:Orbit):Mag.
		local omega is h / Body:Position:SqrMagnitude.
		local grav is Ship:Body:Mu / Body:Position:SqrMagnitude - (omega * omega) * Body:Position:Mag.
		local invTWR is (Ship:Mass * grav) / Ship:MaxThrust.
		set minPitch to arcsin(invTWR) * 1.1.
		set debugStat:Text to "TWR=" + round(1 / invTWR, 2) + " minPitch=" + round(minPitch, 1) + " vTh=" + round(h / Body:Position:Mag, 1) + " / " + round(guidanceMinV, 1).
		
		if Ship:Apoapsis > LAS_TargetPe * 1010 and Ship:Control:PilotMainThrottle > 0
		{
			print "Entering coast mode".
			set Ship:Control:PilotMainThrottle to 0.
		}
	}
}

until flightPhase = c_PhaseMECO
{
    checkAscent().
    wait 0.
}

// Release control
set Ship:Control:Neutralize to true.
