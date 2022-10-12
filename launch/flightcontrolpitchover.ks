clobberbuiltins on.
lazyglobal off.

// Fly minimal AoA until Q < 0.1 and then engage guidance

// Set some fairly safe defaults
parameter pitchOverSpeed is 100.
parameter pitchOverAngle is 4.
parameter launchAzimuth is 90.
parameter targetInclination is -1.
parameter targetOrbitable is 0.
parameter launchParams is lexicon().

runoncepath("/mgmt/diffthrottle").
runoncepath("/mgmt/readoutgui").

local maxQ is Ship:Q.
local maxQset is false.

local kscPos is Ship:GeoPosition.
local coastMode is false.
local coastSteer is false.
local engineSpool is false.
local spoolTimer is 0.

local minPitch is choose 85 if pitchOverAngle < 1e-4 else 70.
local maxPitch is 90.
local lock velocityPitch to max(min(maxPitch, 90 - vang(Ship:up:vector, Ship:Velocity:Surface)), minPitch).
local lock shipPitch to 90 - vang(Ship:up:vector, Ship:facing:forevector).

if minPitch > 80 or not Ship:Crew:Empty
    set launchParams:Loft to true.

// Flight phases
local c_PhaseLiftoff        is 0.
local c_PhasePitchOver      is 1.
local c_PhaseAeroFlight     is 2.
local c_PhaseGuidanceReady  is 3.
local c_PhaseGuidanceActive is 4.
local c_PhaseGuidanceKick   is 5.
local c_PhaseDownrangePower is 6.
local c_PhaseSECO           is 7.
local c_PhaseSuborbCoast    is 8.

local flightPhase is c_PhaseLiftoff.
local flightGuidance is V(0,0,0).
local guidanceThreshold is 0.995.
local guidanceMinV is choose 100 if defined LAS_TargetAp and LAS_TargetAp < 100 else LAS_GuidanceTargetVTheta() * 0.1.     // Minimum tangental speed
local lock nextStageIsGuided to LAS_StageIsGuided(Stage:Number-1).
local compassGuidance is true.

local readoutGui is RGUI_Create(-320, -550).
readoutGui:SetColumnCount(80, list(160, 100)).

local flightStatus is readoutGui:AddReadout("Flight").
local miscStatus is readoutGui:AddReadout("").
local pitchStatus is readoutGui:AddReadout("Pitch").
local QReadout is readoutGui:AddReadout("Q").
local fairingStatus is readoutGui:AddReadout("Fairings").
local QαReadout is readoutGui:AddReadout("Qα").
local engineStatus is readoutGui:AddReadout("Engines").
local DReadout is readoutGui:AddReadout("Downrange").

RGUI_SetText(flightStatus, "Liftoff", RGUI_ColourNormal).
RGUI_SetText(fairingStatus, "locked", "#ff4000").

readoutGui:Show().

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

local function currentTWR
{
    // Calculate current peformance
    local StageEngines is LAS_GetStageEngines().
    local currentThrust is 0.
    for eng in StageEngines
    {
        if eng:Thrust > 0
            set currentThrust to currentThrust + eng:Thrust.
    }
    // Must have 1.5 TWR before guidance
    return currentThrust / (Ship:Mass * Ship:Body:Mu / LAS_ShipPos():SqrMagnitude).
}

