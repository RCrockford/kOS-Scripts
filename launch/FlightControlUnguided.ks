@lazyglobal off.

parameter maxApoapsis is -1.

// Some basic telemetry.
local maxQ is Ship:Q.

local function checkMaxQ
{
    if maxQ > 0
    {
        if maxQ > Ship:Q and Ship:Altitude > 5000
        {
            print "Max Q: " + round(maxQ * constant:AtmToKPa, 2) + " kPa.".
            set maxQ to -1.
        }
        else
        {
            set maxQ to Ship:Q.
        }
    }
}

until False
{
    if maxQ > 0
        checkMaxQ().
    
    LAS_CheckStaging().
	
	if Ship:Control:PilotMainThrottle > 0 and maxApoapsis > 0 and Ship:Orbit:Apoapsis > maxApoapsis * 1000
	{
        print "Main engine cutoff".
        set Ship:Control:PilotMainThrottle to 0.
		
		local mainEngines is LAS_GetStageEngines().
        for eng in mainEngines
        {
            if eng:AllowShutdown
                eng:Shutdown().
        }
	}
    
    wait 0.05.
}

print "Auto launch disengaged.".

// Release control
set Ship:Control:Neutralize to true.
