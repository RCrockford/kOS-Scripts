@lazyglobal off.

local pitchPid is PIDloop(0.004, 0, 0.004, -1, 1).
local climbRatePid is pidloop(3, 0, 4).
local climbLimitPid is pidloop(3, 0, 4).
local climbRateLimit is 0.
local prevAirSpeed is 0.
local prevVelocity is V(0,0,0).
local prevUpdateTime is 0.
local pitchLimit is 1.

local AoAPid is pidloop(0.04, 0, 0.08, -8, 8).
local prevAoAUpdateTime is 0.
local ΔAoA is 0.
local targetAoA is 0.

local GLimitPID is pidloop(0.022, 0, 0.0018, -0.2, 0.016).

local rollPid is PIDloop(0.005, 0.00005, 0.001, -1, 1).
local maxBankPid is pidloop(0.02, 0, 0.05, -2, 1).
local maxBankPid2 is pidloop(0.08, 0, 0.12, -0.5, 0.25).
local bankPid is PIDloop(1.25, 0.0, 1, -60, 60).

local groundYawPid is PIDloop(0.5, 0.05, 0.2, -1, 1).
local yawPid is PIDloop(0.0025, 0, 0.0025, -1, 1).
local yawLocked is false.

local wheelPid is PIDLoop(0.15, 0, 0.1, -1, 1).

local throtPid is PIDloop(0.005, 0, 0.006, -0.1, 0.1).

local PitchTune is lexicon(
    "Crossings", 0,
    "StartTime", 0,
    "SetPoint", 0,
    "PrevValue", 0,
    "MinValue", 0,
    "MaxValue", 0,
    "OutHigh", 0.5,
    "OutLow", -0.25,
    "Kp", 0,
    "Ki", 0,
    "Kd", 0
).
local RollTune is PitchTune:Copy.
set RollTune:OutHigh to 0.2.
set RollTune:OutLow to -0.2.

global function GetTargetAoA
{
    return targetAoA.
}

global function PIDTuning
{
    parameter inVal.
    parameter tuning.
    
    local outVal is choose tuning:OutLow if inVal > tuning:SetPoint else tuning:OutHigh.

    if Time:Seconds - tuning:StartTime >= 5
    {
        if (inVal > tuning:SetPoint) <> (tuning:PrevValue > tuning:SetPoint) 
            set tuning:Crossings to tuning:Crossings + 1.
        set tuning:MinValue to min(tuning:MinValue, inVal).
        set tuning:MaxValue to max(tuning:MaxValue, inVal).
        set tuning:PrevValue to inVal.
        
        // Calc current PID tuning
        if tuning:Crossings > 0
        {
            local Ku is 4 * (tuning:OutHigh - tuning:OutLow) / (Constant:Pi * (tuning:MaxValue - tuning:MinValue)).
            local Tu is (Time:Seconds - tuning:StartTime) / tuning:Crossings.
            print "Ku: " + round(Ku, 4) + "    " at (0,8).
            print "Tu: " + round(Tu, 4) + " cross=" + tuning:Crossings + "    " at (0,9).
            print "PD:  Kp=" + round(0.8 * Ku, 6) + " Kd=" + round(0.1 * Ku * Tu, 6) + "    " at (0,10).
            print "PID: Kp=" + round(0.6 * Ku, 6) + " Ki=" + round(1.2 * Ku / Tu, 6) + " Kd=" + round(0.075 * Ku * Tu, 6) + "    " at (0,11).
            print "Over: Kp=" + round(0.33 * Ku, 6) + " Ki=" + round(0.66 * Ku / Tu, 6) + " Kd=" + round(0.11 * Ku * Tu, 6) + "    " at (0,12).
            print "Tuning, setpoint=" + round(tuning:SetPoint, 2) + " low= " + round(tuning:OutLow, 1) + " high= " + round(tuning:OutHigh, 1) + " cur= " + round(inVal, 1) + "    " at (0,13).
            
            if tuning:Crossings >= 20
            {
                set tuning:Kp to 0.33 * Ku.
                set tuning:Ki to 0.66 * Ku / Tu.
                set tuning:Kd to 0.11 * Ku * Tu.
            }
        }
    }
    
    return outVal.
}