local function checkAscent
{
	if flightPhase = c_PhaseGuidanceKick
		return.

    local cutoff is false.
	local guidanceStage is Stage:Number.

	if flightPhase = c_PhaseDownrangePower
	{
		if navmode <> "surface"
			set navmode to "surface".
	
        RGUI_SetText(flightStatus, "Downrange Flight", RGUI_ColourNormal).
        RGUI_SetText(miscStatus, "vT = " + max(launchParams:minSpeed, 0), RGUI_ColourNormal).
        
        if Ship:Altitude > 80000 and launchParams:minSpeed >= 1000
        {
            set minPitch to max(10, 45 - (Ship:Altitude - 80000) / 2000).
            set maxPitch to minPitch.
        }
        
        if rcs
        {
            set Ship:Control:Roll to -1.
        }
	}
    else if flightPhase >= c_PhaseGuidanceReady
    {
		LAS_GuidanceUpdate(guidanceStage).
        
        local guidance is LAS_GetGuidanceAim(guidanceStage).
        local fr is vdot(guidance, Ship:Up:Vector).
		
        if guidance:SqrMagnitude > 0.9
        {
            local targetPitch is 90 - arccos(fr).
            if Ship:Q > 0.001
            {
                // Limit Qα to 0.4
                local maxPitchDiff is 0.4 / Ship:Q.
                set targetPitch to min(max(targetPitch, velocityPitch - maxPitchDiff), velocityPitch + maxPitchDiff).
            }
            if compassGuidance
            {
                if targetInclination < 0
                    set compassGuidance to false.
                else if Ship:GroundSpeed > 3200 and (Stage:Number <= LAS_GuidanceLastStage() or LAS_GuidanceBurnTime() > 60)
                    set compassGuidance to false.
                // Just fly along launch azimuth until 4 km ground speed, then use guidance yaw steering
                set guidance to Heading(launchAzimuth, targetPitch):Vector.
            }
        }
        
        // Make sure dynamic pressure is low enough to start manoeuvres
        if flightPhase = c_PhaseGuidanceReady
        {
            RGUI_SetText(flightStatus, "Guidance Ready", RGUI_ColourNormal).
            RGUI_SetText(miscStatus, choose "Coasting" if coastSteer else "", RGUI_ColourNormal).

            if guidance:SqrMagnitude > 0.9 and Ship:Q < 0.1
            {
                // Check guidance pitch, when guidance is saying pitch down relative to open loop, engage guidance.
                // Alternatively, if Q is at ~7.6 kPa, engage guidance.
                if (fr <= vdot(Ship:Up:Vector, Ship:Facing:Vector) or Ship:Q < 0.075) and (fr >= 0.1 or Stage:Number = LAS_GuidanceLastStage())
                {
                    set flightPhase to c_PhaseGuidanceActive.
                    set flightGuidance to guidance.
                    set guidanceThreshold to 0.995.
                    lock Steering to flightGuidance.
					set kUniverse:TimeWarp:Rate to 2.
                    print METString + " Orbital guidance active".
                }
                else if fr < 0.1 and not coastSteer
                {
                    set coastSteer to true.
					set minPitch to -5.
					lock Steering to Heading(launchAzimuth, choose (velocityPitch - 2) if (Ship:Orbit:Apoapsis < LAS_TargetPe * 900) else Ship:VerticalSpeed * max(-0.004, (1 - Ship:Orbit:Apoapsis / (LAS_TargetPe * 1000)) * 0.01), 0).
                }
            }
        }
        else
        {
            if guidance:SqrMagnitude > 0.9
            {
                RGUI_SetText(flightStatus, "Guidance Active", RGUI_ColourGood).
                RGUI_SetText(miscStatus, choose "Compass" if compassGuidance else "Orbital", RGUI_ColourNormal).
                // Ignore guidance if it's commanding a large change.
                if vdot(guidance, flightGuidance) > guidanceThreshold
                {
                    set guidanceThreshold to 0.995.
                    
                    if engineSpool and MissionTime >= spoolTimer
                        set engineSpool to false.
                    if not engineSpool
                        set flightGuidance to guidance.
                }
                else
                {
                    set guidanceThreshold to guidanceThreshold * 0.995.
                    if guidanceThreshold < 0.9
                        set guidanceThreshold to 0.
                }
            }
			else 
			{
				local stageEngines is LAS_GetStageEngines().
                RGUI_SetText(flightStatus, "Guidance Inactive", RGUI_ColourFault).
				if stageEngines:Length >= 1
                    RGUI_SetText(miscStatus, "F=" + stageEngines[0]:FlameOut, RGUI_ColourFault).
				else
                    RGUI_SetText(miscStatus, "No engine", RGUI_ColourFault).

				if not nextStageIsGuided and stageEngines:Length >= 1 and stageEngines[0]:FlameOut
				{
					local nextStageEngines is LAS_GetStageEngines(Stage:Number-1).
					if nextStageEngines:Length >= 1
					{
						print METString + " Setting up unguided kick".
						set flightPhase to c_PhaseGuidanceKick.
						local kickPitch is LAS_GetPartParam(LAS_GetStageEngines(Stage:Number-1)[0], "p=", 0).
						lock Steering to Heading(mod(360 - latlng(90,0):bearing, 360), kickPitch, 0).
						RGUI_SetText(flightStatus, "Guidance Kick", RGUI_ColourNormal).
                        RGUI_SetText(miscStatus, "h=" + round(mod(360 - latlng(90,0):bearing, 360), 2) + " p=" + round(kickPitch, 1), RGUI_ColourNormal).
					}
					else
					{
						// Assume we're out of fuel.
						set cutoff to true.
					}
				}
			}
            
            if LAS_GuidanceCutOff()
                set cutoff to true.
        }
    }
    else if Ship:AirSpeed >= pitchOverSpeed
    {
        if flightPhase <= c_PhasePitchOver and vang(Ship:SrfPrograde:ForeVector, LAS_ShipPos():Normalized) - pitchOverAngle < -0.1
        {
            if flightPhase < c_PhasePitchOver
            {
				set kUniverse:TimeWarp:Rate to 1.
                RGUI_SetText(flightStatus, "Pitch and roll", RGUI_ColourNormal).
                RGUI_SetText(miscStatus, round(pitchOverAngle, 1) + "° / " + round(launchAzimuth, 1) + "°", RGUI_ColourNormal).
                print METString + " Pitch and roll program: " + round(pitchOverAngle, 2) + "° heading " + round(launchAzimuth, 2) + "°".
                set flightPhase to c_PhasePitchOver.
                local steerAngle is 89.5 - pitchOverAngle.
                if vang(Ship:SrfPrograde:ForeVector, LAS_ShipPos():Normalized) > pitchOverAngle
                    set steerAngle to 90 - pitchOverAngle / 2.
				lock Steering to Heading(launchAzimuth, steerAngle, 0).
            }
        }
        else
        {
            if flightPhase < c_PhaseAeroFlight
            {
				set kUniverse:TimeWarp:Rate to 2.
                print METString + " Minimal AoA flight active".
				lock Steering to Heading(launchAzimuth, min(90 - pitchOverAngle, velocityPitch), 0).
                set flightPhase to c_PhaseAeroFlight.
            }
            
            local r is LAS_ShipPos():Mag.
            local h is vcrs(LAS_ShipPos(), Ship:Velocity:Orbit):Mag.
            local vTheta is h / r.
			
			if Ship:Altitude > 12000
			{
				if not coastMode and launchParams:Coast and Ship:Q < 0.12
				{
					set coastMode to true.
                    set coastSteer to true.
					set minPitch to -5.
					lock Steering to Heading(launchAzimuth, choose (velocityPitch - 2) if (Ship:Orbit:Apoapsis < LAS_TargetPe * 900) else Ship:VerticalSpeed * max(-0.004, (1 - Ship:Orbit:Apoapsis / (LAS_TargetPe * 1000)) * 0.01), 0).
				}
			}
            if minPitch < 80 and minPitch > 0
            {
                if Ship:altitude >= 18266
                    set minPitch to 38 - 3.6 * ((Ship:Altitude / 1000 - 10) / 16) ^ 2.6.
                else
                    set minPitch to 72 - 32 * (Ship:Altitude / 16000) ^ 0.6.
            }
            if Ship:Altitude >= 3000 and Ship:Altitude <= 48000 and not (launchParams:Loft or diffEngines:Length > 0)
            {
                local targetMaxPitch is 90 - 36 * (Ship:Altitude / 16000) ^ 0.5.
                set maxPitch to max(targetMaxPitch, velocityPitch - 1 / Ship:Q).    // Cap Qα at 1
            }
            if defined LAS_TargetAp and LAS_TargetAp < 100
            {
                set minPitch to max(minPitch, 45).
            }

			if coastMode
			{
				RGUI_SetText(flightStatus, "Coast Flight", RGUI_ColourNormal).
                RGUI_SetText(miscStatus, "aT=" + LAS_TargetPe * 0.9 + "km vT=" + round(vTheta, 0) + "/" + round(guidanceMinV, 0), RGUI_ColourNormal).
				for e in ship:engines
				{
					if e:flameout and e:ignition
						e:shutdown.
				}
			}
			else
			{
				RGUI_SetText(flightStatus, "Zero Lift", RGUI_ColourNormal).
                RGUI_SetText(miscStatus, "vT=" + round(vTheta, 0) + "/" + round(guidanceMinV, 0), RGUI_ColourNormal).
			}
            
			local startGuidance is vTheta >= guidanceMinV.
            if LAS_NextStageIsBoosters() or not LAS_StageReady()
                set startGuidance to false.
            if coastMode and startGuidance
                set startGuidance to Stage:Number = LAS_GuidanceLastStage() and (Ship:Altitude > LAS_TargetPe * 900 or Eta:Apoapsis < 60).
			
			if maxQset and Ship:Q < 0.1
			{
				if LAS_HasEscapeSystem
				{
					LAS_EscapeJetisson().
					set startGuidance to false.	// Wait for LES to jetisson.
				}
			}
			
			// Don't setup guidance until we're past maxQ
			if maxQset and startGuidance and Ship:Q < 0.1
			{
				local mainEngines is LAS_GetStageEngines().
				for eng in mainEngines
				{
					if eng:tag:contains("noguide")
						set startGuidance to false.
				}
			
				if startGuidance
				{
					kUniverse:TimeWarp:CancelWarp().
				
					if defined LAS_TargetAp and LAS_TargetAp < 100
					{
                        print METString + " Suborbital boost flight".
						set flightPhase to c_PhaseDownrangePower.
                        local allRCS is list().
                        list rcs in allRCS.
                        for r in allRCS
                        {
                            if r:IsType("Engine") or r:Enabled
                            {
                                rcs on.
                                break.
                            }
                        }
					}
					else if LAS_StartGuidance(guidanceStage, targetInclination, targetOrbitable, launchAzimuth)
					{
						set flightPhase to c_PhaseGuidanceReady.
					}
					else
					{
						until guidanceMinV > vTheta
							set guidanceMinV to guidanceMinV + LAS_GuidanceTargetVTheta() * 0.025.
					}
				}
			}
        }
    }
    
    local pitchColour is "#00ff00".
    local curPitch is 90 - vang(Ship:up:vector, Ship:Velocity:Surface).
    if flightPhase < c_PhaseGuidanceActive
    {
        if curPitch > maxPitch
            set pitchColour to "#fff000".
        else if curPitch < minPitch
            set pitchColour to "#ffa000".
    }
    RGUI_SetText(pitchStatus, round(minPitch, 2) + " < " + round(curPitch, 2) + " < " + round(maxPitch, 2), pitchColour).
    
    if cutoff
    {
        print METString + " Sustainer engine cutoff".
        set Ship:Control:PilotMainThrottle to 0.

        local mainEngines is LAS_GetStageEngines().
        for eng in mainEngines
        {
            if eng:AllowShutdown
                eng:Shutdown().
        }
        
        set flightPhase to c_PhaseSECO.
    }
}

