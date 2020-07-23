// Launch ascent system
// Overall control of launching and ascent

@lazyglobal off.

parameter engineStart is -1.    // Engine start time relative to T+0, -1 to autoconfigure.
parameter targetOrbit is 0.

// Wait for unpack
wait until Ship:Unpacked.

// Must be prelaunch for system to activate (allows for reboots after liftoff).
if Ship:Status = "PreLaunch"
{
    // Open terminal
    Core:DoEvent("Open Terminal").
	set Terminal:Height to max(Terminal:Height, 50).
    
    switch to 0.
   
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
    local pitchOverAngle is 3.
    local launchAzimuth is 90.
    local targetInclination is -1.
    local targetOrbitable is 0.
    local maxApoapsis is -1.

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
			runpath("0:/launch/OrbitalGuidance").
        
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

    local flightGui is Gui(250).
    set flightGui:X to 100.
    set flightGui:Y to flightGui:Y + 50.
    local mainBox is flightGui:AddHBox().
    local labelBox is mainBox:AddVBox().
    set labelBox:style:width to 150.
    local controlBox is mainBox:AddVBox().
    set controlBox:style:width to 100.
	local launchButton is flightGui:AddButton("Launch").
    
    local function createLabel
    {
        parameter str.
        local newLabel is labelBox:AddLabel(str).
        set newLabel:Style:Height to 25.
        return newLabel.
    }
    local function createControl
    {
        parameter str.
        parameter dlg.
        local newControl is controlBox:AddTextField(str).
        set newControl:Style:Height to 25.
        set newControl:OnConfirm to dlg.
        set newControl:Enabled to totalControlled > 0.
        return newControl.
    }
    
    local speedLabel is createLabel("Speed").
    local speedText is createControl(pitchOverSpeed:ToString, { parameter str. set pitchOverSpeed to str:ToNumber(pitchOverSpeed). }).
    local angleLabel is createLabel("Angle").
    local angleText is createControl(pitchOverAngle:ToString, { parameter str. set pitchOverAngle to str:ToNumber(pitchOverAngle). }).
    local azimuthLabel is createLabel("Azimuth").
    local azimuthText is createControl(launchAzimuth:ToString, { parameter str. set launchAzimuth to str:ToNumber(launchAzimuth). }).

    local function setAzimuth
    {
		parameter south is false.
	
        if targetInclination >= 0
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
            set launchAzimuth to mod(arctan2(vOrbit * sinInertialAz - vEqRot * cos(Ship:Latitude), vOrbit * sqrt(1 - sinInertialAz^2)) + 360, 360).
			
			if south
				set launchAzimuth to mod(360 + 180 - launchAzimuth, 360).
            
            set azimuthText:text to round(launchAzimuth, 3):ToString.
        }

        set azimuthText:Enabled to targetInclination < 0.
    }
    
    local inclinationLabel is createLabel("Inclination").
    local inclinationText is createControl(targetInclination:ToString, {
		parameter str.
		set targetInclination to str:replace("s", ""):ToNumber(targetInclination).
		setAzimuth(str:contains("s")).
	}).
    
    if totalControlled > 0
    {
		local launchSouth is false.
        if targetOrbit:IsType("Orbitable")
        {
            set targetOrbitable to targetOrbit.
            set targetInclination to -1.
            set inclinationText:Text to "Target (" + targetOrbitable:Name + ")".
            set inclinationText:Enabled to false.
        }
        else if targetOrbit:IsType("Orbit")
        {
            set targetInclination to max(Ship:Latitude, min(targetOrbit:Inclination, 180 - Ship:Latitude)).
            set inclinationText:Text to round(targetInclination, 2):ToString.
        }
		else if defined LAS_TargetInc
		{
            set targetInclination to max(Ship:Latitude, min(abs(LAS_TargetInc), 180 - Ship:Latitude)).
            set inclinationText:Text to round(targetInclination, 2):ToString.
			set launchSouth to (defined LAS_TargetInc and LAS_TargetInc < 0).
		}
		else
		{
			set launchSouth to targetInclination >= 0 and (Ship:Latitude < 0).// or (Ship:Longitude > -122 and Ship:Longitude < -78)).	// Southerly launches by default from North America.
            set inclinationText:Text to round(targetInclination, 2):ToString + (choose "s" if launchSouth else "").
		}
        
        setAzimuth(launchSouth).
		
		// Preset launch, just go straight into countdown.
		if defined LAS_LaunchTime
		{
			set launchButton:Pressed to true.
			set launchButton:Enabled to false.
		}

        flightGui:Show().
    }
    
    // Trigger GLC
	if totalControlled > 0
		runpath("0:/launch/GroundLaunchControl", engineStart, targetOrbit, launchButton, totalControlled).
	else
		runpath("0:/launch/GroundLaunchControl", engineStart).

    // Check if we actually lifted off
    if Ship:Status = "Flying"
    {
		local canCoast is core:tag:contains("coast").
	
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
            flightGui:Hide().
            runpath("0:/launch/FlightControlPitchOver", pitchOverSpeed, pitchOverAngle, launchAzimuth, targetInclination, targetOrbitable, canCoast).
        }
    }
    else
    {
        print "Ship not flying: " + Ship:Status.
    }
}
