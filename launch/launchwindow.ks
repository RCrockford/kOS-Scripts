// Launch window planning for direct ascent

@lazyglobal off.

parameter targetObt.
parameter flightTime.

// Wait for unpack
wait until Ship:Unpacked.

// Must be prelaunch for system to activate (allows for reboots after liftoff).
if Ship:Status = "PreLaunch"
{
    Core:DoEvent("Open Terminal").
    
    switch to 0.

    runoncepath("0:/launch/lasfunctions").

    local meanAngMotion is 360 / targetObt:Orbit:Period.

    // Lead angle from launch site
    local leadAngle is flightTime * meanAngMotion.
    // we start 180 degrees from the target (i.e. we aim to impact at apoapsis).
    set leadAngle to 180 - leadAngle.

    // mean anomaly of target to achieve intercept.
    local interceptMeanAnomaly is (leadAngle - 90) - targetObt:Orbit:ArgumentOfPeriapsis.
    set interceptMeanAnomaly to mod(interceptMeanAnomaly + 360, 360).

    lock meanAnomaly to targetObt:Orbit:MeanAnomalyAtEpoch + meanAngMotion * (Time:Seconds - targetObt:Orbit:Epoch).

    local windowTime is (interceptMeanAnomaly - meanAnomaly).
    if windowTime < -5
        set windowTime to windowTime + 360.
    set windowTime to max(windowTime - 10, 0) / meanAngMotion.
    
    // Just make sure the moon is opposite us around the Earth
    local targetLong is Ship:Longitude + leadAngle.
    local longDiff is mod(targetObt:Longitude - targetLong + 360, 360).
    
    set windowTime to longDiff * Ship:Body:RotationPeriod / 360.
    set windowTime to windowTime + (meanAngMotion * windowTime) * Ship:Body:RotationPeriod / 360.

    print "Launch window opening in " + LAS_FormatTime(windowTime).

    if windowTime > 120 and Addons:Available("KAC")
    {
        // Add a KAC alarm.
        AddAlarm("Raw", windowTime - 60 + Time:Seconds, Ship:Name + " Launch Window", Ship:Name + " is nearing its launch window").
    }
    
    local waitGui is GUI(200).
    local mainBox is waitGui:AddVBox().

    local guiHeading is mainBox:AddLabel("Awaiting launch window").
    local guiTime is mainBox:AddLabel("MA: " + round(meanAnomaly, 1) + ", Target: " + round(interceptMeanAnomaly, 1)).

    waitGui:Show().
    
    // Wait until we're within 10 degrees.
    //until (meanAnomaly - interceptMeanAnomaly) < 5 and (meanAnomaly - interceptMeanAnomaly) > -10
    until abs(targetObt:Longitude - targetLong) < 0.2
    {
        //set guiTime:text to "MA: " + round(meanAnomaly, 1) + ", Target: " + round(interceptMeanAnomaly, 1).
        set guiTime:text to "Long: " + round(targetObt:Longitude, 1) + ", Target: " + round(targetLong, 1).
        wait 1.
    }
	
    kUniverse:Timewarp:CancelWarp().
    waitGui:Hide().
}