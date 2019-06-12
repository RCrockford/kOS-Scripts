@lazyglobal off.

local ignitionDelay is 0.
local activeEngines is list().

// Setup active engine list
set stageEngines to LAS_GetStageEngines().

for eng in stageEngines
{
    if not eng:Title:Contains("Separation") and not eng:Tag:Contains("ullage")
    {
        if not eng:HasModule("ModuleEnginesRF") or eng:GetModule("ModuleEnginesRF"):GetField("ignitions remaining"):ToNumber(0) > 0
        {
            activeEngines:Add(eng).
        }
    }
}

for eng in activeEngines
{
    // 1 second more than nominal ignition time for ullage.
    if not LAS_EngineIsSolidFuel(eng)
    {
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
    local currentThrust is 0.

    // If we have engines, prep them to ignite.
    if not activeEngines:empty
    {
        print "Performing ullage for main engines".

        // Burn forwards with RCS.
        rcs on.
        set Ship:Control:Fore to 1.
        
        local fuelState is "Unstable".
        
        wait until LAS_GetFuelStability(activeEngines) >= 99.
        
        set Ship:Control:MainThrottle to 1.
        
        for eng in activeEngines
        {
            eng:Activate().
            set currentThrust to currentThrust + eng:PossibleThrust.
        }

        wait 0.
        set Ship:Control:Fore to 0.
    }
    
    return currentThrust.
}