local function PitchTuning
{
    parameter Δpitch.

    if guiButtons["pkp"]:Pressed
    {
        set Δpitch to PIDTuning(shipPitch(), PitchTune).
        
        if PitchTune:Crossings >= 20
        {
            set PIDSettings:PitchKp to PitchTune:Kp.
            set PIDSettings:PitchKi to PitchTune:Ki.
            set PIDSettings:PitchKd to PitchTune:Kd.
            set PIDSettings:tuneSpeed to round(Ship:Airspeed).
        }
    }
    else
    {
        set PitchTune:Crossings to 0.
        set PitchTune:StartTime to Time:Seconds.
        set PitchTune:SetPoint to ShipPitch().
        set PitchTune:PrevValue to PitchTune:SetPoint.
        set PitchTune:MinValue to PitchTune:SetPoint.
        set PitchTune:MaxValue to PitchTune:SetPoint.
    }
    
    if guiButtons["pkd"]:Pressed
    {
        writejson(PIDSettings, "0:/aero/settings/" + Ship:Name + ".json").
        print "Saved PID settings  ".
        set guiButtons["pkd"]:Pressed to false.
    }
    
    return Δpitch.
}

local function RollTuning
{
    parameter newRoll.

    if guiButtons["rkp"]:Pressed
    {
        set newRoll to PIDTuning(shipRoll(), RollTune).
        
        if RollTune:Crossings >= 20
        {
            set PIDSettings:RollKp to RollTune:Kp.
            set PIDSettings:RollKi to RollTune:Ki * 0.1.
            set PIDSettings:RollKd to RollTune:Kd.
        }
    }
    else
    {
        set RollTune:Crossings to 0.
        set RollTune:StartTime to Time:Seconds.
        set RollTune:SetPoint to 0.
        set RollTune:PrevValue to 0.
        set RollTune:MinValue to 0.
        set RollTune:MaxValue to 0.
    }

    return newRoll.
}


global function HighAltControl
{
    parameter ctrlState.

    set ctrlState:Heading to velocityHeading().
    set SteeringManager:RollControlAngleRange to 180.
    lock steering to heading(ctrlState:Heading, ctrlState:Pitch):Vector.
    print "HighAlt " + round(ctrlState:Heading, 1) + "° p=" + round(ctrlState:Pitch, 1) + "/" + round(shipPitch, 1) + "°            " at (0,0).
}

global function SteeringReset
{
    pitchPid:Reset().
    rollPid:Reset().
    yawPid:Reset().
    AoAPid:Reset().
}

