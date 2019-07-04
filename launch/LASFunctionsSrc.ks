// Generic functions for the LAS

@lazyglobal off.

runoncepath("/FCFuncs").

global function LAS_GetStageParts
{
    parameter stageNum is Stage:Number.
    parameter moduleFilter is "".

    local allParts is Ship:Parts.
    
    local stageParts is list().
    for p in allParts
    {
        if p:Stage = stageNum
        {
            if moduleFilter:Length = 0 or p:HasModule(moduleFilter)
            {
                stageParts:Add(p).
            }
        }
    }
    
    return stageParts.
}

global function LAS_GetPartParam
{
    parameter shipPart.
    parameter tagString.
    parameter defValue is 0.

    local value is defValue.
    if shipPart:Tag:Contains(tagString)
    {
        local f is shipPart:Tag:Find(tagString) + tagString:Length.
        set value to shipPart:Tag:Substring(f, shipPart:Tag:Length - f):Split(" ")[0]:ToNumber(defValue).
    }
    
    return value.
}

local EngineBurnTime is lexicon().
local EngineIgnitionTime is lexicon().

// Auto configure on run
{
    local allEngines is list().
    list engines in allEngines.

    for eng in allEngines
    {
        local burnTime is LAS_GetPartParam(eng, "t=", -1).
        set EngineBurnTime[eng] to burnTime.
        set EngineIgnitionTime[eng] to -1.
    }
}

global function LAS_GetEngineBurnTime
{
    parameter eng.
    
    if EngineBurnTime:HasKey(eng) and EngineBurnTime[eng] > 0
    {
        // If engine has been ignited, return remaining time to burn.
        if EngineIgnitionTime[eng] >= 0
            return max(EngineBurnTime[eng] - (MissionTime - EngineIgnitionTime[eng]), 0).
        else
            return EngineBurnTime[eng].
    }
        
    return -1.
}

global function LAS_IgniteEngine
{
    parameter eng.
    
    set EngineIgnitionTime[eng] to MissionTime.
    eng:Activate().
}

global function LAS_GetStageBurnTime
{
    parameter stageEngines is list().
    
    if stageEngines:empty()
        set stageEngines to LAS_GetStageEngines().

    local massFlow is 0.
    local maxBurnTime is 0.
    for eng in stageEngines
    {
        local burnTime is LAS_GetEngineBurnTime(eng).
        if burnTime >= 0
            set maxBurnTime to max(burnTime, maxBurnTime).
        else
            set maxBurnTime to 100000.  // Just set a large number so we ignore this
    
        set massFlow to massFlow + eng:FuelFlow.
    }
    
    if massFlow = 0
        return 0.
    
    local stageRes is Stage:ResourcesLex.
    local fuelMass is 0.
    for res in stageRes:Values
    {
        // Only consider resources that are being used
        if res:Amount > 0 and res:Amount < res:Capacity
        {
            set fuelMass to fuelMass + res:Amount * res:Density * 1000.
        }
    }
    
    return min(maxBurnTime, fuelMass / massFlow).
}

global function LAS_FormatTime
{
    parameter t.

    local fmt is "".
    if t > (30 * 3600)
        set fmt to round(t / (24 * 3600), 1):ToString() + " days.".
    else if t > (90 * 60)
        set fmt to round(t / 3600, 1):ToString() + " hours.".
    else if t > 90
        set fmt to round(t / 60, 1):ToString() + " minutes.".
    else
        set fmt to round(t, 0):ToString() + " seconds.".
        
    return fmt.
}
