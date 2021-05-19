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

local ResourceAliases is lexicon("LqdHydrogen", list("LH2")).

local function GetConnectedResources
{
    parameter p.
    parameter res.
    parameter seen.
	parameter eng.

    if p:FuelCrossfeed or seen:Length = 1	// ignore crossfeed if directly connected
    {
		for r in p:resources
		{
			if r:Enabled
			{
				local nameList is list(r:Name).
				if ResourceAliases:HasKey(r:Name)
				{
					for a in ResourceAliases[r:Name]
						nameList:Add(a).
				}
				
				for name in nameList
				{
					if res:HasKey(name)
						set res[name] to res[name] + r:amount.
					else
						res:Add(name, r:amount).
				}
			}
		}
	}	
	
    seen:Add(p).
	
	// Connected engines
	if p:IsType("Engine")
	{
		if res:HasKey("eng")
			res["eng"]:add(p).
		else
			res:Add("eng", list(p)).
	}	
	
    // Don't consider crossfeed for solid fuel engines
	if p:FuelCrossfeed and eng:AllowShutdown
	{
        if p:HasParent and not seen:contains(p:parent)
        {
            set res to GetConnectedResources(p:parent, res, seen, eng).
        }
        for c in p:children
        {
            if not seen:contains(c)
                set res to GetConnectedResources(c, res, seen, eng).
        }
    }
    
    return res.
}

local EngineStats is lexicon().

// Auto configure on run
{
    local allEngines is list().
    list engines in allEngines.

    for eng in allEngines
    {
        EngineStats:Add(eng, lexicon()).
    
        local burnTime is LAS_GetPartParam(eng, "t=", -1).
        EngineStats[eng]:Add("burnTime", burnTime).
        EngineStats[eng]:Add("igniteTime", -1).

        local engRes is GetConnectedResources(eng, lexicon(), uniqueset(), eng).
		
		local resConsumption is lexicon().
        for k in engRes:keys
        {
			resConsumption:add(k, 0).
		}
		
		for e in engRes["eng"]
		{
			for k in e:ConsumedResources:keys
			{
				local r is e:ConsumedResources[k].
				if resConsumption:HasKey(r:Name)
				{
					set resConsumption[r:Name] to resConsumption[r:Name] + r:MaxFuelFlow.
				}
			}
		}
        
        local fuelTime is 1e6.
		local resShare is 1.
        for k in eng:ConsumedResources:keys
        {
            local r is eng:ConsumedResources[k].
            if engRes:HasKey(r:Name)
            {
                if resConsumption[r:Name] > 0
                {
                    set fuelTime to min(fuelTime, engRes[r:Name] / resConsumption[r:Name]).
                    set resShare to min(resShare, r:MaxFuelFlow / resConsumption[r:Name]).
                }
            }
            else
            {
				//print eng:Config + " missing fuel " + r:name.
                set fuelTime to 0.
            }
        }
        
        EngineStats[eng]:Add("fuelTime", fuelTime).
        EngineStats[eng]:Add("resShare", resShare).
		
		//if not LAS_EngineIsUllage(eng)
			//print "Eng " + eng:Config + " t=" + round(fuelTime, 1) + " s=" + round(resShare, 3).
    }
}

global function LAS_GetEngineBurnTime
{
    parameter eng.
    
    if EngineStats[eng]:burnTime > 0
    {
        // If engine has been ignited, return remaining time to burn.
        if EngineStats[eng]:IgniteTime >= 0
            return max(EngineStats[eng]:burnTime - (MissionTime - EngineStats[eng]:IgniteTime), 0).
        else
            return EngineStats[eng]:burnTime.
    }
        
    return -1.
}

global function LAS_GetRealEngineBurnTime
{
    parameter eng.
    parameter checkFO is true.
    
    if checkFO and eng:Flameout
        return 0.
    
    local burnTime is LAS_GetEngineBurnTime(eng).
    if burnTime < 0
    {
        if eng:Ignition
        {
            set burnTime to 1e6.
            for k in eng:ConsumedResources:keys
            {
                local r is eng:ConsumedResources[k].
                set burnTime to min(burnTime, r:Amount * EngineStats[eng]:resShare / r:MaxFuelFlow).
            }
        }
        else
        {
            set burnTime to EngineStats[eng]:fuelTime.
        }
    }
    
    return burnTime.
}

