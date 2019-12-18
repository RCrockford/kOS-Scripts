@lazyglobal off.

parameter maxApoapsis is -1.

// Some basic telemetry.
local maxQ is Ship:Q.

local function checkMaxQ
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

local PL_Fairings is list().
local PL_FairingsJettisoned is false.

local function checkPayload
{
    if not PL_FairingsJettisoned
    {
        if Ship:Q < 0.001
        {
            // Jettison fairings
			local jettisoned is false.
            for f in PL_Fairings
            {
                if f:HasEvent("jettison fairing")
				{
                    f:DoEvent("jettison fairing").
					set jettisoned to true.
				}
            }
            
            if jettisoned
                print "Fairings jettisoned".
            
            set PL_FairingsJettisoned to true.
        }
    }
}

for shipPart in Ship:Parts
{
    if shipPart:HasModule("ProceduralFairingDecoupler")
    {
        PL_Fairings:Add(shipPart:GetModule("ProceduralFairingDecoupler")).
    }
}

until False
{
    if maxQ > 0
        checkMaxQ().
	else
		checkPayload().
    
    LAS_CheckStaging().
	
	if Ship:Control:PilotMainThrottle > 0 and maxApoapsis > 0 and Ship:Orbit:Apoapsis > maxApoapsis * 1000
	{
        print "Sustainer engine cutoff".
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
