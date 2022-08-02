@lazyglobal off.

// Lift off then just turn 30 degrees and wait for guidance to become active

// Set some fairly safe defaults
parameter launchAzimuth is 90.
parameter targetInclination is -1.
parameter targetOrbitable is 0.

local pitchOverSpeed is 20.
local pitchOverAngle is 12 * Ship:MaxThrust / (Ship:Mass * Ship:Body:Mu / Body:Position:SqrMagnitude).

local pitchOverCosine is cos(pitchOverAngle).

local lock velocityPitch to 90 - vang(Ship:up:vector, Ship:Velocity:Surface).

// Flight phases
local c_PhaseLiftoff        is 0.
local c_PhasePitchOver      is 1.
local c_PhaseGuidanceReady  is 2.
local c_PhaseGuidanceActive is 3.
local c_PhaseMECO           is 4.
local c_PhaseCoast          is 5.

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
            until guidanceMinV > vcrs(LAS_ShipPos(), Ship:Velocity:Orbit):Mag / Body:Position:Mag
                set guidanceMinV to guidanceMinV + LAS_GuidanceTargetVTheta() * 0.025.
		}
        else
		{
            local east is vcrs(up:vector, north:vector).

            local trig_x is vdot(north:vector, newGuidance).
            local trig_y is vdot(east, newGuidance).

			set guidance to Heading(mod(arctan2(trig_y, trig_x) + 360, 360), min(minPitch, 90 - vang(newGuidance, Ship:Up:Vector))):Vector.
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
				if LAS_StartGuidance(Stage:Number, targetInclination, targetOrbitable, launchAzimuth)
                {
					set flightPhase to c_PhaseGuidanceReady.
                }
				else
                {
                    if guidanceMinV > LAS_GuidanceTargetVTheta() * 0.4
                        set guidanceMinV to LAS_GuidanceTargetVTheta().
                    until guidanceMinV > vcrs(LAS_ShipPos(), Ship:Velocity:Orbit):Mag / Body:Position:Mag
                        set guidanceMinV to guidanceMinV + LAS_GuidanceTargetVTheta() * 0.025.
                }
			}
        }
    }
	
    if Ship:Maxthrust > 0
	{
        local h is vcrs(LAS_ShipPos(), Ship:Velocity:Orbit):Mag.
		local omega is h / Body:Position:SqrMagnitude.
		local grav is Ship:Body:Mu / Body:Position:SqrMagnitude - (omega * omega) * Body:Position:Mag.
		local invTWR is (Ship:Mass * grav) / Ship:MaxThrust.
		set minPitch to arcsin(invTWR) * 1.05.
		set debugStat:Text to "TWR=" + round(1 / invTWR, 2) + " minPitch=" + round(minPitch, 1) + " vTh=" + round(h / Body:Position:Mag, 1) + " / " + round(guidanceMinV, 1).
		
		if Ship:Apoapsis > LAS_TargetPe * 1010 and (flightPhase < c_PhaseGuidanceReady or vdot(guidance, Facing:Vector) < 0.99)
		{
			print "Entering coast mode".
			set Ship:Control:PilotMainThrottle to 0.
            set flightPhase to c_PhaseCoast.
		}
	}
}

until flightPhase >= c_PhaseMECO
{
    checkAscent().
    wait 0.
}

// Release control
set Ship:Control:Neutralize to true.

if flightPhase = c_PhaseCoast
    runpath("/flight/changeperi", LAS_TargetPe, true).
