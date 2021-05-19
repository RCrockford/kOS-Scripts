@lazyglobal off.

local landingSpeedPid is PIDloop(1.5, 0, 1.5, -2, 2).
local touchdownTime is 0.

global function LandingControl
{
    parameter ctrlState.

    if flightState = fs_LandInitApproach
    {
        set ctrlState:ClimbRate to getClimbRateToTarget().
        set ctrlState:Heading to flightTarget:Heading.
        set ctrlState:Speed to (1.6 + getDistanceToTarget() / 25000) * landingSpeed.
        local minSpeed is 1.6 * landingSpeed.
        set ctrlState:Speed to max(minSpeed, min(targetSpeed, ctrlState:Speed)).
        local minDistance is 200.
        if rocketPlane or abs(angle_off(groundHeading, shipHeading)) <= 60
            set minDistance to minDistance + abs(angle_off(groundHeading, shipHeading)) * Ship:Airspeed * 0.25.

        set guiButtons["dbg"]:Text to round(ctrlState:Heading, 1) + "° " + round(getDistanceToTarget() * 0.001, 1) + "/" + round(minDistance * 0.001, 1).

        if getDistanceToTarget() < minDistance
        {
            if rocketPlane or (abs(angle_off(groundHeading, shipHeading)) <= 90 and Ship:AirSpeed < ctrlState:Speed * 1.2)
            {
                set flightState to fs_LandInterApproach.
                set debugName:Text to "Approach".
                set flightTarget to LatLng(landingTarget:lat + approachDirLat * (4/2.46), landingTarget:lng + approachDirLng * (4/2.46)).
                set flightTargetAlt to runwayAlt + 220.
                if rocketPlane
                    set flightTargetAlt to flightTargetAlt + 440.
                else
                    setFlaps(2).
                print "On approach".
            }
            else
            {
                set flightState to fs_LandTurn.
                set debugName:Text to "Turn 1".
                if Ship:AirSpeed >= ctrlState:Speed * 1.25
                    print "Turning to reduce speed".
                else
                    print "Turning to correct heading".
            }
        }
        else if rocketPlane and Alt:Radar < 1000
        {
            set flightState to fs_LandDitch.
            set debugName:Text to "Ditching".
            set groundHeading to shipHeading.
            set kUniverse:TimeWarp:Rate to 1.
            print "Insufficient momentum for landing, ditching aircraft".
        }
    }
    else if flightState = fs_LandTurn
    {
        set ctrlState:ClimbRate to (flightTargetAlt - Ship:Altitude) * 0.05.
        set ctrlState:Speed to (1.6 + getDistanceToTarget() / 25000) * landingSpeed.
        local minDistance is 2500 * landingSpeed * landingSpeed / 6400.

        if getDistanceToTarget() < minDistance
        {
            set ctrlState:Heading to mod(groundHeading + 135, 360).
            local heading2 is mod(groundHeading + 225, 360).
            if abs(angle_off(heading2, shipHeading)) < abs(angle_off(ctrlState:Heading, shipHeading))
                set ctrlState:Heading to heading2.
            set guiButtons["dbg"]:Text to round(ctrlState:Heading, 1) + "° " + round(getDistanceToTarget() * 0.001, 2) + " / " + round(minDistance * 0.001, 2).
        }
        else
        {
            set ctrlState:Heading to mod(groundHeading + 180, 360).

            set debugName:Text to "Turn 2".
            set guiButtons["dbg"]:Text to round(ctrlState:Heading, 1) + "° " + round(getDistanceToTarget() * 0.001, 2) + " / " + round(minDistance * 0.002, 2).

            if getDistanceToTarget() > minDistance * 2
            {
                set flightState to fs_LandInitApproach.
                set debugName:Text to "Initial Approach".
            }
        }
    }
    else if flightState = fs_LandInterApproach
    {
        if getDistanceToTarget() < 800
        {
            kUniverse:Timewarp:CancelWarp().
            // Use blended heading
            if abs(flightTarget:Heading - landingTarget:Heading) <= 10
                set ctrlState:Heading to (flightTarget:Heading + landingTarget:Heading) / 2.
            else
                set ctrlState:Heading to landingTarget:Heading.
        }
        else
        {
            set ctrlState:Heading to flightTarget:Heading.
        }
        set ctrlState:ClimbRate to getClimbRateToTarget().
        local maxSpeed is max(1.1, min((Ship:AirSpeed - 1) / landingSpeed, 1.6)).
        set ctrlState:Speed to min((1.1 + getDistanceToTarget() / 16000), maxSpeed) * landingSpeed.

        set guiButtons["dbg"]:Text to round(ctrlState:Heading, 1) + "° " + round(getDistanceToTarget() * 0.001, 1) + "/0.1".

        if landingTarget:Distance < 4200
        {
            set flightState to fs_LandFinalApproach.
            set debugName:Text to "Final".
            set flightTarget to landingTarget.
            if runwayEnd1:Distance < runwayEnd2:Distance
                set landingTarget to runwayEnd2.
            else
                set landingTarget to runwayEnd1.
            set flightTargetAlt	to runwayAlt + 6.
            setFlaps(3).
            gear on.
            brakes off.
            set groundPitch to -10.
            when alt:radar < 100 then { lights off. lights on. }
            print "Final approach".
        }
    }
    else if flightState = fs_LandFinalApproach
    {
        set ctrlState:Heading to flightTarget:Heading.
        set ctrlState:Speed to max(1.1 * max(getDistanceToTarget() / 4200, 1e-4) ^ 0.2, 1) * landingSpeed.

        set guiButtons["dbg"]:Text to round(ctrlState:Heading, 1) + "° " + round(getDistanceToTarget() * 0.001, 2).
        
        local sinkRate is -50.
        local landingAltitude is max(8, min(Alt:Radar, Ship:Altitude - runwayAlt)).

        if rocketPlane and landingAltitude < 100
        {
            set sinkRate to -(landingAltitude/20)^1.7.
            set ctrlState:Heading to landingTarget:heading.
        }
        else if landingAltitude < 40
        {
            set ctrlState:Heading to landingTarget:heading.
            set sinkRate to -(landingAltitude/10)^1.2.
        }
        
        if not rocketPlane and flightTarget:Distance > (landingAltitude - 5) / sin(1) and not rocketPlane
        {
            print "Insufficient altitude, going around".
            set ctrlState:goAround to true.
        }

        if landingAltitude < 150 and groundPitch < -8
            CalcGroundPitch().

        if landingAltitude < 40
        {
            set landingSpeedPid:SetPoint to groundPitch * (50 - landingAltitude) / 20.
            set ctrlState:Speed to min(Ship:AirSpeed - landingSpeedPid:Update(Time:Seconds, GetTargetAoA()) * (50 - landingAltitude) / 20, landingSpeed).
        }

        set ctrlState:ClimbRate to max(sinkRate, getClimbRateToTarget()).

        // Crosswind compensation
        local latDiff is max(-2, min((Ship:Latitude - landingTarget:Lat) * 8000, 2)).
        if Ship:longitude < landingTarget:lng
            set ctrlState:Heading to ctrlState:Heading + latDiff.
        else
            set ctrlState:Heading to ctrlState:Heading - latDiff.
            
        if landingAltitude < 20 and (flightTarget:Distance < 100 or abs(flightTarget:Bearing > 90))
        {
            set flightState to fs_LandTouchdown.
            set flightTarget to landingTarget.
            set debugName:Text to "Touchdown".
        }
    }
    else if flightState = fs_LandTouchdown
    {
        set ctrlState:Heading to flightTarget:Heading.
        set ctrlState:ClimbRate to -1e8.
        set ctrlState:Pitch to max((groundPitch + 0.2 + shipPitch()) / 2,  GetTargetAoA()).
        local landingAltitude is max(8, min(Alt:Radar, Ship:Altitude - runwayAlt)).
        set landingSpeedPid:SetPoint to -2.5.
        set ctrlState:Speed to Ship:AirSpeed + min(0, landingSpeedPid:Update(Time:Seconds, Ship:VerticalSpeed)).

        if Ship:Status = "Landed"
        {
            print "Braking".
            set flightState to fs_LandBrakeHeading.
            set debugName:Text to "Brake".
            set touchdownTime to Time:Seconds.
            setFlaps(2).
            stopEngines().
        }
        else if landingAltitude > 40 or landingTarget:Distance < 1000 and not rocketPlane
        {
            if landingAltitude > 40
                print "Over altitude, going around".
            if landingTarget:Distance < 1000
                print "Insufficient runway, going around".
            set ctrlState:goAround to true.
        }
    }
    else if flightState = fs_LandBrake or flightState = fs_LandBrakeHeading
    {
        set Ship:Control:PilotMainThrottle to 0.
        if flightState = fs_LandBrakeHeading
            set groundHeading to flightTarget:Heading.

        set ctrlState:Heading to groundHeading.
        if Ship:Status = "Landed"
        {
            set ctrlState:Pitch to -1 / (max(1, min((Time:Seconds - touchdownTime) * 1.8, 1000)) ^ 2).
        }
        else
        {
            set ctrlState:Pitch to 0.
            set touchdownTime to Time:Seconds.
        }
        if ctrlState:Pitch > -0.5
            brakes on.

        if Ship:GroundSpeed < 1
        {
            setFlaps(0).
            set flightState to fs_Landed.
            set debugName:Text to "Landed".
            stopEngines().
        }
        // anti-lock brakes
        else
        {
            local a is angle_off(shipHeading, ctrlState:Heading).
            if Ship:GroundSpeed < 8
                set a to 0.
            local maxBrake is max(100 - Ship:GroundSpeed, 0) * min(max(3 - abs(a), 0), 1).

            if leftGear:IsType("part") and rightGear:IsType("part")
            {
                leftGear:GetModule("ModuleWheelBrakes"):SetField("brakes", maxBrake * min(max(1.5 - a, 0.1), 1.25)).
                rightGear:GetModule("ModuleWheelBrakes"):SetField("brakes", maxBrake * min(max(1.5 + a, 0.1), 1.25)).
            }
        }
    }
    else if flightState = fs_LandManual
    {
        set ctrlState:Enabled to false.

        if Ship:Status = "Landed"
        {
            brakes on.
            set groundHeading to shipHeading.
            print "Braking".
            set flightState to fs_LandBrake.
            set debugName:Text to "Brake".
        }
        else if guiButtons["lnd"]:TakePress
        {
            print "Landing assistance cancelled".
            set flightState to fs_Flight.
            set debugName:Text to "Flight".
        }
    }
    else if flightState = fs_LandDitch
    {
        set ctrlState:Heading to groundHeading.
        if Alt:Radar > 1
            set ctrlState:ClimbRate to -((Alt:Radar / 10) ^ 0.8).

        if Ship:Status = "Landed"
        {
            brakes on.
            print "Braking".
            set flightState to fs_LandBrake.
            set debugName:Text to "Brake".
        }
    }
    else if flightState = fs_Landed
    {
        set ctrlState:Pitch to 0.
    }
    
    return ctrlState.
}