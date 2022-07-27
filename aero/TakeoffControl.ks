@lazyglobal off.

global function TakeoffControl
{
    parameter ctrlState.

    if Ship:GroundSpeed >= rotateSpeed or flightState = fs_Airlaunch
    {
        // 6 degree rotation
        set ctrlState:Pitch to groundPitch + 6.
        if rocketPlane
            set ctrlState:Pitch to 20.
    }
    else
    {
        set groundHeading to landingTarget:Heading.
        if groundHeading > 85 and groundHeading < 95
        {
            if Ship:longitude < landingTarget:lng
                set groundHeading to groundHeading + (Ship:Latitude - landingTarget:Lat) * 12000.
            else
                set groundHeading to groundHeading - (Ship:Latitude - landingTarget:Lat) * 12000.
        }
        set ctrlState:Pitch to groundPitch.
    }
    
    if abortMode
        set ctrlState:Pitch to 20.

    if Ship:GroundSpeed >= rotateSpeed and Ship:Status = "Flying" and onGround
    {
        set onGround to false.
        set Ship:Control:WheelSteer to 0.
    }
    else if Ship:Status = "Landed"
    {
        set onGround to true.
    }
    
    local minAlt is 200 * (30 / maxClimbAngle) ^ 2.25.
    if abortMode
        set minAlt to 400.
        
    if flightState = fs_Airlaunch
    {
        set ctrlState:Heading to -1.
        if Ship:AirSpeed < targetSpeed
        {
            set ctrlState:Pitch to 10.
            set minAlt to 0.
        }
    }
    else
    {
        set ctrlState:Heading to groundHeading.
    }
    
    set Ship:Control:PilotMainThrottle to 1.
        
    if not onGround
    {
        if Alt:Radar > 10 and gear
            gear off.
        if alt:radar > minAlt / 2 and currentFlapDeflect > 1
            setFlaps(1).
    }

    if Alt:Radar >= minAlt and Ship:VerticalSpeed > 0 and shipPitch > 4
    {
        setFlaps(0).
        set flightState to fs_Flight.
        set debugName:Text to "Flight".
        set guiButtons["lnd"]:Enabled to true.
    }
    
    return ctrlState.
}

global function TakeoffSpoolControl
{
    local engineMaxThrust is 0.
    local engineThrust is 0.

    for eng in jetEngines
    {
        set engineMaxThrust to engineMaxThrust + eng:part:PossibleThrust().
        set engineThrust to engineThrust + eng:part:Thrust().
    }

    if engineThrust > engineMaxThrust * 0.25
    {
        TakeoffBrakeRelease().
    }
}

global function BeginTakeoff
{
    set guiButtons["to"]:Enabled to false.
    if taxiButton1:IsType("Button")
    {
        set taxiButton1:Enabled to false.
        set taxiButton2:Enabled to false.
    }
    
    CalcGroundPitch().

    // set landing target for abort
    if runwayEnd1:Distance < runwayEnd2:Distance
        set landingTarget to runwayEnd2.
    else
        set landingTarget to runwayEnd1.

    set groundHeading to landingTarget:Heading.

    print "Takeoff from runway " + runwayNumber(groundHeading).
    print "Engine start.".

    startEngines().
    for rj in ramjetEngines
        rj:Part:Shutdown.

    setFlaps(2).
    
    if brakes and not jetEngines:empty
    {
        print "Waiting for engines to spool.".

        set flightState to fs_TakeoffSpool.
        set debugName:Text to "Takeoff Spool".
    }
    else
    {
        TakeoffBrakeRelease().
    }
}

global function TakeoffBrakeRelease
{
    set flightState to fs_Takeoff.
    set debugName:Text to "Takeoff".
    brakes on.
    brakes off.

    print "Beginning takeoff roll.".
}