global function SteeringControl
{
    parameter ctrlState.

    local ctrlDamp is PIDSettings:tuneSpeed / max(min(Ship:AirSpeed, 900), PIDSettings:tuneSpeed * 0.7).
    local ctrlDamp2 is (min(ctrlDamp, 1.1) ^ 2) * kUniverse:TimeWarp:Rate.
    set ctrlDamp to ctrlDamp * kUniverse:TimeWarp:Rate.

    local updateTime is time:seconds.

    local climbRate is ctrlState:ClimbRate.
    if ctrlState:ClimbRate <= -1e6 and not guiButtons["pt"]:Pressed and flightState = fs_Flight and guiButtons["fl"]:Pressed
    {
        set climbRatePid:kP to 600 / (Ship:Airspeed^1.4).
        set climbRatePid:kD to climbRatePid:kP * 1.6.
        set climbRatePid:SetPoint to targetflightLevel * 100.
        set ctrlState:ClimbRate to climbRatePid:Update(updateTime, Ship:Altitude).

        // Cap maximum climb rate to avoid reducing speed too much
        if ctrlState:ClimbRate > 1 and Ship:VerticalSpeed > 0
        {
            local allEngines is list().
            list engines in allEngines.

            local engineThrust is 0.
            for eng in allEngines
            {
                set engineThrust to engineThrust + eng:AvailableThrust.
            }
            
            if climbRateLimit <= 0
                set climbRateLimit to Ship:VerticalSpeed.
            
            local accel is (Ship:AirSpeed - prevAirSpeed) / (updateTime - prevUpdateTime).
            local maxAccel is engineThrust / Ship:Mass.
            
            if (ctrlState:Speed - Ship:Airspeed) < maxAccel * 0.75
            {
                if ctrlState:Speed > 0
                {
                    if hasReheat and not guiButtons["rht"]:Pressed and flightState >= fs_Flight
                        set climbLimitPid:SetPoint to 13.25.
                    else
                        set climbLimitPid:SetPoint to 19.9.
                    set climbRateLimit to max(Ship:VerticalSpeed + climbLimitPid:Update(updateTime, Ship:Control:PilotMainThrottle * 20), 1).
                    print "Throt: " + round(Ship:Control:PilotMainThrottle * 20, 2) + " / " + round(climbLimitPid:SetPoint, 2) + "         " at (0,4).
                }
                else
                {
                    set climbRateLimit to Ship:Airspeed * 0.25.
                }
            }
            else
            {
                set climbLimitPid:SetPoint to maxAccel * 0.2.
                set climbRateLimit to max(max(Ship:VerticalSpeed, 5) - climbLimitPid:Update(updateTime, accel), 5).
                print "Accel: " + round(accel, 2) + " / " + round(climbLimitPid:SetPoint, 2) + "         " at (0,4).
            }
            set climbRateLimit to min(climbRateLimit, Ship:Airspeed * sin(maxClimbAngle)).
            print "CR: " + round(ctrlState:ClimbRate, 1) + " [" + round(climbRateLimit, 1) + "]      " at (0,3).
            set ctrlState:ClimbRate to min(ctrlState:ClimbRate, climbRateLimit).
        }
        else
        {
            set climbRateLimit to 0.
            if guiButtons["fl"]:Pressed
                set ctrlState:ClimbRate to max(ctrlState:ClimbRate, -Ship:Airspeed * 0.1).
        }
    }
    else
    {
        set climbRateLimit to 0.
    }
    
    set AoAPid:kP to AoAkPTweak / ctrlDamp2.
    set AoAPid:kD to AoAkPTweak * 1.25 / ctrlDamp2.
    set pitchPid:kP to PIDSettings:PitchKp * ctrlDamp.
    set pitchPid:kI to PIDSettings:PitchKi * ctrlDamp / kUniverse:TimeWarp:Rate.
    set pitchPid:kD to PIDSettings:PitchKd * ctrlDamp.
    
    if ctrlState:ClimbRate > -1e6
    {
        if flightState >= fs_Flight and flightState < fs_LandInterApproach
            set ctrlState:ClimbRate to max(ctrlState:ClimbRate, -Alt:Radar / 24).

        local AoARate is choose 0.16 if flightState < fs_LandFinalApproach else 0.1.
        if prevAoAUpdateTime < updateTime - AoARate * kUniverse:TimeWarp:Rate
        {
            set AoAPid:SetPoint to ctrlState:ClimbRate.
            local NewΔAoA is AoAPid:Update(updateTime, Ship:VerticalSpeed).
            local AoAUpdateFactor is max(0.05, min((180 / Ship:AirSpeed)^3, 1)).
            set ΔAoA to ΔAoA * (1-AoAUpdateFactor) + NewΔAoA * AoAUpdateFactor.
            set targetAoA to ShipPitch + ΔAoA.
            print "ΔAoA: " + round(ΔAoA, 4) + "          " at (0,2).
            set prevAoAUpdateTime to updateTime.
        }
        set ctrlState:Pitch to targetAoA.
    }
    else
    {
        AoAPid:Reset().
    }

    set pitchPid:SetPoint to max(-maxClimbAngle, min(ctrlState:Pitch, maxClimbAngle)).
    local Δpitch is PitchTuning(pitchPid:Update(updateTime, shipPitch)).

    if Ship:Status = "Flying"
    {
        local newYaw is ship:control:yaw.
        
        if flightState >= fs_LandFinalApproach
        {
            // Yaw to counter crosswind for straighter landings
            set yawPid:SetPoint to choose ctrlState:Heading if ctrlState:Heading >= 0 else shipHeading.
            
            if Ship:VerticalSpeed < ctrlState:ClimbRate * 3
                set Δpitch to Δpitch + (ctrlState:ClimbRate * 3 - Ship:VerticalSpeed) * 0.1.
            set pitchLimit to 1.
        }
        else
        {
            // Anti-yaw while cruising
            if ctrlState:Heading < 0 or (angle_off(ctrlState:Heading, shipHeading) < 2 and abs(shipRoll()) < 4)
            {
                set yawPid:SetPoint to velocityHeading.
                local Δyaw is yawPID:Update(updateTime, shipHeading) * 0.1.
                set newYaw to newYaw + Δyaw.
            }
            else
            {
                // Yaw to correct for nose dropping during turns
                set yawPid:SetPoint to pitchPid:SetPoint.
                local Δyaw is choose yawPID:Update(updateTime, shipPitch) * ctrlDamp if ctrlState:Heading >= 0 else 0.
                
                set newYaw to newYaw * 0.98 - Δyaw * sin(shipRoll()).
            }
            
            // G limiter
            if prevVelocity:Mag > 0
            {
                local accel is vdot(Velocity:Surface - prevVelocity, Facing:UpVector) / (9.81 * (updateTime - prevUpdateTime)).
                local maxg is 9 - min(Ship:Airspeed / 120, 5).
                print "g: " + round(accel, 2) + " [" + round(maxg, 2) + "]        " at (32, 1).

                set GLimitPID:SetPoint to maxg.
                set pitchLimit to pitchLimit + GLimitPID:Update(updateTime, accel).
                set pitchLimit to min(max(-1, pitchLimit), 1).
            }
        }
        
        if Ship:Airspeed > 900 or flightState >= fs_LandFinalApproach
        {
            if not yawLocked
            {
                lock steering to Heading(yawPid:SetPoint, pitchPid:SetPoint, rollPid:SetPoint).
                set yawLocked to true.
            }
            set ship:control:yaw to 0.
        }
        else
        {
            if yawLocked
            {
                unlock steering.
                set yawLocked to false.
            }
            set ship:control:yaw to newYaw.
        }

        if flightState = fs_Takeoff
            set ship:control:pitch to max(ship:control:pitch - 0.01, min(Δpitch, ship:control:pitch + 0.01)).
        else if flightState = fs_AirLaunch and ctrlState:Pitch < 10
            set ship:control:pitch to max(-0.6, min(Δpitch, 0.6)).
        else if Ship:Altitude > 25000
            set ship:control:pitch to Δpitch.
        else
            set ship:control:pitch to min(max(Δpitch, -1) + max((abs(shipRoll()) - 10) / 40, 0), pitchLimit).
    }
    else if Ship:Status = "Landed"
    {
        if flightState = fs_Takeoff
        {
            if Ship:GroundSpeed < rotateSpeed and not abortMode
                set ship:control:pitch to max(-0.1, min(Δpitch, 0.25)).
            else
                set ship:control:pitch to max(ship:control:pitch - 0.01, min(Δpitch, ship:control:pitch + 0.01)).
        }
        else if Ship:Status = "Landed" and flightState >= fs_LandTouchdown
            set ship:control:pitch to ctrlState:Pitch.
        else 
            set ship:control:pitch to Δpitch.
    }

    print " Δpitch: " + round(Δpitch, 4) + " lim: " + round(pitchLimit, 3) + "      " at (29,2).
    print round(ctrlState:Heading, 1) + "° vs=" + (choose "--" if ctrlState:ClimbRate < -10000 else round(ctrlState:ClimbRate, 1)) + "/" + round(Ship:VerticalSpeed, 1) + " p=" + round(ctrlState:Pitch, 1) + "/" + round(shipPitch, 1) + "°        " at (0,0).

    local reqBank is 0.
    if alt:radar > 15 and ctrlState:Heading >= 0
    {
        // crosswind compensation
        local hvelVec is vxcl(Up:Vector, Ship:Velocity:Surface:Normalized).
        local headVec is vxcl(Up:Vector, Facing:Vector).
        local headingDelta is vang(hvelVec, headVec).
        if vdot(vcrs(hvelVec, headVec), Up:Vector) < 0
            set headingDelta to -headingDelta.
    
        local reqTurn is angle_off(ctrlState:Heading + headingDelta, shipHeading).
        
        local speedBankLimit is 65 - min(max(0, (Ship:AirSpeed - 600) / 6), 50).

        if guiButtons["akp"]:Pressed and flightState >= fs_Flight
        {
            set bankPid:MaxOutput to speedBankLimit.
        }
        else if abs(reqTurn) > 5
        {
            set maxBankPid:SetPoint to Ship:VerticalSpeed.
            set bankPid:MaxOutput to bankPid:MaxOutput + maxBankPid:Update(updateTime, ctrlState:ClimbRate) * ctrlDamp * 0.12.
            if ctrlState:Speed > 0
            {
                set maxBankPid2:SetPoint to Ship:Airspeed.
                set bankPid:MaxOutput to bankPid:MaxOutput + maxBankPid2:Update(updateTime, ctrlState:Speed) * ctrlDamp.
            }
            set bankPid:MaxOutput to min(max(20, bankPid:MaxOutput), speedBankLimit).
        }
        else
        {
            set bankPid:MaxOutput to min(20, speedBankLimit).
        }
        set bankPid:MinOutput to -bankPid:MaxOutput.
    
        // Avoid twitchiness when turning close to 180 degrees.
        if reqTurn < -175
            set reqTurn to 185.
        local turnFactor is min(max(-20, reqTurn), 20).
        set turnFactor to (0.55 * turnFactor^2 - 0.018 * abs(turnFactor)^3) * (turnFactor / abs(turnFactor)).
        
        set bankPid:kI to choose 0.05 if abs(reqTurn) < 4 else 0.
        set reqBank to bankPid:Update(updateTime, turnFactor).
        print "Turn: " + round(reqTurn, 2) + " / " + round(turnFactor, 2) + " [" + round(headingDelta, 2) + "]      " at (0,6).
    }
    else
    {
        bankPid:Reset().
    }
    
    local rollBoost is 1.
    if flightState = fs_LandFinalApproach
        set rollBoost to 2.

    set rollPid:kP to PIDSettings:RollKp * rollBoost.
    set rollPid:kI to PIDSettings:RollKi / kUniverse:TimeWarp:Rate.
    set rollPid:kD to PIDSettings:RollKd * rollBoost.
    
    set rollPid:SetPoint to reqBank.
    set ship:control:roll to RollTuning(rollPid:Update(time:seconds, shipRoll())).
    
    print "Roll: " + round(reqBank, 2) + " / " + round(shipRoll(), 2) + "          " at (0,5).

    set prevVelocity to Velocity:Surface.
    set prevAirSpeed to Ship:AirSpeed.
    set prevUpdateTime to updateTime.
}

