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
    
    switch to 0.
   
    // Setup functions
    runoncepath("0:/launch/LASFunctions").
    runpath("0:/launch/Staging").
    
    local shipParts is list().
    list parts in shipParts.
    local guidance is false.
    for p in shipParts
    {
        if p:HasModule("ModuleProceduralAvionics")
        {
            set guidance to true.
            break.
        }
    }
    
    local pitchOverSpeed is 100.
    local pitchOverAngle is 4.
    local launchAzimuth is 90.
    local targetInclination is -1.
    local targetOrbitable is 0.
    local maxApoapsis is -1.

    if guidance
    {
        print "Avionics unit detected.".
        
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
        set newControl:Enabled to guidance.
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
        if targetInclination >= 0
        {
            local targetPe is LAS_TargetPe * 1000 + Ship:Body:Radius.
            local a is (LAS_TargetPe + LAS_TargetAp) * 500 + Ship:Body:Radius.
            local sinInertialAz is max(-1, min(cos(targetInclination)/cos(Ship:Latitude),1)).
            local vOrbit is sqrt(2 * Ship:Body:Mu / targetPe - Ship:Body:Mu / a).
            local vEqRot is 2 * Constant:pi * Ship:Body:Radius / Ship:Body:RotationPeriod.
            // Using the identity sin2 + cos2 = 1 to avoid inverse trig.
            set launchAzimuth to mod(arctan2(vOrbit * sinInertialAz - vEqRot * cos(Ship:Latitude), vOrbit * sqrt(1 - sinInertialAz^2)) + 360, 360).
            
            set azimuthText:text to round(launchAzimuth, 3):ToString.
        }

        set azimuthText:Enabled to targetInclination < 0.
    }
    
    local inclinationLabel is createLabel("Inclination").
    local inclinationText is createControl(targetInclination:ToString, { parameter str. set targetInclination to str:ToNumber(targetInclination). setAzimuth(). }).
    
    if guidance
    {
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
        
        setAzimuth().

        flightGui:Show().
    }
    
    // Trigger GLC
    runpath("0:/launch/GroundLaunchControl", engineStart, targetOrbit).

    // Check if we actually lifted off
    if Ship:Status = "Flying"
    {
        // Clear tag and boot file So they don't affect ships in flight / orbit.
        Set Core:Tag to "".
        Set Core:BootFileName to "".
    
        // Trigger flight control
        if not guidance
        {
            runpath("0:/launch/FlightControlUnguided", maxApoapsis).
        }
        else
        {
            flightGui:Hide().
            runpath("0:/launch/FlightControlPitchOver", pitchOverSpeed, pitchOverAngle, launchAzimuth, targetInclination, targetOrbitable).
        }
    }
    else
    {
        print "Ship not flying: " + Ship:Status.
    }
}