local function checkMaxQ
{
    if not maxQset or Ship:Q > maxQ
    {
        if maxQ > Ship:Q and Ship:Altitude > 5000
        {
            print METString + " Max Q " + round(maxQ * constant:AtmToKPa, 2) + " kPa, pitch: " + round((90 - vang(SrfPrograde:ForeVector, LAS_ShipPos():Normalized)), 2) + "°".
            set maxQset to true.
        }
        else
        {
            set maxQ to Ship:Q.
            set maxQset to false.
        }
    }
}

local RollTqStart is 0.
local RollTqCross is 0.
local RollTqPrev is 0.
local RollTqInstabCount is 0.

local function CheckRollTorque
{
    local rollPos is (SteeringManager:Actuation:y >= 0).
    if RollTqStart = 0
    {
        set RollTqPrev to rollPos.
        set RollTqCross to 0.
        set RollTqStart to Time:Seconds.
    }
    else
    {
        if rollPos <> RollTqPrev and abs(SteeringManager:Actuation:y) >= 0.05
            set RollTqCross to RollTqCross + 1.
        set RollTqPrev to rollPos.
        
        if Time:Seconds - RollTqStart >= 1
        {
            set RollTqStart to 0.
            if RollTqCross >= 3
                set RollTqInstabCount to RollTqInstabCount + 1.
            else
                set RollTqInstabCount to 0.
            if RollTqInstabCount >= 2
            {
                set SteeringManager:RollTorqueFactor to SteeringManager:RollTorqueFactor * 1.4.
                set RollTqInstabCount to 0.
                if flightPhase = c_PhaseLiftoff
                    RGUI_SetText(miscStatus, round(SteeringManager:RollTorqueFactor, 2), RGUI_ColourNormal).
            }
        }
    }
}

