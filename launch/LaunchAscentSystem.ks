// Launch ascent system
// Overall control of launching and ascent

@lazyglobal off.

parameter engineStart is -1.    // Engine start time relative to T+0, -1 to autoconfigure.

// Wait for unpack
wait until Ship:Unpacked.

// Must be prelaunch for system to activate (allows for reboots after liftoff).
if Ship:Status = "PreLaunch"
{
    // Open terminal
    Core:Part:GetModule("kOSProcessor"):DoEvent("Open Terminal").
    
    switch to 0.
   
    // Setup functions
    runpath("0:/launch/LASFunctions").
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

    if guidance
    {
        print "Avionics unit detected.".
        
        runpath("0:/launch/OrbitalGuidance").
        
        set pitchOverSpeed to LAS_GetPartParam(Ship:RootPart, "spd=", pitchOverSpeed).
        set pitchOverAngle to LAS_GetPartParam(Ship:RootPart, "ang=", pitchOverAngle).
        set launchAzimuth to LAS_GetPartParam(Ship:RootPart, "az=", launchAzimuth).
        set targetInclination to LAS_GetPartParam(Ship:RootPart, "inc=", targetInclination).
    }
    else
    {
        print "No avionics unit detected, assuming unguided.".
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
    local inclinationLabel is createLabel("Inclination").
    local inclinationText is createControl(targetInclination:ToString, { parameter str. set targetInclination to str:ToNumber(targetInclination). }).
    
    if guidance
        flightGui:Show().
    
    // Trigger GLC
    runpath("0:/launch/GroundLaunchControl", engineStart).

    // Check if we actually lifted off
    if Ship:Status = "Flying"
    {
        // Trigger flight control
        if not guidance
        {
            runpath("0:/launch/FlightControlUnguided").
        }
        else
        {
            set speedText:Enabled to false.
            set angleText:Enabled to false.
            set azimuthText:Enabled to false.
            set inclinationText:Enabled to false.
            runpath("0:/launch/FlightControlPitchOver", pitchOverSpeed, pitchOverAngle, launchAzimuth, targetInclination).
        }
    }
}
