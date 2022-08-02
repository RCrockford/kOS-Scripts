@lazyglobal off.

parameter burnStage.

local ignitionDelay is 0.
local needsUllage is false.
local activeEngines is list().

runoncepath("/FCFuncs").

// Lead time for manoeuvres
global function EM_CalcSpoolTime
{
    parameter eng.
    
    if eng:HasModule("ModuleEnginesRF")
    {
        local engMod is eng:GetModule("ModuleEnginesRF").
        return engMod:Getfield("effective spool-up time").
    }
    return 0.1.
}

global function EM_ResetEngines
{
    parameter newStage.
    
    // Setup active engine list
    set burnStage to newStage.
    local stageEngines is LAS_GetStageEngines(burnStage).
    
    set needsUllage to false.
    set ignitionDelay to 0.
    activeEngines:Clear().

    for e in stageEngines
    {
        if e:Ignitions <> 0 or e:Ignition
        {
            activeEngines:Add(e).
            
            if e:Ullage
                set needsUllage to true.
            if e:Ullage or not e:PressureFed
                set ignitionDelay to EM_CalcSpoolTime(e).
        }
    }
}

EM_ResetEngines(burnStage).

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
    parameter minThrust is 0.25.

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

		local t is time:seconds + 0.2.
        for e in activeEngines
        {
            e:Activate.
            set t to max(t, time:seconds + EM_CalcSpoolTime(e) * 2).
        }

        wait until EM_CheckThrust(minThrust) or activeEngines[0]:Flameout or time:seconds > t.

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