local symmetryEngines is list().

local function BalanceThrust
{
    RGUI_SetText(engineStatus, (choose "Spooling" if LAS_StageSpooling() else "Burning") + ", E=" + round(abs(SteeringManager:AngleError), 2), RGUI_ColourNormal).

    if LAS_StageSpooling() or mod(symmetryEngines:Length, 2) = 1
        return.

    if abs(SteeringManager:AngleError) < 2
        return.

    local i is 0.
    for eng in symmetryEngines
    {
        if eng[0]:Thrust < eng[0]:PossibleThrust * 0.1 and eng:Length = 2
        {
            if eng[1]:Ignition
            {
                print METString + " " + eng[0]:config + " #" + i:ToString + (choose " failed" if Addons:TF:Failed(eng[0]) else " burned out").
                print "  shutting down opposing engine to balance thrust".
                eng[0]:Shutdown.
                eng[1]:Shutdown.
            }
        }
        set i to i + 1.
    }
}

local diffEngines is lexicon().

local function DiffThrottleSteering
{
    local reqPitch is SteeringManager:Actuation:X * 0.99.
    local reqYaw is SteeringManager:Actuation:Z * 0.99.

    for eng in diffEngines
    {
        local limit is 1 + eng:pitch * reqPitch + eng:yaw * reqYaw.
        set eng:eng:ThrustLimit to sqrt(max(limit, 0)) * 100.
    }
}

