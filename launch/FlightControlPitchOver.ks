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

local kscPos is Ship:GeoPosition.

local lock velocityPitch to 90 - vang(Ship:up:vector, Ship:Velocity:Surface).
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
local guidanceApoThreshold is LAS_TargetPe * 250.
local lock nextStageIsGuided to LAS_StageIsGuided(Stage:Number-1).
local coastMode is false.
local lastCoastTime is 0.
local coastTicks is 0.

local suborbPitchPID is pidloop(1, 0.1, 1, -750, 250).

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
	if coastMode
		set guidanceStage to max(guidanceStage - 1, 0).

	if flightPhase = c_PhaseDownrangePower
	{
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
		
				set fr to min(fr, 0.6).
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
			set debugStat:Text to "Downrange Flight, Q=" + round(Ship:Q * constant:AtmToKPa, 1) + " D=" + round((Ship:GeoPosition:Position - kscPos:Position):Mag * 0.001, 0) + "km".
	}
    else if flightPhase >= c_PhaseGuidanceReady
    {
		LAS_GuidanceUpdate(guidanceStage).
        
        local guidance is LAS_GetGuidanceAim(guidanceStage).
        
        // Make sure dynamic pressure is low enough to start manoeuvres
        if flightPhase = c_PhaseGuidanceReady
        {
			if coastMode
			{
				set debugStat:Text to "Guidance Ready, coasting".
				if lastCoastTime <> LAS_GuidanceBurnTime(guidanceStage) and lastCoastTime < LAS_GuidanceBurnTime(guidanceStage)
				{
					set coastTicks to coastTicks + 1.
				}
				else
				{
					set coastTicks to 0.
				}
				set lastCoastTime to LAS_GuidanceBurnTime(guidanceStage).
				
				if coastTicks > 2
					set coastMode to false.
			}
			else
			{
				set debugStat:Text to "Guidance Ready, Q=" + round(Ship:Q * constant:AtmToKPa, 1).
			}
				
            if not coastMode and guidance:SqrMagnitude > 0.9 and Ship:Q < 0.1
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
				set debugStat:Text to "Guidance Active: M=" + round(guidance:SqrMagnitude, 3).
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
						lock Steering to Heading(mod(360 - latlng(90,0):bearing, 360), kickPitch).
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
			
			local startGuidance is false.
			if coastMode
			{
				if not LAS_NextStageIsUllage()
				{
					set debugStat:Text to "Aero Flight, Q=" + round(Ship:Q * constant:AtmToKPa, 1) + " Waiting for coast".
				}
				else
				{
					set debugStat:Text to "Aero Flight, Q=" + round(Ship:Q * constant:AtmToKPa, 1) + " Coasting AltT=" + round(guidanceApoThreshold * 0.001, 0).
					set startGuidance to Ship:Altitude > guidanceApoThreshold.
				}
			}
			else
			{
				set debugStat:Text to "Aero Flight, Q=" + round(Ship:Q * constant:AtmToKPa, 1) + " ApoT=" + round(guidanceApoThreshold * 0.001, 0).
				set startGuidance to Ship:Orbit:Apoapsis > guidanceApoThreshold.
			}
				
			// Don't setup guidance until we're past maxQ
			if maxQset and startGuidance and Ship:Q < 0.1
			{
				kUniverse:TimeWarp:CancelWarp().
			
				if defined LAS_TargetAp and LAS_TargetAp < 100
				{
					set flightPhase to c_PhaseDownrangePower.
				}
				else if LAS_StartGuidance(guidanceStage, targetInclination, targetOrbitable, launchAzimuth) or (coastMode and guidanceApoThreshold >= LAS_TargetPe * 500)
				{
					set flightPhase to c_PhaseGuidanceReady.
					set lastCoastTime to LAS_GuidanceBurnTime(guidanceStage).
				}
				else
				{
					set guidanceApoThreshold to guidanceApoThreshold + LAS_TargetPe * 40.
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
	
	if (not coastMode or not LAS_NextStageIsUllage()) and LAS_CheckStaging()
    {
        set stageChecked to false.
        set flameoutTimer to MissionTime + 5.
    }
    
    if not stageChecked and LAS_StageReady()
	{
		local mainEngines is LAS_GetStageEngines().
		if LAS_FinalStage()
		{
			local haveControl is false.
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
				local allRCS is list().
                list rcs in allRCS.
				for r in allRCS
				{
					if r:Enabled
					{
						set haveControl to true.
						break.
					}
				}
			}
			
			if not haveControl
			{
				print "No attitude control, aborting guidance.".
				break.
			}
		}
		else
		{
			local torqueFactor is 1.
			for eng in mainEngines
			{
				if eng:Name = "ROE-RD108"
				{
					set torqueFactor to 12.
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

if defined LAS_TargetSMA
	print "Final latitude: " + round(Ship:Latitude, 2).

ClearGUIs().

// Switch off avionics
LAS_Avionics("shutdown").