@lazyglobal off.

parameter burnStage.

local ignitionDelay is 0.
local activeEngines is list().

// Setup active engine list
local stageEngines is LAS_GetStageEngines(burnStage).

for eng in stageEngines
{
    if not eng:HasModule("ModuleEnginesRF") or eng:GetModule("ModuleEnginesRF"):GetField("ignitions remaining") > 0
    {
        activeEngines:Add(eng).
    }
}

for eng in activeEngines
{
    if not LAS_EngineIsSolidFuel(eng)
    {
        // Add half a second for ullage.
        if LAS_EngineIsPressureFed(eng)
            set ignitionDelay to max(ignitionDelay, 1).
        else
            set ignitionDelay to max(ignitionDelay, 3).
    }
}

global function EM_GetIgnitionDelay
{
    return ignitionDelay.
}

global function EM_GetManoeuvreEngines
{
    return activeEngines.
}
    
global function EM_IgniteManoeuvreEngines
{
    // If we have engines, prep them to ignite.
    if not activeEngines:empty
    {
        // Burn forwards with RCS.
        rcs on.
        set Ship:Control:Fore to 1.
        
        print "Manoeuvre engine ullage".
        
        wait until LAS_GetFuelStability(activeEngines) >= 99.
        
        set Ship:Control:PilotMainThrottle to 1.
        
        for eng in activeEngines
        {
            eng:Activate().
        }

        wait 0.
        set Ship:Control:Fore to 0.
    }
    
    return not activeEngines:empty.
}
