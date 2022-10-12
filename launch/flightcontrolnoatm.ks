@clobberbuiltins on.
@lazyglobal off.

// Lift off then just turn 30 degrees and wait for guidance to become active

// Set some fairly safe defaults
parameter launchAzimuth is 90.
parameter targetInclination is -1.
parameter targetOrbitable is 0.

runoncepath("/mgmt/readoutgui").

local pitchOverSpeed is 12.
local pitchOverAngle is 10 * Ship:MaxThrust / (Ship:Mass * Ship:Body:Mu / Body:Position:SqrMagnitude).

if core:tag:contains("softpitch")
    set pitchOverAngle to 10.

local pitchOverCosine is cos(pitchOverAngle).

local lock velocityPitch to 90 - vang(Ship:up:vector, Ship:Velocity:Surface).

// Flight phases
local c_PhaseLiftoff        is 0.
local c_PhasePitchOver      is 1.
local c_PhaseGuidanceReady  is 2.
local c_PhaseGuidanceActive is 3.
local c_PhaseMECO           is 4.

local flightPhase is c_PhaseLiftoff.
local guidanceMinV is LAS_GuidanceTargetVTheta() * 0.1.
local minPitch is 30.
local pitchAdj is 1.
local guidance is v(0,0,0).

lock Steering to LookDirUp(Ship:Up:Vector, Ship:Facing:TopVector).

local readoutGui is RGUI_Create(-320, -500).
readoutGui:SetColumnCount(80, list(160, 100)).

local flightStatus is readoutGui:AddReadout("Flight").
local twrStatus is readoutGui:AddReadout("TWR").
local pitchStatus is readoutGui:AddReadout("Pitch").
local vThReadout is readoutGui:AddReadout("vTh").

RGUI_SetText(flightStatus, "Liftoff", RGUI_ColourNormal).

readoutGui:Show().

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
                RGUI_SetText(flightStatus, "Guidance Active", RGUI_ColourGood).
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
            RGUI_SetText(flightStatus, "Pitch and roll", RGUI_ColourNormal).
			lock Steering to Heading(launchAzimuth, max(minPitch, min(90 - pitchOverAngle, velocityPitch + pitchAdj))).
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
                    RGUI_SetText(flightStatus, "Guidance Ready", RGUI_ColourNormal).
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
		set minPitch to arcsin(invTWR) * 1.1.
        set pitchAdj to max(2.5 - 0.5 / invTWR, -0.5).

        RGUI_SetText(pitchStatus, round(minPitch, 2) + " < " + round(velocityPitch, 2), choose RGUI_ColourGood if velocityPitch > minPitch else RGUI_ColourNormal).
        RGUI_SetText(twrStatus, round(1 / invTWR, 2):ToString(), RGUI_ColourNormal).
        RGUI_SetText(vThReadout, round(h / Body:Position:Mag, 1) + " / " + round(guidanceMinV, 1), RGUI_ColourNormal).
	}
}

until flightPhase >= c_PhaseMECO
{
    checkAscent().
    wait 0.
}

// Release control
unlock Steering.
set Ship:Control:Neutralize to true.

ClearGUIs().

LAS_Avionics("shutdown").