global function LAS_IgniteEngine
{
    parameter eng.
    
    set EngineStats[eng]:IgniteTime to MissionTime.
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

global function LAS_FormatNumber
{
    parameter n.
    parameter dp.
    
    local s is round(n, dp):ToString.
    local p is s:FindLast(".").
    if p = -1
        return s + ".0000000000":SubString(0, 1 + dp).
    if p >= s:Length - dp
        return s + "0000000000":SubString(0, 1 + dp - (s:Length - p)).
    return s.
}

global function LAS_GetStagePerformance
{
	parameter s.
    parameter fromGuidance.

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
		local engStage is min(eng:DecoupledIn + 1, eng:stage).
        local valid is not LAS_EngineIsUllage(eng).
        if fromGuidance and valid
            set valid to not (eng:Tag:Contains("nostage") or eng:Tag:Contains("noguide")).
		if engStage = s and valid
		{
			local t is LAS_GetRealEngineBurnTime(eng).
            if t >= 10 or not fromGuidance
            {
                set massFlow to massFlow + eng:MaxMassFlow.
                set stageThrust to stageThrust + eng:PossibleThrustAt(0).
                
                set burnTime to max(burnTime, t).

                set perf:guided to perf:guided or eng:HasGimbal or eng:HasModule("ModuleRCSFX").

                set decoupler to eng:Decoupler.
                set litPrevStage to litPrevStage or eng:Stage > s.
            }
		}
        
        if fromGuidance and engStage > s and eng:Tag:Contains("lastguide")
        {
            set massFlow to 0.
            set stageThrust to 0.
            break.
        }
	}

	if not decoupler:IsType("Decoupler")
		set decoupler to Ship:RootPart.

	local stageWetMass is 0.
	local stageDryMass is 0.

	for shipPart in Ship:Parts
	{
		if not shipPart:HasModule("LaunchClamp") and not (shipPart:tag:Contains("les") and shipPart:IsType("Engine"))
		{
			// Because decoupler tanks don't report correctly.
			local decoupleStage is shipPart:DecoupledIn.
			if shipPart:IsType("decoupler")
				set decoupleStage to max(shipPart:DecoupledIn, shipPart:Stage).
		
			if decoupleStage < s and decoupleStage >= decoupler:stage
			{
				set stageWetMass to stageWetMass + shipPart:Mass.
				set stageDryMass to stageDryMass + shipPart:DryMass.

				set perf:guided to perf:guided or shipPart:IsType("RCS").
			}
			else if decoupleStage < decoupler:stage
			{
				set stageWetMass to stageWetMass + shipPart:Mass.
				set stageDryMass to stageDryMass + shipPart:Mass.
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

global function LAS_PrintEngineReliability
{
    if not addons:available("tf")
        return.

	local allEngines is list().
    list engines in allEngines.
    
    local successRate is 1.
	
	from {local s is stage:number.} until s < 0 step {set s to s - 1.} do
	{
        for eng in allEngines
        {
            local engStage is min(eng:DecoupledIn + 1, eng:stage).
            if engStage = s and not LAS_EngineIsUllage(eng) and Addons:TF:MTBF(eng) >= 0
            {
                local t is LAS_GetRealEngineBurnTime(eng).
                
                local engName is eng:Config.
                if engName:Length > 16
                    set engName to engName:SubString(0,16).
                else
                    set engName to engName:PadRight(16).
                    
                print engName + " Rel: " + LAS_FormatNumber(100 * Addons:TF:Reliability(eng, t), 3) + "% Ign: " +  + LAS_FormatNumber(100 * Addons:TF:IgnitionChance(eng), 3) + "% t: " + LAS_FormatNumber(t, 1):PadLeft(5) + " / " + round(Addons:TF:RatedBurnTime(eng)) + "s".
                set successRate to successRate * Addons:TF:Reliability(eng, t) * Addons:TF:IgnitionChance(eng).
            }
        }
    }
    print "Estimated mission success rate: " + LAS_FormatNumber(100 * successRate, 3) + "%".
}