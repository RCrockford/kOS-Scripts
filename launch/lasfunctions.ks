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

runoncepath("/mgmt/ResourceWalk").

local EngineStats is lexicon().

// Auto configure on run
{
    for eng in ship:engines
    {
        EngineStats:Add(eng, lexicon()).
    
        local burnTime is LAS_GetPartParam(eng, "t=", -1).
        EngineStats[eng]:Add("burnTime", burnTime).
        EngineStats[eng]:Add("igniteTime", -1).

        local engRes is GetConnectedResources(eng).
		
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
        
        local burnProp is 1 - eng:Residuals.
        
        local fuelTime is 1e6.
		local resShare is 1.
        for k in eng:ConsumedResources:keys
        {
            local r is eng:ConsumedResources[k].
            if engRes:HasKey(r:Name)
            {
                if resConsumption[r:Name] > 0
                {
                    set fuelTime to min(fuelTime, (engRes[r:Name]:amount * burnProp) / resConsumption[r:Name]).
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
    
    if EngineStats:HasKey(eng) and EngineStats[eng]:burnTime > 0
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
                local residuals is eng:Residuals * r:Capacity.
                set burnTime to min(burnTime, (r:Amount - residuals) * EngineStats[eng]:resShare / r:MaxFuelFlow).
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
    parameter debug is false.

	local decoupler is Ship:RootPart.

	// Sum mass flow for each engine
	local massFlow is 0.
	local stageThrust is 0.
	local burnTime is -1.
	local litPrevStage is false.
	
	local perf is lexicon("guided", false, "eV", 0, "BurnTime", 0, "Accel", 0, "MassFlow", 0, "litPrevStage", false).
    
    if debug
        print "Stage " + s + " Debug".

	for eng in ship:engines
	{
		local engStage is choose min(eng:DecoupledIn + 1, eng:stage) if eng:DecoupledIn >= 0 else eng:stage.
        if engStage = s
        {
            local valid is not LAS_EngineIsUllage(eng).
            if debug and (not valid)
                print "  Engine " + eng:Config + " flagged as ullage".
            if fromGuidance and valid
            {
                set valid to not (eng:Tag:Contains("nostage") or eng:Tag:Contains("noguide")).
                if debug and (not valid)
                    print "  Engine " + eng:Config + " tagged for no guidance".
            }
            if valid
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

                    if debug
                        print "  Engine " + eng:Config + " added to stage".
                }
                else if debug
                    print "  Engine " + eng:Config + " burn time < 10s".
            }
        }
        
        if fromGuidance and engStage > s and eng:Tag:Contains("lastguide")
        {
            if debug
                print "  Engine " + eng:Config + " tagged last guide, skipping others".
            set massFlow to 0.
            set stageThrust to 0.
            break.
        }
	}

	if not decoupler:IsType("Decoupler")
		set decoupler to Ship:RootPart.

	local stageWetMass is 0.

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
				set perf:guided to perf:guided or shipPart:IsType("RCS").
			}
			else if decoupleStage < decoupler:stage
			{
				set stageWetMass to stageWetMass + shipPart:Mass.
			}
		}
	}
	
	perf:Add("WetMass", stageWetMass).
	perf:Add("DryMass", stageWetMass - massFlow * burnTime).

	if stageThrust > 0 and massFlow > 0
	{
        set perf:burnTime to burnTime.
		set perf:litPrevStage to litPrevStage.

		// Initial effective exhaust velocity and acceleration
		set perf:MassFlow to MassFlow.
		set perf:eV to stageThrust / massFlow.
		set perf:Accel to stageThrust / max(stageWetMass, 1e-6).
	}
    
    if debug
        print "  Stage thrust=" + round(stageThrust, 2) + ", massflow=" + round(massFlow, 4).
	
	return perf.
}

global function LAS_PrintEngineReliability
{
    parameter launchStage is Stage:Number.

    if not addons:available("tf")
        return.

    local successRate is 1.
    local postLaunchSuccess is 1.
	
	from {local s is stage:number.} until s < 0 step {set s to s - 1.} do
	{
        local prevEngine is "".
        for eng in ship:engines
        {
            local engStage is min(eng:DecoupledIn + 1, eng:stage).
            if engStage = s and not LAS_EngineIsUllage(eng) and Addons:TF:MTBF(eng) >= 0 and not eng:Name:Contains("vernier") and not eng:Name:Contains("lr101")
            {
                local t is LAS_GetRealEngineBurnTime(eng).
                
                if eng:Config <> prevEngine
                {
                    set prevEngine to eng:Config.
                    local engName is eng:Config.
                    if engName:Length > 16
                        set engName to engName:SubString(0,16).
                    else
                        set engName to engName:PadRight(16).
                        
                    print engName + " Rel: " + LAS_FormatNumber(100 * Addons:TF:Reliability(eng, t), 3) + "% Ign: " +  + LAS_FormatNumber(100 * Addons:TF:IgnitionChance(eng), 3) + "% t: " + LAS_FormatNumber(t, 1):PadLeft(5) + " / " + round(Addons:TF:RatedBurnTime(eng)) + "s".
                }
                local reliability is Addons:TF:Reliability(eng, t) * Addons:TF:IgnitionChance(eng).
                set successRate to successRate * reliability.
                if s < launchStage
                    set postLaunchSuccess to postLaunchSuccess * reliability.
                else
                    set postLaunchSuccess to postLaunchSuccess * Addons:TF:Reliability(eng, t).
            }
        }
    }
    print "Estimated mission success rate: " + LAS_FormatNumber(100 * successRate, 2) + "%".
    print "Estimated post launch success rate: " + LAS_FormatNumber(100 * postLaunchSuccess, 2) + "%".
}