// Lander ascent system, for taking off after landing

@lazyglobal off.

parameter launchAzimuth is 90.

// Wait for unpack
wait until Ship:Unpacked.

switch to scriptpath():volume.
Core:Part:ControlFrom().

// Setup functions
runoncepath("/launch/LASFunctions").

if Ship:Status = "Landed" or Ship:Status = "Splashed"
{
    print "Lifting off".
    
    LAS_Avionics("activate").
    ladders off.
	rcs on.
    
    // Assume we're sat on the lander legs, turn on all stage engines and steer straight up
    lock Steering to LookDirUp(Up:Vector, Facing:UpVector).
    set Ship:Control:PilotMainThrottle to 1.

    local stageEngines is LAS_GetStageEngines().
    for eng in stageEngines
    {
        if not eng:Ignition
            LAS_IgniteEngine(eng).
    }
    wait until Alt:Radar > 50 or Ship:VerticalSpeed > 10.
}

if Ship:Status = "Flying" or Ship:Status = "Sub_Orbital"
{
    legs off. gear off.

    local grav is Ship:Body:Mu / Body:Position:SqrMagnitude.
    local invTWR is (Ship:Mass * grav) / Ship:MaxThrust.

    lock steering to Heading(launchAzimuth, max(arcsin(invTWR) * 1.05, 40)).

    wait until Ship:Control:PilotMainThrottle = 0.

    rcs off.
    unlock steering.

    runpath("/lander/DirectDescent", stage:number).
}
