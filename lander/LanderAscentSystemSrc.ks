// Lander ascent system, for taking off after landing

@lazyglobal off.

parameter targetAp.
parameter targetPe.
parameter launchAzimuth is 90.

// Wait for unpack
wait until Ship:Unpacked.

// Setup functions
runpathonce("../launch/LASFunctions").

if Ship:Status = "Landed" or Ship:Status = "Splashed"
{
    print "Lifting off".
    
    ladders off.
    
    // Assume we're sat on the lander legs, turn on all stage engines and steer straight up
    lock Steering to Heading(launchAzimuth, 90).
    set Ship:Control:PilotMainThrottle to 1.

    local stageEngines is LAS_GetStageEngines().
    for eng in stageEngines
    {
        if not eng:Ignition
            LAS_IgniteEngine(eng).
    }
    
    wait until Alt:Radar > 100 or Ship:VerticalSpeed > 20.
}

if Ship:Status = "Flying" or Ship:Status = "Sub_Orbital"
{
    legs off.

    if defined LAS_TargetPe
        set LAS_TargetPe to targetPe.
    else
        global LAS_TargetPe is targetPe.
        
    if defined LAS_TargetAp
        set LAS_TargetAp to targetAp.
    else
        global LAS_TargetAp is targetAp.

    runpath("../launch/OrbitalGuidance").

    // Trigger flight control
    if Ship:Body:Atm:Exists
    {
        set pitchOverSpeed to LAS_GetPartParam(Ship:RootPart, "spd=", 100).
        set pitchOverAngle to LAS_GetPartParam(Ship:RootPart, "ang=", 4).

        runpath("../launch/FlightControlPitchOver", pitchOverSpeed, pitchOverAngle, launchAzimuth).
    }
    else
    {
        runpath("../launch/FlightControlNoAtm", launchAzimuth).
    }
}
