lazyglobal off.

// Fly minimal AoA until Q < 0.1 and then engage guidance

// Set some fairly safe defaults
parameter pitchOverSpeed is 100.
parameter pitchOverAngle is 4.
parameter launchAzimuth is 90.
parameter targetInclination is -1.
parameter targetOrbitable is 0.
parameter canCoast is false.
parameter canLoft is false.

local maxQ is Ship:Q.
local maxQset is false.

local kscPos is Ship:GeoPosition.
local coastMode is false.
local engineSpool is false.
local spoolTimer is 0.

local minPitch is choose 85 if pitchOverAngle < 1e-4 else 38.
local maxPitch is 90.
local lock velocityPitch to max(min(maxPitch, 90 - vang(Ship:up:vector, Ship:Velocity:Surface)), minPitch).
local lock shipPitch to 90 - vang(Ship:up:vector, Ship:facing:forevector).

if minPitch > 60
    set canLoft to true.

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
local guidanceMinV is 900.     // Minimum tangental speed
local lock nextStageIsGuided to LAS_StageIsGuided(Stage:Number-1).

local debugGui is GUI(300, 80).
set debugGui:X to -160.
set debugGui:Y to debugGui:Y - 550.
local mainBox is debugGui:AddVBox().

local flightStatus is mainBox:AddLabel("Liftoff").
local pitchStatus is mainBox:AddLabel("").
local fairingStatus is mainBox:AddLabel("Fairings: <color=#ff4000>locked</color>").
local equipmentStatus is mainBox:AddLabel("Equipment: <color=#ff4000>locked</color>").
debugGui:Show().

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
	if flightPhase = c_PhaseGuidanceKick
		return.

    local cutoff is false.
	local guidanceStage is Stage:Number.

	if flightPhase = c_PhaseDownrangePower
	{
		if navmode <> "surface"
			set navmode to "surface".
	
		if Ship:Orbit:Apoapsis > 250000
		{
			local r is LAS_ShipPos():Mag.
			local r2 is LAS_ShipPos():SqrMagnitude.
			local rVec is LAS_ShipPos():Normalized.
			local hVec is vcrs(LAS_ShipPos(), Ship:Velocity:Orbit):Normalized.
			local downtrack is vcrs(hVec, rVec).
			local omega is vdot(Ship:Velocity:Orbit, downtrack) / r.
			
			// Calculate current peformance
			local StageEngines is LAS_GetStageEngines().
			local currentThrust is 0.
			local fullThrust is 0.
			for eng in StageEngines
			{
				if eng:Thrust > 0
				{
					set currentThrust to currentThrust + eng:Thrust.
					set fullThrust to fullThrust + eng:PossibleThrust.
				}
			}
			
			if currentThrust > fullThrust * 0.98
			{
				local accel is currentThrust / Ship:Mass.
				local fr is (Ship:Body:Mu / r2 - (omega * omega) * r) / accel.
		
				set fr to min(fr, 0.5).
				set flightGuidance to fr * rVec + sqrt(1 - fr * fr) * downtrack.
				
				lock Steering to flightGuidance.
				
				set flightStatus:Text to "Downrange Boost, fr=" + round(fr, 3) + " D=" + round((Ship:GeoPosition:Position - kscPos:Position):Mag * 0.001, 0) + "km".
			}
            else
            {
                set flightStatus:Text to "Downrange Boost, D=" + round((Ship:GeoPosition:Position - kscPos:Position):Mag * 0.001, 0) + "km".
            }
		}
		else			
			set flightStatus:Text to "Downrange Flight, Q=" + round(1000 * Ship:Q * constant:AtmToKPa, 2) + " Pa D=" + round((Ship:GeoPosition:Position - kscPos:Position):Mag * 0.001, 0) + "km".
	}
    else if flightPhase >= c_PhaseGuidanceReady
    {
		LAS_GuidanceUpdate(guidanceStage).
        
        local guidance is LAS_GetGuidanceAim(guidanceStage).
		
		if Stage:Number > LAS_GuidanceLastStage() or (Ship:GroundSpeed < 4000 and guidance:SqrMagnitude > 0.9)
		{
			// Just fly along launch azimuth until 4 km ground speed, then use guidance yaw steering
			set guidance to Heading(launchAzimuth, 90 - arccos(vdot(guidance, Ship:Up:Vector))):Vector.
		}
        
        // Make sure dynamic pressure is low enough to start manoeuvres
        if flightPhase = c_PhaseGuidanceReady
        {
			local fr is vdot(guidance, Ship:Up:Vector).
            set flightStatus:Text to "Guidance Ready, Q=" + round(1000 * Ship:Q * constant:AtmToKPa, 2) + " Pa fr=" + round(fr, 3).
				
            if guidance:SqrMagnitude > 0.9 and Ship:Q < 0.1
            {
                // Check guidance pitch, when guidance is saying pitch down relative to open loop, engage guidance.
                // Alternatively, if Q is at ~3 kPa, engage guidance.
                if fr <= vdot(Ship:Up:Vector, Ship:Facing:Vector) or Ship:Q < 0.075
                {
                    set flightPhase to c_PhaseGuidanceActive.
                    set flightGuidance to guidance.
                    set guidanceThreshold to 0.995.
                    lock Steering to flightGuidance.
					set kUniverse:TimeWarp:Rate to 2.
                    print "Orbital guidance mode active".
                }
            }
        }
        else
        {
            if guidance:SqrMagnitude > 0.9
            {
				set flightStatus:Text to "Guidance Active: M=" + round(guidance:SqrMagnitude, 3) + " Q=" + round(1000 * Ship:Q * constant:AtmToKPa, 2) + " Pa".
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
				if stageEngines:Length >= 1
					set flightStatus:Text to "Guidance Inactive: G=" + nextStageIsGuided + " F=" + stageEngines[0]:FlameOut + " N=" + stageEngines[0]:Name.
				else
					set flightStatus:Text to "Guidance Inactive: G=" + nextStageIsGuided + " No engine".

				if not nextStageIsGuided and stageEngines:Length >= 1 and stageEngines[0]:FlameOut
				{
					local nextStageEngines is LAS_GetStageEngines(Stage:Number-1).
					if nextStageEngines:Length >= 1
					{
						print "Setting up unguided kick".
						set flightPhase to c_PhaseGuidanceKick.
						local kickPitch is LAS_GetPartParam(LAS_GetStageEngines(Stage:Number-1)[0], "p=", 0).
						lock Steering to Heading(mod(360 - latlng(90,0):bearing, 360), kickPitch, 0).
						set flightStatus:Text to "Guidance Kick: h=" + round(mod(360 - latlng(90,0):bearing, 360), 2) + " p=" + round(kickPitch, 1).
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
        if flightPhase <= c_PhasePitchOver and abs(vang(Ship:SrfPrograde:ForeVector, LAS_ShipPos():Normalized) - pitchOverAngle) > 0.25
        {
            if flightPhase < c_PhasePitchOver
            {
				set kUniverse:TimeWarp:Rate to 1.
				set flightStatus:Text to "Pitch and roll program: " + round(pitchOverAngle, 2) + "° heading " + round(launchAzimuth, 2) + "°".
                print flightStatus:Text.
                set flightPhase to c_PhasePitchOver.
                local steerAngle is 90 - pitchOverAngle.
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
                print "Minimal AoA flight mode active".
				lock Steering to Heading(launchAzimuth, min(90 - pitchOverAngle, velocityPitch), 0).
                set flightPhase to c_PhaseAeroFlight.
            }
            
            local r is LAS_ShipPos():Mag.
            local h is vcrs(LAS_ShipPos(), Ship:Velocity:Orbit):Mag.
            local vTheta is h / r.
			
			if Ship:Altitude > 12000
			{
				if not coastMode and canCoast and Ship:Q < 0.12
				{
					set coastMode to true.
					set minPitch to -5.
					lock Steering to Heading(launchAzimuth, choose (velocityPitch - 2) if (Ship:Orbit:Apoapsis < LAS_TargetPe * 800) else Ship:VerticalSpeed * max(-0.004, (1 - Ship:Orbit:Apoapsis / (LAS_TargetPe * 1000)) * 0.01), 0).
				}
				else
                {
                    if Ship:Q < 0.3 and not LAS_HasEscapeSystem and not canLoft
                        set maxPitch to 60.
                    set minPitch to 38 - 3.6 * ((Ship:Altitude / 1000 - 10) / 16) ^ 2.6.
				}
			}

			if coastMode
			{
				set flightStatus:Text to "Coast Flight, aT=" + LAS_TargetPe * 0.8 + "km vT=" + round(vTheta, 0) + "/" + round(guidanceMinV, 0).
				local eng is list().
				list engines in eng.
				for e in eng
				{
					if e:flameout and e:ignition
						e:shutdown.
				}
			}
			else
			{
				set flightStatus:Text to "Aero Flight, Q=" + round(Ship:Q * constant:AtmToKPa, 2) + " kPa vT=" + round(vTheta, 0) + "/" + round(guidanceMinV, 0).
			}
            
			local startGuidance is vTheta > guidanceMinV.
            if LAS_NextStageIsBoosters
                set startGuidance to false.
            if coastMode and startGuidance
                set startGuidance to LAS_GuidanceLastStage() and (Ship:Altitude > LAS_TargetPe * 800 or Eta:Apoapsis < 60).
			
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
						set flightPhase to c_PhaseDownrangePower.
					}
					else if LAS_StartGuidance(guidanceStage, targetInclination, targetOrbitable, launchAzimuth)
					{
						set flightPhase to c_PhaseGuidanceReady.
					}
					else
					{
						until guidanceMinV > vTheta
							set guidanceMinV to guidanceMinV + 150.
					}
				}
			}
        }
    }
    
    local pitchColour is "<color=" + (choose "#00ff00" if (velocityPitch < maxPitch and velocityPitch > minPitch) or flightPhase >= c_PhaseGuidanceActive else "#ffa000") + ">".
    set pitchStatus:Text to "Pitch control: " + pitchColour + round(minPitch, 2) + " < " + round(90 - vang(Ship:up:vector, Ship:Velocity:Surface), 2) + " < " + round(maxPitch, 2) + "</color>".
    
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
        
        set flightPhase to c_PhaseSECO.
    }
}