lock Steering to LookDirUp(Ship:Up:Vector, Ship:Facing:TopVector).

set steeringmanager:rollts to 4.
set steeringmanager:maxstoppingtime to 1.

set kUniverse:TimeWarp:Mode to "Physics".
if vdot(Ship:Up:Vector, SrfPrograde:Vector) > 0.9998
    set kUniverse:TimeWarp:Rate to 2.

local stageChecked is false.
local flameoutTimer is MissionTime + 5.

until false
{
    checkMaxQ().
    if flightPhase < c_PhaseSECO
        checkAscent().
    if maxQSet
        LAS_CheckFairings(fairingStatus).
    if flightPhase = c_PhaseSECO
        break.

    if SteeringManager:HasSuffix("Actuation")
        CheckRollTorque().
    
    if diffEngines:Length > 0
        DiffThrottleSteering().
    if diffEngines:Length = 0 or diffEngines:Length > 4
        BalanceThrust().

    if Ship:Q * constant:AtmToKPa >= 1
        RGUI_SetText(QReadout, round(Ship:Q * constant:AtmToKPa, 3) + " kPa", choose RGUI_ColourGood if Ship:Q < 0.1 else RGUI_ColourNormal).
    else
        RGUI_SetText(QReadout, round(1000 * Ship:Q * constant:AtmToKPa, 2) + " Pa", RGUI_ColourGood).
    local Qα is Ship:Q * vang(Facing:Vector, SrfPrograde:Vector).
    RGUI_SetText(QαReadout, round(Qα, 3), choose RGUI_ColourGood if Qα < 1 else (choose RGUI_ColourNormal if Qα < 2 else RGUI_ColourFault)).
    RGUI_SetText(DReadout, round((Ship:GeoPosition:Position - kscPos:Position):Mag * 0.001, 1) + " km", RGUI_ColourNormal).

	if (not coastMode or Ship:Altitude > LAS_TargetPe * 900 or Eta:Apoapsis < 60) and LAS_CheckStaging()
    {
        set stageChecked to false.
        set symmetryEngines to list().
        if Ship:Control:PilotMainThrottle > 0
            set flameoutTimer to MissionTime + 5.
        
        if flightPhase = c_PhaseGuidanceActive
        {
            set engineSpool to true.
            set spoolTimer to MissionTime + 4.
        }
    }
    
    if not stageChecked and LAS_StageReady()
	{
        local mainEngines is list().
        set mainEngines to LAS_GetStageEngines().
        local havePitch is false.
        local haveYaw is false.
        local rcsRoll is false.
        
        set diffEngines to list().
        set SteeringManager:PitchTorqueAdjust to 0.
        set SteeringManager:YawTorqueAdjust to 0.
        
        for eng in mainEngines
        {
            if eng:HasGimbal and eng:Gimbal:Range > 0 
            {
                set havePitch to havePitch or eng:Gimbal:Pitch.
                set haveYaw to haveYaw or eng:Gimbal:Yaw.
                set rcsRoll to eng:tag:contains("rcsroll").
            }
            
            if eng:AllowShutdown and symmetryEngines:Length = 0 and eng:SymmetryCount > 1
            {
                from {local i is 0.} until i >= eng:SymmetryCount step {set i to i + 1.} do
                {
                    symmetryEngines:Add(list(eng:SymmetryPartner(i))).
                }
            }
        }
        
        for eng in symmetryEngines
        {
            local engPos is vxcl(Facing:Vector, eng[0]:Position).
            from {local i is 0.} until i >= eng[0]:SymmetryCount step {set i to i + 1.} do
            {
                local partnerPos is vxcl(Facing:Vector, eng[0]:SymmetryPartner(i):Position).
                local posTest is vdot(engPos, partnerPos).
                if abs(posTest + engPos:Mag^2) < engPos:Mag^2 * 0.01
                {
                    eng:Add(eng[0]:SymmetryPartner(i)).
                    break.
                }
            }
        }

        if havePitch and haveYaw
        {
            if rcsRoll
                rcs on.
            else
                rcs off.
        }
        else
        {
            local allRCS is list().
            list rcs in allRCS.
            for r in allRCS
            {
                if r:IsType("Engine") or r:Enabled
                {
                    set havePitch to true.
                    set haveYaw to true.
                    rcs on.
                    break.
                }
            }
        }
        
        if (not havePitch or not haveYaw) and mainEngines:Length > 1
        {
            set diffEngines to SetupDiffThrottle(mainEngines).
            set havePitch to diffEngines:Length > 0.
            set haveYaw to diffEngines:Length > 0.
            if diffEngines:Length > 0
            {
                print METString + " Using differential throttle (" + diffEngines:Length + " engines).".
            }
        }
        
        if (not havePitch or not haveYaw) and flightPhase < c_PhaseGuidanceKick
        {
            print METString + " No attitude control, aborting guidance.".
            break.
        }
        
        // Reset torque
        set SteeringManager:RollTorqueFactor to 2.
        set RollTqStart to 0.
        
        set stageChecked to true.
	}
    
    if LAS_TargetPe < 100 and MissionTime > flameoutTimer and LAS_LastPoweredStage()
    {
   		local mainEngines is LAS_GetStageEngines().
        local flamedOut is true.
		for eng in mainEngines
		{
			if not eng:FlameOut or not eng:Ignition
            {
				set flamedOut to false.
                break.
            }
		}
        
        if launchParams:minSpeed >= 1000 and Ship:Altitude >= 150000
        {
            if Velocity:Orbit:Mag > launchParams:minSpeed and Velocity:Surface:Mag > launchParams:minSpeed
            {
                set flamedOut to true.
                for eng in mainEngines
                {
                    eng:Shutdown.
                }
            }
        }

        if flamedOut
        {
            set flightPhase to c_PhaseSuborbCoast.
            print METString + " Sustainer engine burnout".
            set Ship:Control:PilotMainThrottle to 0.
            unlock Steering.
            set Ship:Control:Neutralize to true.
            rcs off.
            set flameoutTimer to MissionTime + 1e10.
        }
        else
            set flameoutTimer to MissionTime + 0.5.
    }
    
    // Reduce power consumption when coasting
    if flightPhase = c_PhaseSuborbCoast
    {
        RGUI_SetText(flightStatus, "Suborbital coast", RGUI_ColourNormal).
        RGUI_SetText(miscStatus, "", RGUI_ColourNormal).
        wait 0.5.
    }
    else
    {
        wait 0.
    }
}

// Release control
unlock Steering.
set Ship:Control:Neutralize to true.
steeringmanager:resettodefault().

if defined LAS_TargetSMA
	print METString + " Final latitude: " + round(Ship:Latitude, 2).
    
LAS_DeployEquipment().

ClearGUIs().

// Switch off avionics
LAS_Avionics("shutdown").