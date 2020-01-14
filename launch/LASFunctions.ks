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

local function GetConnectedResources
{
    parameter p.
    parameter res.
    parameter seen.

    for r in p:resources
    {
        if r:Enabled
        {
            if res:HasKey(r:name)
                set res[r:name] to res[r:name] + r:amount.
            else
                res:Add(r:name, r:amount).
        }
    }
    seen:Add(p).
    
    if p:FuelCrossfeed
    {
        if p:HasParent and not seen:contains(p:parent)
        {
            set res to GetConnectedResources(p:parent, res, seen).
        }
        for c in p:children
        {
            if not seen:contains(c)
                set res to GetConnectedResources(c, res, seen).
        }
    }
    
    return res.
}

local EngineBurnTime is lexicon().
local EngineFuelTime is lexicon().
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

        local engRes is GetConnectedResources(eng, lexicon(), uniqueset()).
        
        local fuelTime is 1e6.
        for k in eng:ConsumedResources:keys
        {
            local r is eng:ConsumedResources[k].
            if engRes:HasKey(r:Name)
            {
                set fuelTime to min(fuelTime, engRes[r:Name] / r:MaxFuelFlow).
            }
            else
            {
                set fuelTime to 0.
            }
        }
        set EngineFuelTime[eng] to fuelTime.
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

global function LAS_GetRealEngineBurnTime
{
    parameter eng.
    
    local burnTime is LAS_GetEngineBurnTime(eng).
    if burnTime < 0
    {
        if eng:Ignition or eng:Flameout
        {
            set burnTime to 1e6.
            for k in eng:ConsumedResources:keys
            {
                local r is eng:ConsumedResources[k].
                set burnTime to min(burnTime, r:Amount / r:MaxFuelFlow).
            }
        }
        else
        {
            set burnTime to EngineFuelTime[eng].
        }
    }
    
    return burnTime.
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

    local maxBurnTime is 0.
    for eng in stageEngines
    {
        local burnTime is LAS_GetRealEngineBurnTime(eng).
        set maxBurnTime to max(burnTime, maxBurnTime).
    }
    
    return maxBurnTime.
}

global function LAS_FormatTime
{
    parameter t.

    local fmt is "".
    if t > (30 * 3600)
        set fmt to round(t / (24 * 3600), 1):ToString() + " days".
    else if t > (90 * 60)
        set fmt to round(t / 3600, 1):ToString() + " hours".
    else if t > 90
        set fmt to round(t / 60, 1):ToString() + " minutes".
    else
        set fmt to round(t, 0):ToString() + " seconds".
        
    return fmt.
}

global function LAS_FormatTimeStamp
{
    parameter t.

	local divisors is list(24*3600, 3600, 60, 1).
	
	local negative is t < 0.
	set t to abs(t).

    local fmt is "".
	for d in divisors
	{
		local n is floor(t / d).
		if d = divisors[divisors:length-1]
			set n to round(t / d, 0).
		if negative
			set fmt to fmt + "-".
		else if n < 10
			set fmt to fmt + "0".
		set fmt to fmt + n + ":".
		set t to t - n*d.
		set negative to false.
	}
        
    return fmt:remove(fmt:length-1, 1).
}

global function LAS_GetStagePerformance
{
	parameter s.

	local allEngines is list().
    list engines in allEngines.

	local decoupler is Ship:RootPart.

	// Sum mass flow for each engine
	local massFlow is 0.
	local stageThrust is 0.
	local burnTime is -1.
	local litPrevStage is false.
	
	local perf is lexicon("guided", false, "eV", 0, "BurnTime", 0, "Accel", 0, "MassFlow", 0, "litPrevStage", false).

	for eng in allEngines
	{
		if eng:DecoupledIn = s - 1 and not LAS_EngineIsUllage(eng) and not eng:Tag:Contains("nostage")
		{
			set massFlow to massFlow + eng:MaxMassFlow.
			set stageThrust to stageThrust + eng:PossibleThrustAt(0).
			set burnTime to max(burnTime, LAS_GetRealEngineBurnTime(eng)).

			set perf:guided to perf:guided or eng:HasGimbal.

			set decoupler to eng:Decoupler.
			set litPrevStage to litPrevStage or eng:Stage > s.
		}
	}

	if not decoupler:IsType("Decoupler")
		set decoupler to Ship:RootPart.

	local stageWetMass is 0.
	local stageDryMass is 0.

	for shipPart in Ship:Parts
	{
		if not shipPart:HasModule("LaunchClamp")
		{
			// Because decoupler tanks don't report correctly.
			local decoupleStage is shipPart:DecoupledIn.
			if shipPart:IsType("decoupler")
				set decoupleStage to max(shipPart:DecoupledIn, shipPart:Stage).
		
			if decoupleStage < s and decoupleStage >= decoupler:stage
			{
				set stageWetMass to stageWetMass + shipPart:WetMass.
				set stageDryMass to stageDryMass + shipPart:DryMass.

				set perf:guided to perf:guided or shipPart:IsType("RCS").
			}
			else if decoupleStage < decoupler:stage
			{
				set stageWetMass to stageWetMass + shipPart:WetMass.
				set stageDryMass to stageDryMass + shipPart:WetMass.
			}
		}
	}
	
	perf:Add("DryMass", stageDryMass).
	perf:Add("WetMass", stageWetMass).

	if stageThrust > 0 and massFlow > 0
	{
        set perf:burnTime to burnTime.
		set perf:litPrevStage to litPrevStage.

		// Initial effective exhaust velocity and acceleration
		set perf:MassFlow to MassFlow.
		set perf:eV to stageThrust / massFlow.
		set perf:Accel to stageThrust / max(stageWetMass, 1e-6).
	}
	
	return perf.
}