local lastBrake is 0.

global function ThrottleControl
{
    parameter ctrlState.

    if ctrlState:Speed > 0
    {
        local maxThrottle is 1.
		if hasReheat and not guiButtons["rht"]:Pressed and flightState >= fs_Flight
			set maxThrottle to 2/3.
            
        if not rocketPlane
        {
            set throtPid:kP to 0.0004.
            set throtPid:kD to 0.0025.
        }

        // Throttle control
        set throtPid:SetPoint to ctrlState:Speed.
        local Δthrottle is throtPid:Update(time:seconds, Ship:AirSpeed).
        
        local minThrottle is choose 0.01 if rocketPlane else 0.
        if brakes or (lastBrake > Time:Seconds - (Ship:AirSpeed - ctrlState:Speed))
        {
            set Ship:Control:PilotMainThrottle to minThrottle.
            if brakes
                set lastBrake to Time:Seconds.
        }
        else
        {
            if flightState < fs_LandInterApproach and alt:radar > 100 and ctrlState:Heading >= 0 and abs(rollPid:SetPoint) > 10
                set Δthrottle to Δthrottle + min(abs(angle_off(ctrlState:Heading, shipHeading)) * 0.005, 0.5) * 0.005.
            set Ship:Control:PilotMainThrottle to min(max(minThrottle, Ship:Control:PilotMainThrottle + Δthrottle), maxThrottle).
        }

        print "Speed " + round(ctrlState:Speed, 1) + "/" + round(Ship:AirSpeed, 1) + " [" + (choose "+" if Ship:AirSpeed > ctrlState:Speed else "-") + round(abs(Ship:AirSpeed - ctrlState:Speed), 1) + "]     " at (0,1).

        if flightState >= fs_LandInitApproach and flightState <= fs_LandFinalApproach
        {
            // Use airbrakes if overspeed and subsonic
            if Ship:AirSpeed > ctrlState:Speed + 10 and Ship:Q < 0.32
                brakes on.
            else if Ship:AirSpeed <= ctrlState:Speed + 4
                brakes off.
        }
    }
    else
    {
        throtPid:Reset().
        print "No speed control              " at (0,1).
    }

    set Ship:control:MainThrottle to Ship:Control:PilotMainThrottle.
}

global function GroundControl
{
    parameter ctrlState.

    if Ship:Status = "Landed"
    {
        if yawLocked
        {
            unlock steering.
            set yawLocked to false.
        }
        
        local wheelError is angle_off(groundHeading, shipHeading).

        set wheelPid:kP to 0.04 / max(0.5, Ship:GroundSpeed / 18).
        set wheelPid:kD to wheelPid:kP * 2 / 3.
        
        if flightState = fs_Takeoff
            set wheelPid:kP to wheelPid:kP * 2.

        set Ship:Control:WheelSteer to wheelPid:update(time:seconds, -wheelError).
        set Ship:Control:Yaw to groundYawPid:Update(time:seconds, wheelError).
        
        if abs(Ship:Control:WheelSteer) > 0.5
            set Ship:Control:PilotMainThrottle to 0.

        if flightState = fs_Taxi
            set guiButtons["dbg"]:Text to round(groundHeading, 1) + "° " + round(getDistanceToTarget(), 1) + "m".
        else
            set guiButtons["dbg"]:Text to round(groundHeading, 1) + "° ".
    }
    else
    {
        wheelPid:Reset().
        groundYawPid:Reset().
    }
}
