// ReEntry burn
@lazyglobal off.

parameter targetPe is 70.       // In km
// Lat or long depending on orbital inclination. If inclination is > 60 degrees then it's lat.
parameter burnLatLong is 200.   // Default to immediate.

// Wait for unpack
wait until Ship:Unpacked.

if Ship:Status = "Sub_Orbital" or Ship:Status = "Orbiting"
{
    switch to 0.

	local orientLatLong is 200.
    if abs(burnLatLong) > 180
    {
        print "Re-entry immediately, target Pe: " + round(targetPe, 1) + " km.".
    }
    else if abs(Ship:Obt:Inclination) > 60 and abs(Ship:Obt:Inclination) < 120
    {
        print "Re-entry at Lat: " + burnLatLong + ", target Pe: " + round(targetPe, 1) + " km.".

        set orientLatLong to burnLatLong - 360 * (30 / Ship:Obt:Period).    // Lead by 30 seconds for orientation.
        if orientLatLong < -90
            set orientLatLong to -180 - orientLatLong.
        if orientLatLong > 90
            set orientLatLong to 180 - orientLatLong.
            
        print "Orient at Lat: " + round(orientLatLong, 2).
    }
    else
    {
        print "Re-entry at Long: " + burnLatLong + ", target Pe: " + round(targetPe, 1) + " km.".

        set orientLatLong to burnLatLong - 360 * (30 / Ship:Obt:Period).    // Lead by 30 seconds for orientation.
        if orientLatLong < -180
            set orientLatLong to orientLatLong + 360.
        if orientLatLong > 180
            set orientLatLong to orientLatLong - 360.
            
        print "Orient at Long: " + round(orientLatLong, 2).
    }
	
    runpath("0:/flight/enginemgmt", Stage:Number).
	runpath("0:/flight/tunesteering").
    
    local fileList is list().
    local burnParams is lexicon("pe", targetPe * 1000).
    
    if EM_GetEngines():empty and abs(burnLatLong) > 180
    {
        LAS_Avionics("activate").

		for rcs in Ship:ModulesNamed("ModuleRCSFX")
		{
			if rcs:HasField("rcs")
			{
				rcs:SetField("rcs", true).
			}
		}

        // Cheap version, RCS only, immediate.
        runoncepath("0:/flight/rcsperf").
        if GetRCSForePerf():Thrust < GetRCSAftPerf():Thrust * 0.5
            fileList:Add("reentry/reentryrcspro.ks").
        else
            fileList:Add("reentry/reentryrcs.ks").
    }
    else
    {
        burnParams:Add("oLatLong", orientLatLong).
        burnParams:Add("bLatLong", burnLatLong).
        burnParams:Add("engines", EM_GetEngines():Length).
        
        fileList:Add("reentry/reentryburn.ks").
        fileList:add("fcfuncs").
        if burnParams:engines > 0
            fileList:add("flight/enginemgmt.ks").
    }
    fileList:add("reentry/reentrylanding.ks").
	print "Using " + fileList[0].

    runpath("0:/flight/setupburn", burnParams, fileList, "re-entry").
}
