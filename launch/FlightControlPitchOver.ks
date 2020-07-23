lazyglobal off.

// Fly minimal AoA until Q < 0.1 and then engage guidance

// Set some fairly safe defaults
parameter pitchOverSpeed is 100.
parameter pitchOverAngle is 4.
parameter launchAzimuth is 90.
parameter targetInclination is -1.
parameter targetOrbitable is 0.
parameter canCoast is false.

local pitchOverCosine is cos(pitchOverAngle).
local maxQ is Ship:Q.
local maxQset is false.

local kscPos is Ship:GeoPosition.
local coastMode is false.

local lock velocityPitch to max(90 - vang(Ship:up:vector, Ship:Velocity:Surface), choose 0 if coastMode else (choose 85 if pitchOverAngle < 1e-4 else 30)).
local lock shipPitch to 90 - vang(Ship:up:vector, Ship:facing:forevector).

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
set debugGui:X to -150.
set debugGui:Y to debugGui:Y - 480.
local mainBox is debugGui:AddVBox().

local debugStat is mainBox:AddLabel("Liftoff").
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
				
				set debugStat:Text to "Downrange Boost, fr=" + round(fr, 3) + " D=" + round((Ship:GeoPosition:Position - kscPos:Position):Mag * 0.001, 0) + "km".
			}
            else
            {
                set debugStat:Text to "Downrange Boost, D=" + round((Ship:GeoPosition:Position - kscPos:Position):Mag * 0.001, 0) + "km".
            }
		}
		else			
			set debugStat:Text to "Downrange Flight, Q=" + round(1000 * Ship:Q * constant:AtmToKPa, 2) + " Pa D=" + round((Ship:GeoPosition:Position - kscPos:Position):Mag * 0.001, 0) + "km".
	}
    else if flightPhase >= c_PhaseGuidanceReady
    {
		LAS_GuidanceUpdate(guidanceStage).
        
        local guidance is LAS_GetGuidanceAim(guidanceStage).
        
        // Make sure dynamic pressure is low enough to start manoeuvres
        if flightPhase = c_PhaseGuidanceReady
        {
			local fr is vdot(guidance, Ship:Up:Vector).
            set debugStat:Text to "Guidance Ready, Q=" + round(1000 * Ship:Q * constant:AtmToKPa, 2) + " Pa fr=" + round(fr, 3).
				
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
                    print "Orbital guidance mode active".
                }
            }
        }
        else
        {
            if guidance:SqrMagnitude > 0.9
            {
				set debugStat:Text to "Guidance Active: M=" + round(guidance:SqrMagnitude, 3) + " Q=" + round(1000 * Ship:Q * constant:AtmToKPa, 2) + " Pa".
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
			else 
			{
				local stageEngines is LAS_GetStageEngines().
				if stageEngines:Length >= 1
					set debugStat:Text to "Guidance Inactive: G=" + nextStageIsGuided + " F=" + stageEngines[0]:FlameOut + " N=" + stageEngines[0]:Name.
				else
					set debugStat:Text to "Guidance Inactive: G=" + nextStageIsGuided + " No engine".

				if not nextStageIsGuided and stageEngines:Length >= 1 and stageEngines[0]:FlameOut
				{
					local nextStageEngines is LAS_GetStageEngines(Stage:Number-1).
					if nextStageEngines:Length >= 1
					{
						print "Setting up unguided kick".
						set flightPhase to c_PhaseGuidanceKick.
						local kickPitch is LAS_GetPartParam(LAS_GetStageEngines(Stage:Number-1)[0], "p=", 0).
						lock Steering to Heading(mod(360 - latlng(90,0):bearing, 360), kickPitch, 0).
						set debugStat:Text to "Guidance Kick: h=" + round(mod(360 - latlng(90,0):bearing, 360), 2) + " p=" + round(kickPitch, 1).
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
        if vdot(Ship:SrfPrograde:ForeVector, LAS_ShipPos():Normalized) > pitchOverCosine
        {
            if flightPhase < c_PhasePitchOver
            {
				set debugStat:Text to "Pitch and roll program: " + round(pitchOverAngle, 2) + "° heading " + round(launchAzimuth, 2) + "°".
                print debugStat:Text.
                set flightPhase to c_PhasePitchOver.
            }
            lock Steering to Heading(launchAzimuth, min(90 - pitchOverAngle, velocityPitch), 0).
        }
        else
        {
            if flightPhase < c_PhaseAeroFlight
            {
                print "Minimal AoA flight mode active".
				lock Steering to Heading(launchAzimuth, min(90 - pitchOverAngle, velocityPitch), 0).
                set flightPhase to c_PhaseAeroFlight.
            }
            
            local r is LAS_ShipPos():Mag.
            local h is vcrs(LAS_ShipPos(), Ship:Velocity:Orbit):Mag.
            local vTheta is h / r.
			
			if not coastMode and canCoast and Ship:Q < 0.12 and Ship:Altitude > 10000
			{
				set coastMode to true.				
				lock Steering to Heading(launchAzimuth, min(90 - pitchOverAngle, choose (velocityPitch - 2) if (Ship:Orbit:Apoapsis < LAS_TargetPe * 800) else 0), 0).
			}

			if coastMode
			{
				set debugStat:Text to "Coast Flight, aT=" + LAS_TargetPe * 0.8 + "km vT=" + round(vTheta, 0) + "/" + round(guidanceMinV, 0).
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
				set debugStat:Text to "Aero Flight, Q=" + round(Ship:Q * constant:AtmToKPa, 2) + " kPa vT=" + round(vTheta, 0) + "/" + round(guidanceMinV, 0).
			}
            
			local startGuidance is vTheta > guidanceMinV and (not coastMode or (LAS_FinalStage() and (Ship:Altitude > LAS_TargetPe * 800 or Eta:Apoapsis < 60))).
			
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
					set guidanceMinV to guidanceMinV + 150.
				}
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
        
        set flightPhase to c_PhaseSECO.
    }
}

local function checkMaxQ
{
    if not maxQset or Ship:Q > maxQ
    {
        if maxQ > Ship:Q and Ship:Altitude > 5000
        {
            print "Max Q " + round(maxQ * constant:AtmToKPa, 2) + " kPa.".
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

local stageChecked is false.
local flameoutTimer is MissionTime + 5.

until flightPhase = c_PhaseSECO
{
    checkMaxQ().
    if flightPhase < c_PhaseSECO
        checkAscent().
    if maxQSet
        LAS_CheckPayload().
	
	if (not coastMode or Ship:Altitude > LAS_TargetPe * 800 or Eta:Apoapsis < 60) and LAS_CheckStaging()
    {
        set stageChecked to false.
        set flameoutTimer to MissionTime + 5.
    }
    
    if not stageChecked and LAS_StageReady()
	{
		if LAS_FinalStage()
		{
			local mainEngines is LAS_GetStageEngines().
			local haveControl is false.
			for eng in mainEngines
			{
				if eng:HasGimbal
				{
					set haveControl to true.
					break.
				}
			}
			
			if haveControl
			{
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
			local allEngines is list().
			list engines in allEngines.
			local torqueFactor is 2.
			for eng in allEngines
			{
				if eng:ignition and eng:Name = "ROE-RD108"
				{
					set torqueFactor to 12.
					break.
				}
				if eng:ignition and eng:Name:contains("vernier")
				{
					set torqueFactor to 64.
					break.
				}
			}
			// Reset torque
			set SteeringManager:RollTorqueFactor to torqueFactor.
		}
        
        set stageChecked to true.
	}
    
    if flightPhase < c_PhaseSECO and LAS_TargetPe < 100 and MissionTime > flameoutTimer
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
        set debugStat:Text to "Suborbital coast, D=" + round((Ship:GeoPosition:Position - kscPos:Position):Mag * 0.001, 0) + "km".
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

if defined LAS_TargetSMA
	print "Final latitude: " + round(Ship:Latitude, 2).
    
LAS_EnableAllEC().

ClearGUIs().

// Switch off avionics
LAS_Avionics("shutdown").