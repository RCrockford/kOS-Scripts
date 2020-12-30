// Launch ascent system
// Overall control of launching and ascent

@lazyglobal off.

parameter engineStart is -1.    // Engine start time relative to T+0, -1 to autoconfigure.
parameter targetOrbit is 0.

// Wait for unpack
wait until Ship:Unpacked.

ClearGuis().

// Must be prelaunch for system to activate (allows for reboots after liftoff).
if Ship:Status = "PreLaunch" or core:tag:contains("prelaunchfix")
{
    // Open terminal
    Core:DoEvent("Open Terminal").
	set Terminal:Height to max(Terminal:Height, 50).
    
    switch to 0.
	
	Core:Part:ControlFrom().
   
    // Setup functions
    runoncepath("0:/launch/LASFunctions").
	
	global function dummy_func {}
	
	global LAS_CrewEscape is dummy_func@.
	global LAS_EscapeJetisson is dummy_func@.
	global LAS_HasEscapeSystem is false.
	if not Ship:Crew:Empty
	{
		print "Crew found, setting up escape system.".
		runpath("0:/launch/LaunchEscape").
	}
	
    runpath("0:/launch/Staging").

    local totalControlled is 0.
	for a in Ship:ModulesNamed("ModuleProceduralAvionics")
    {
		local controllable is choose a:GetField("controllable") if a:HasField("Controllable") else 0.
		set totalControlled to totalControlled + controllable.
    }
    
    local pitchOverSpeed is 50.
    local pitchOverAngle is 4.
    local launchAzimuth is 90.
    local targetInclination is -1.
    local targetOrbitable is 0.
    local maxApoapsis is -1.
    local stagingValid is true.
    local helioSync is false.

    if totalControlled > 0
    {
        print "Avionics unit detected.".
        
        local targetPe is LAS_GetPartParam(Core:Part, "pe=", -1).
        if targetPe >= 0 and defined LAS_TargetPe
            set LAS_TargetPe to targetPe.
        else if targetPe >= 0
            global LAS_TargetPe is targetPe.
        
        local targetAp is LAS_GetPartParam(Core:Part, "ap=", -1).
        if targetAp >= 0 and defined LAS_TargetAp
            set LAS_TargetAp to targetAp.
        else if targetAp >= 0
            global LAS_TargetAp is targetAp.
        
		if defined LAS_TargetSMA or LAS_TargetAp > 100
        {
			runpath("0:/launch/OrbitalGuidance").
            if LAS_GuidanceDeltaV() < LAS_GuidanceTargetVTheta() + 1000
            {
                print "Insufficient deltaV in guided stages:".
                print "  Needs >" + round(LAS_GuidanceTargetVTheta() + 1000, 0) + " m/s, has " + round(LAS_GuidanceDeltaV(), 0) + " m/s".
                set stagingValid to false.
            }
            else if LAS_GuidanceDeltaV() > LAS_GuidanceTargetVTheta() + 2500
            {
                print "Excessive deltaV in guided stages:".
                print "  Needs <" + round(LAS_GuidanceTargetVTheta() + 2500, 0) + " m/s, has " + round(LAS_GuidanceDeltaV(), 0) + " m/s".
                set stagingValid to false.
            }
        }
        
        set pitchOverSpeed to LAS_GetPartParam(Core:Part, "spd=", pitchOverSpeed).
        set pitchOverAngle to LAS_GetPartParam(Core:Part, "ang=", pitchOverAngle).
        set launchAzimuth to LAS_GetPartParam(Core:Part, "az=", launchAzimuth).
        set targetInclination to LAS_GetPartParam(Core:Part, "inc=", targetInclination).
    }
    else
    {
        print "No avionics unit detected, assuming unguided.".
        set maxApoapsis to LAS_GetPartParam(Core:Part, "ap=", maxApoapsis).
    }
    
    runpath("0:/launch/LaunchGUI").

	local launchButton is LGUI_GetButton().
    set launchButton:Enabled to stagingValid.
    
    local speedText is LGUI_CreateTextEdit("Speed", pitchOverSpeed:ToString, { parameter str. set pitchOverSpeed to str:ToNumber(pitchOverSpeed). }, totalControlled > 0).
    local angleText is LGUI_CreateTextEdit("Angle", pitchOverAngle:ToString, { parameter str. set pitchOverAngle to str:ToNumber(pitchOverAngle). }, totalControlled > 0).
    local azimuthText is LGUI_CreateTextEdit("Azimuth", launchAzimuth:ToString, { parameter str. set launchAzimuth to str:ToNumber(launchAzimuth). }, totalControlled > 0).
    local southCheckbox is LGUI_CreateCheckbox("Launch South").
    
    local function CalcAzimuth
    {
        local targetPe is LAS_TargetPe * 1000 + Ship:Body:Radius.
        local a is 0.
        if defined LAS_TargetSMA
            set a to LAS_TargetSMA.
        else
            set a to (LAS_TargetPe + LAS_TargetAp) * 500 + Ship:Body:Radius.
        local sinInertialAz is max(-1, min(cos(targetInclination)/cos(Ship:Latitude),1)).
        local vOrbit is sqrt(2 * Ship:Body:Mu / targetPe - Ship:Body:Mu / a).
        local vEqRot is 2 * Constant:pi * Ship:Body:Radius / Ship:Body:RotationPeriod.
        // Using the identity sin2 + cos2 = 1 to avoid inverse trig.
        return mod(arctan2(vOrbit * sinInertialAz - vEqRot * cos(Ship:Latitude), vOrbit * sqrt(1 - sinInertialAz^2)) + 360, 360).
    }
    
    local function RendezvousLaunchSouth
    {
        local bodyAngVel is Ship:Body:AngularVel:Normalized.
        local lanVec is (SolarPrimeVector * AngleAxis(TargetOrbit:LAN, bodyAngVel)):Normalized.
        local orbitNorm is bodyAngVel * AngleAxis(-TargetOrbit:Inclination, lanVec).
        local padVec is -Ship:Body:Position:Normalized.
        local northLaunchNorm is vcrs(heading(launchAzimuth, 0):Vector, padVec):Normalized.
        local southLaunchNorm is vcrs(heading(mod(360 + 180 - launchAzimuth, 360), 0):Vector, padVec):Normalized.
        return abs(vdot(northLaunchNorm, orbitNorm)) < abs(vdot(southLaunchNorm, orbitNorm)).
    }
    
    local function TerminatorLaunchSouth
    {
        local padVec is -Ship:Body:Position:Normalized.
        local northLaunchNorm is vcrs(heading(launchAzimuth, 0):Vector, padVec):Normalized.
        local southLaunchNorm is vcrs(heading(mod(360 + 180 - launchAzimuth, 360), 0):Vector, padVec):Normalized.
        return abs(vdot(northLaunchNorm, Sun:Position:Normalized)) < abs(vdot(southLaunchNorm, Sun:Position:Normalized)).
    }
    
    local function setAzimuth
    {
		local south is southCheckbox:Pressed.
	
		if targetOrbit:IsType("Orbit")
			set targetInclination to max(Ship:Latitude, min(targetOrbit:Inclination, 180 - Ship:Latitude)).
		
        if targetInclination >= 0
        {
            set launchAzimuth to CalcAzimuth().
			
			if targetOrbit:IsType("Orbit")
                set south to RendezvousLaunchSouth().
			
			if south
				set launchAzimuth to mod(360 + 180 - launchAzimuth, 360).
            
            set azimuthText:text to round(launchAzimuth, 3):ToString.
        }

        set azimuthText:Enabled to targetInclination < 0.
    }

    local LANOrbit is false.

    local inclinationText is LGUI_CreateTextEdit("Inclination", targetInclination:ToString, {
		parameter str.
		set targetInclination to str:ToNumber(targetInclination).
        if LANOrbit
            set targetOrbit to CreateOrbit(max(Ship:Latitude, min(targetInclination, 180 - Ship:Latitude)), 0, (LAS_TargetAp + LAS_TargetPe) * 500 + Body:Radius, targetOrbit:LAN, 0, 0, 0, Body).
		setAzimuth().
	}, totalControlled > 0).
    
    local lanText is LGUI_CreateTextEdit("LAN", "-1", {
		parameter str.
		local newLAN to str:ToNumber(-1).
        if newLAN >= 0 and newLAN < 360
        {
            set targetOrbit to CreateOrbit(max(Ship:Latitude, min(targetInclination, 180 - Ship:Latitude)), 0, (LAS_TargetAp + LAS_TargetPe) * 500 + Body:Radius, newLAN, 0, 0, 0, Body).
            set LANOrbit to true.
        }
        else
        {
            set targetOrbit to 0.
            set LANOrbit to false.
        }
		setAzimuth().
	}, totalControlled > 0).
    set lanText:Enabled to targetOrbit:IsType("Scalar").

    if totalControlled > 0
    {
		local launchSouth is false.
        set southCheckbox:Enabled to false.
        if targetOrbit:IsType("Orbitable") and targetOrbit <> Sun
        {
            set targetOrbitable to targetOrbit.
			set targetOrbit to targetOrbitable:Orbit.
            set targetInclination to -1.
            set inclinationText:Text to "Target (" + targetOrbitable:Name + ")".
            set inclinationText:Enabled to false.
        }
        else if targetOrbit = Sun and targetInclination <= 90
        {
            set targetInclination to arccos(vdot(Body:AngularVel:Normalized, Sun:Position:Normalized)).
            if targetInclination > 90
                set targetInclination to 180 - targetInclination.
            set launchAzimuth to CalcAzimuth().
			set launchSouth to TerminatorLaunchSouth().
        }
        else if targetOrbit:IsType("Orbit")
        {
            set targetInclination to max(Ship:Latitude, min(targetOrbit:Inclination, 180 - Ship:Latitude)).
        }
		else if defined LAS_TargetInc
		{
            set targetInclination to max(Ship:Latitude, min(abs(LAS_TargetInc), 180 - Ship:Latitude)).
			set launchSouth to (defined LAS_TargetInc and LAS_TargetInc < 0).
		}
		else
		{
			set launchSouth to targetInclination >= 0 and Ship:Latitude > 0 and (Ship:Longitude > -122 and Ship:Longitude < -78).	// Southerly launches by default from North America.
            set southCheckbox:Enabled to true.
		}
        if inclinationText:Enabled
            set inclinationText:Text to round(targetInclination, 2):ToString.
        set southCheckbox:Pressed to launchSouth.
        
        setAzimuth().
        
        if defined LAS_TargetLAN
        {
            set lanText:Text to round(LAS_TargetLAN, 3):ToString.
            lanText:OnConfirm(lanText:Text).
        }

		// Preset launch, just go straight into countdown.
		if defined LAS_LaunchTime
		{
			set launchButton:Pressed to true.
			set launchButton:Enabled to false.
		}

        LGUI_Show().
    }
    
    // Trigger GLC
	if totalControlled > 0
		runpath("0:/launch/GroundLaunchControl", engineStart, { return targetOrbit. }, launchButton, totalControlled).
	else
		runpath("0:/launch/GroundLaunchControl", engineStart).

    // Check if we actually lifted off
    if Ship:Status = "Flying"
    {
		local canCoast is core:tag:contains("coast").
		local canLoft is core:tag:contains("loft").
	
        // Clear tag and boot file So they don't affect ships in flight / orbit.
        Set Core:Tag to "".
        Set Core:BootFileName to "".
    
        // Trigger flight control
        if totalControlled <= 0
        {
            runpath("0:/launch/FlightControlUnguided", maxApoapsis).
        }
        else
        {
            // Reverify orbit paramters
            if targetOrbit:IsType("Orbit")
            {
                set targetInclination to max(Ship:Latitude, min(targetOrbit:Inclination, 180 - Ship:Latitude)).
                set launchAzimuth to CalcAzimuth().
                
                if RendezvousLaunchSouth()
                    set launchAzimuth to mod(360 + 180 - launchAzimuth, 360).
            }
            else if targetOrbit = Sun and targetInclination <= 90
            {
                set targetInclination to arccos(vdot(Body:AngularVel:Normalized, Sun:Position:Normalized)).
                if targetInclination > 90
                    set targetInclination to 180 - targetInclination.
                set launchAzimuth to CalcAzimuth().
                
                if TerminatorLaunchSouth()
                    set launchAzimuth to mod(360 + 180 - launchAzimuth, 360).
            }
                
            print "Launch parameters: " + round(targetInclination, 2) + "° inc, " + round(launchAzimuth, 2) + "° azimuth".
        
            LGUI_Hide().
            
            writejson(list(pitchOverSpeed, pitchOverAngle, launchAzimuth, targetInclination, targetOrbitable, canCoast, canLoft), "1:/launch.json").
            runpath("0:/launch/FlightControlPitchOver", pitchOverSpeed, pitchOverAngle, launchAzimuth, targetInclination, targetOrbitable, canCoast, canLoft).
        }
    }
    else
    {
        print "Ship not flying: " + Ship:Status.
    }
}
else if Ship:Status = "Flying"
{
    if exists("1:/launch.json")
    {
        local p is readjson("1:/launch.json").
        
        print "Resuming launch: " + round(p[3], 2) + "° inc, " + round(p[2], 2) + "° azimuth".
        
        runoncepath("0:/launch/LASFunctions").
        runpath("0:/launch/Staging").
		if defined LAS_TargetSMA or LAS_TargetAp > 100
            runpath("0:/launch/OrbitalGuidance").
        
        runpath("0:/launch/FlightControlPitchOver", p[0], p[1], p[2], p[3], p[4], p[5], p[6]).
    }
}