local function checkMaxQ
{
    if not maxQset or Ship:Q > maxQ
    {
        if maxQ > Ship:Q and Ship:Altitude > 5000
        {
            print "Max Q " + round(maxQ * constant:AtmToKPa, 2) + " kPa, pitch: " + round((90 - vang(SrfPrograde:ForeVector, LAS_ShipPos():Normalized)), 2) + "°".
            set maxQset to true.
        }
        else
        {
            set maxQ to Ship:Q.
            set maxQset to false.
        }
    }
}

lock Steering to LookDirUp(Ship:Up:Vector, Ship:Facing:TopVector).

set steeringmanager:rollts to 1.

set kUniverse:TimeWarp:Mode to "Physics".
if vdot(Ship:Up:Vector, SrfPrograde:Vector) > 0.9998
    set kUniverse:TimeWarp:Rate to 2.

local stageChecked is false.
local flameoutTimer is MissionTime + 5.

until false
{
    checkMaxQ().
    checkAscent().
    if maxQSet
        LAS_CheckPayload(fairingStatus, equipmentStatus).
    if flightPhase = c_PhaseSECO
        break.
	
	if (not coastMode or Ship:Altitude > LAS_TargetPe * 800 or Eta:Apoapsis < 60) and LAS_CheckStaging()
    {
        set stageChecked to false.
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
		if LAS_FinalStage()
		{
			set mainEngines to LAS_GetStageEngines().
			local haveControl is false.
			local rcsRoll is false.
			for eng in mainEngines
			{
				if eng:HasGimbal
				{
					set haveControl to true.
					set rcsRoll to eng:tag:contains("rcsroll").
					break.
				}
			}
			
			if haveControl
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
					if r:Enabled
					{
						set haveControl to true.
						rcs on.
						break.
					}
				}
			}
			
			if not haveControl and flightPhase < c_PhaseGuidanceKick
			{
				print "No attitude control, aborting guidance.".
				break.
			}
			set SteeringManager:RollTorqueFactor to 2.
		}
		else
		{
			list engines in mainEngines.
			local torqueFactor is 2.
			for eng in mainEngines
			{
				if eng:ignition and eng:Name = "ROE-RD108"
				{
					set torqueFactor to 12.
					break.
				}
				if eng:ignition and eng:Name:contains("vernier")
				{
					set torqueFactor to 16.
					break.
				}
			}
			// Reset torque
			set SteeringManager:RollTorqueFactor to torqueFactor.
		}
        
        set stageChecked to true.
	}
    
    if LAS_TargetPe < 100 and MissionTime > flameoutTimer
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

        if flamedOut
        {
            set flightPhase to c_PhaseSuborbCoast.
            print "Sustainer engine burnout".
            set Ship:Control:PilotMainThrottle to 0.
            unlock Steering.
            set Ship:Control:Neutralize to true.
            rcs off.
        }
        
        set flameoutTimer to MissionTime + 0.5.
    }
    
    // Reduce power consumption when coasting
    if flightPhase = c_PhaseSuborbCoast
    {
        set flightStatus:Text to "Suborbital coast, D=" + round((Ship:GeoPosition:Position - kscPos:Position):Mag * 0.001, 0) + "km".
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
	print "Final latitude: " + round(Ship:Latitude, 2).
    
LAS_EnableAllEC().

ClearGUIs().

// Switch off avionics
LAS_Avionics("shutdown").