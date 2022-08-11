@lazyglobal off.

parameter maxApoapsis is -1.

local kscPos is Ship:GeoPosition.

local debugGui is GUI(300, 80).
set debugGui:X to -150.
set debugGui:Y to debugGui:Y - 480.
local mainBox is debugGui:AddVBox().

local debugStat is mainBox:AddLabel("Liftoff").
debugGui:Show().

// Some basic telemetry.
local maxQ is Ship:Q.

local function checkMaxQ
{
	if maxQ > Ship:Q and Ship:Altitude > 5000
	{
		print METString + " Max Q: " + round(maxQ * constant:AtmToKPa, 2) + " kPa.".
		set maxQ to -1.
	}
	else
	{
		set maxQ to Ship:Q.
	}
}

local hotStartCheck is true.

until False
{
    if maxQ > 0
        checkMaxQ().
	else
		LAS_CheckPayload().

    LAS_CheckStaging().
    
    if hotStartCheck and not LAS_StageReady()
    {
        if Ship:Q * constant:AtmToKPa >= 4
        {
            for eng in Ship:Engines
            {
                if eng:Name:Contains("Aerobee")
                {
                    print METString + " Hot started " + eng:Config + " Q=" + round(Ship:Q * constant:AtmToKPa, 2) + " kPa.".
                    eng:Activate.
                }
            }
            set hotStartCheck to false.
        }
    }
	
	if navmode <> "surface"
		set navmode to "surface".
        
    local α is vang(Facing:Vector, SrfPrograde:Vector).
    if Ship:Control:PilotMainThrottle > 0 and α > 15
    {
        print METString + " α exceeded maximum allowed value: " + round(α, 1).
        set maxApoapsis to 1.
    }

	if Ship:Control:PilotMainThrottle > 0 and ((maxApoapsis > 0 and Ship:Orbit:Apoapsis > maxApoapsis * 1000) or Ship:Thrust = 0)
	{
        print METString + " Sustainer engine cutoff".
        set Ship:Control:PilotMainThrottle to 0.

		local mainEngines is LAS_GetStageEngines().
        for eng in mainEngines
        {
            if eng:AllowShutdown
                eng:Shutdown().
        }
	}
    
    if Alt:Radar < 50 and Ship:VerticalSpeed < 0 and kUniverse:Timewarp:Rate > 1
        set kUniverse:Timewarp:Rate to 1.

	set debugStat:Text to "Flight Q=" + round(Ship:Q * constant:AtmToKPa, 1) + " α=" + round(α, 2) + "° D=" + round((Ship:GeoPosition:Position - kscPos:Position):Mag * 0.001, 1) + "km".

    // Relatively low frequency to reduce power consumption.
    wait 0.1.
}

print "Auto launch disengaged.".
    
LAS_EnableAllEC().

// Release control
set Ship:Control:Neutralize to true.
