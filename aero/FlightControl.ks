@lazyglobal off.

global function FlightControl
{
    parameter ctrlState.

    if guiButtons["fl"]:Pressed or guiButtons["cr"]:Pressed or guiButtons["hdg"]:Pressed
    {
        // Altitude control
        if initialClimb
        {
            set ctrlState:Pitch to targetClimbRate.
            if Ship:VerticalSpeed < 0
                set initialClimb to false.
        }
        else if guiButtons["cr"]:Pressed
        {
            set ctrlState:ClimbRate to targetClimbRate.
        }

        if guiButtons["hdg"]:pressed
        {
            set ctrlState:Heading to targetHeading.
        }
    }
    else
    {
        set ctrlState:Enabled to false.
    }

    if guiButtons["spd"]:Pressed
    {
        set ctrlState:Speed to targetSpeed.
    }

    if guiButtons["lnd"]:TakePress
    {
        if runwayHeading >= 0
        {
            if runwayEnd1:Distance < runwayEnd2:Distance
            {
                set landingTarget to runwayEnd1.
                set groundHeading to runwayHeading.
                set approachDirLat to runwayEnd1:Lat - runwayEnd2:Lat.
                set approachDirLng to runwayEnd1:Lng - runwayEnd2:Lng.
            }
            else
            {
                set landingTarget to runwayEnd2.
                set groundHeading to mod(runwayHeading + 180, 360).
                set approachDirLat to runwayEnd2:Lat - runwayEnd1:Lat.
                set approachDirLng to runwayEnd2:Lng - runwayEnd1:Lng.
            }
            // approach lat/lng are approximately 2.46km

            print "Landing at runway " + runwayNumber(groundHeading).

            // initial approach marker at 12 km out, 500m alt.
            set flightTarget to LatLng(landingTarget:lat + approachDirLat * (12/2.46), landingTarget:lng + approachDirLng * (12/2.46)).
            set flightTargetAlt to runwayAlt + 500.
            if rocketPlane
            {
                set flightTarget to LatLng(flightTarget:lat + approachDirLat, flightTarget:lng + approachDirLng).
                set flightTargetAlt to flightTargetAlt + 1250.
            }
            set flightState to fs_LandInitApproach.
            set debugName:Text to "Initial Approach".
            set guiButtons["lnd"]:Enabled to false.

            set ctrlState:ClimbRate to getClimbRateToTarget().
        }
        else
        {
            set flightState to fs_LandManual.
            set debugName:Text to "Manual Landing".
            print "Manual landing assistance active".
            when alt:radar < 200 then { gear on. lights on. }
        }

        for chute in allChutes
        {
            local modRealChute is chute:GetModule("RealChuteModule").
            if modRealChute:HasEvent("arm parachute")
            {
                modRealChute:DoEvent("arm parachute").
            }
        }
    }
    
    return ctrlState.
}