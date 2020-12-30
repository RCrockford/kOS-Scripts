@lazyglobal off.

parameter burnStage.

local ignitionDelay is 0.
local needsUllage is false.
local activeEngines is list().

runoncepath("/FCFuncs").

// Setup active engine list
local stageEngines is LAS_GetStageEngines(burnStage).

for e in stageEngines
{
    if e:Ignitions <> 0 or e:Ignition
    {
        activeEngines:Add(e).
        
        if e:Ullage
            set needsUllage to true.
        if not e:PressureFed    // Assume all pumped engines have spool time (for 8096C which is pumped but not ullaged)
            set ignitionDelay to max(ignitionDelay, 2.39).
        else if e:Ullage
            set ignitionDelay to max(ignitionDelay, 0.91).
    }
}

global function EM_IgDelay
{
    return ignitionDelay.
}

global function EM_GetEngines
{
    return activeEngines.
}

global function EM_CheckThrust
{
    parameter p.

    return activeEngines[0]:Thrust > activeEngines[0]:PossibleThrust * p.
}
    
global function EM_Ignition
{
    // If we have engines, prep them to ignite.
    if not activeEngines:empty
    {
        for e in activeEngines
            e:Shutdown.
			
        // Burn forwards with RCS.
        if needsUllage
        {
            rcs on.
            set Ship:Control:Fore to 1.
        }
        set Ship:Control:PilotMainThrottle to 1.
        
        for e in activeEngines
            wait until e:FuelStability >= 0.99.
        
        for e in activeEngines
            e:Activate.
			
		local t is time:seconds + 3.

        wait until EM_CheckThrust(0.5) or activeEngines[0]:Flameout or time:seconds > t.
        
        set Ship:Control:Fore to 0.
    }
    
    return not activeEngines:empty.
}

global function EM_Shutdown
{
    // Cutoff engines
    for e in activeEngines
        e:Shutdown.
    if not activeEngines:empty
        print "MECO".

    unlock steering.
    set Ship:Control:Neutralize to true.
    set Ship:Control:PilotMainThrottle to 0.
    rcs off.

    LAS_Avionics("shutdown").
}