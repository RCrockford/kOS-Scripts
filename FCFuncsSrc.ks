// Generic functions

@lazyglobal off.

global lock LAS_ShipPos to -Ship:Body:Position.

global function LAS_EngineIsSolidFuel
{
    parameter eng.
    
    return not eng:AllowShutdown.
}

global function LAS_EngineIsPressureFed
{
    parameter eng.
    
    if eng:HasModule("ModuleEnginesRF")
    {
        local rfModule is eng:GetModule("ModuleEnginesRF").
        if rfModule:HasField("pressurefed")
            return rfModule:GetField("pressurefed").
        // Just in case the field doesn't read correctly.
        if eng:HasModule("ModuleTagEngineLiquidPF")
            return true.
    }
    
    return false.
}

local function EngIsUllage
{
    parameter eng.
    
    return eng:Title:Contains("Separation") or eng:Title:Contains("Spin") or eng:Tag:Contains("ullage").
}

global function LAS_GetStageEngines
{
    parameter stageNum is Stage:Number.
    parameter ullage is false.
    
    local allEngines is list().
    list engines in allEngines.
    
    if Ship:Status = "PreLaunch"
        set stageNum to min(stageNum, Stage:Number - 1).
    
    local stageEngines is list().
    for eng in allEngines
    {
        if eng:Stage = stageNum and EngIsUllage(eng) = ullage
        {
            stageEngines:Add(eng).
        }
    }
    
    return stageEngines.
}

global function LAS_GetFuelStability
{
    parameter activeEngines.

    local fuelState is "(99%)".

    // Wait for fuel to settle.
    for eng in activeEngines
    {
        if not LAS_EngineIsSolidFuel(eng) and eng:HasModule("ModuleEnginesRF")
        {
            local rfModule is eng:GetModule("ModuleEnginesRF").
            if rfModule:HasField("propellant")
            {
                set fuelState to rfModule:GetField("propellant").
                break.
            }
        }
    }
	
    if fuelState:Contains("(")
    {
        local f is fuelState:Find("(") + 1.
        set fuelState to fuelState:Substring(f, fuelState:Length - f):Split("%")[0]:ToNumber(-1).
    }
    else
    {
        set fuelState to 0.
    }
    
    return fuelState.
}