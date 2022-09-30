// Lander ascent system, for taking off after landing

@lazyglobal off.

parameter targetPe is round(Body:Radius * 0.000015).
parameter targetAp is targetPe * 2.
parameter launchAzimuth is 90.
parameter ascentStage is max(stage:number - 1, 0).

// Wait for unpack
wait until Ship:Unpacked.

switch to scriptpath():volume.
Core:Part:ControlFrom().

local liftoffTime is MissionTime.

global function METString
{
    local str is "T+" + round(MissionTime - liftoffTime, 1).
    if not str:Contains(".")
        return str + ".0".
    return str.
}

// Setup functions
runoncepath("/launch/lasfunctions").

if Ship:Status = "Landed" or Ship:Status = "Splashed"
{
    if stage:number > ascentStage + 1
	{
        print "Fixing staging".
		wait until stage:ready.
		stage.
	}

    print "Lifting off".
    
    LAS_Avionics("activate").
    ladders off.
	rcs on.
    
    // Assume we're sat on the lander legs, turn on all stage engines and steer straight up
    lock Steering to LookDirUp(Up:Vector, Facing:UpVector).
    set Ship:Control:PilotMainThrottle to 1.

    local stageEngines is LAS_GetStageEngines(ascentStage).
    if stageEngines:Empty
        print "No engines found for stage " + ascentStage.
    for eng in stageEngines
    {
        if not eng:Ignition
            LAS_IgniteEngine(eng).
    }
	wait 0.
    for eng in stageEngines
    {
        if eng:Ignition
            wait until eng:Thrust > eng:PossibleThrust * 0.5.
    }
	
	if stage:number > ascentStage
	{
		wait until stage:ready.
		stage.
	}
    
    wait until Ship:VerticalSpeed > 2.
}

if Ship:Status = "Flying" or Ship:Status = "Sub_Orbital"
{
    legs off. gear off.

    if defined LAS_TargetPe
        set LAS_TargetPe to targetPe.
    else
        global LAS_TargetPe is targetPe.
        
    if defined LAS_TargetAp
        set LAS_TargetAp to targetAp.
    else
        global LAS_TargetAp is targetAp.

    runpath("/launch/orbitalguidance", stage:number).

    // Trigger flight control
    if Ship:Body:Atm:Exists
    {
        set pitchOverSpeed to LAS_GetPartParam(Ship:RootPart, "spd=", 50).
        set pitchOverAngle to LAS_GetPartParam(Ship:RootPart, "ang=", 3).

        runpath("/launch/flightcontrolpitchover", pitchOverSpeed, pitchOverAngle, launchAzimuth).
    }
    else
    {
        runpath("/launch/flightcontrolnoatm", launchAzimuth, -1, 0).
    }
}
