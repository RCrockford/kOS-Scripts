// Staging functionality functions for the LAS

@lazyglobal off.

local StageEngines is list().
local NextStageEngines is list().
local NextStageDecouplers is list().
local NextStageFairings is uniqueset().
local NextStageUllage is list().
local NextStageChutes is list().
local NextStageRCS is list().
local ShutdownEngines is list().

local StagingFunction is CheckStageType@.

local LAS_IsParachuting is false.
local engineSpooling is true.

local PL_FairingsJettisoned is false.
local PL_PanelsExtended is false.

local kscPos is Ship:GeoPosition.

global function LAS_FireDecoupler
{
	parameter decoup.

	local modDecouple is 0.
	if decoup:HasModule("ModuleDecouple")
		set modDecouple to decoup:GetModule("ModuleDecouple").
	else if decoup:HasModule("ModuleAnchoredDecoupler")
		set modDecouple to decoup:GetModule("ModuleAnchoredDecoupler").
	else
		return.
	
	if modDecouple:HasEvent("decouple")
		modDecouple:DoEvent("decouple").
	else if modDecouple:HasEvent("decouple top node")
		modDecouple:DoEvent("decouple top node").
	else if modDecouple:HasEvent("decoupler staging")
		modDecouple:DoEvent("decoupler staging").
}

local function StageFlameout
{
    parameter s.

    local allFlamedOut is true.
    local anyFlamedOut is false.
    local allSpooled is true.

    for eng in stageEngines
    {
		if (s < 0) or (eng:DecoupledIn = s)
		{
			local hasThrust is false.
			// If any liquid fuelled engine is producing less than 10% nominal thrust, consider it burned out.
			if eng:AllowShutdown
				set hasThrust to engineSpooling or eng:Thrust >= eng:PossibleThrust * 0.1.
			else
			// Solid fuel are considered burned out when TWR is below 1.
				set hasThrust to eng:Thrust >= (eng:Mass * Ship:Body:Mu / LAS_ShipPos():SqrMagnitude).
			if not eng:Flameout and hasThrust
			{
				set allFlamedOut to false.
				if eng:Thrust < eng:PossibleThrust * 0.1
					set allSpooled to false.
			}
			else
			{
				set anyFlamedOut to true.
			}
		}
    }
    
    if allSpooled
        set engineSpooling to false.

    if s < 0
        return anyFlamedOut.
    else
        return allFlamedOut.
}

local function DecoupleStage
{
    if not NextStageDecouplers:empty
    {
        for fairing in NextStageFairings
        {
            if fairing:HasEvent("jettison fairing")
                fairing:DoEvent("jettison fairing").
        }
        NextStageFairings:Clear().
    
        // Fire all decouplers
        for decoup in NextStageDecouplers
        {
			LAS_FireDecoupler(decoup).
        }

        NextStageDecouplers:Clear().
        
        return true.
    }
    
    return false.
}

local function IgniteNextStage
{
    print "Igniting stage " + (Stage:Number - 1) + " engines.".

    // Ignite engines for next stage
    for eng in NextStageEngines
    {
        LAS_IgniteEngine(eng).
    }
}

local function GetBatteryProportion
{
	local shipRes is Ship:Resources.
	for r in ShipRes
	{
		if r:Name = "ElectricCharge"
		{
			return r:Amount / r:Capacity.
		}
	}
	
	return 0.
}

// Simple booster drop, just wait for flameout.
local function BoosterDrop
{
    local drop is StageFlameout(Stage:Number - 1).

    if drop
    {
        print "Stage " + Stage:Number + " separation.".
    }

    return drop.
}

// Hot engine swap, wait for spool and then disable the current stage
local function HotSwap
{
    local swap is false.
    for eng in NextStageEngines
    {
        if eng:Thrust > eng:PossibleThrust * 0.8
            set swap to true.
    }

    if swap
    {
        // Switch off old engines
        for eng in ShutdownEngines
        {
            eng:Shutdown().
        }
    }
    
    return swap.
}

local HotStageWarmup is 0.

// Hot staged liquid fuel engine.
local function HotStage
{
    local burnTime is LAS_GetStageBurnTime(stageEngines).
    
    if Terminal:Input:HasChar() and Terminal:Input:GetChar() = "s"
    {
        print "Forcing separation".
        set burnTime to 0.
    }

    if burnTime <= HotStageWarmup
    {
        IgniteNextStage().

        if not NextStageDecouplers:Empty
        {
            // Use booster drop functionality to wait for flame out.
            set StagingFunction to BoosterDrop@.
        }
        else
        {
			set ShutdownEngines to StageEngines.		
            set StagingFunction to HotSwap@.
        }
    }

    return false.
}

// LF engine with ullage motors (part 3).
local function UllageStageSettle
{
    local fuelState is 1.
    for eng in NextStageEngines
        set fuelState to min(fuelState, eng:FuelStability).
    
    if fuelState >= 0.99
    {
        // Fire engines (i.e. stage).
		print "Fuel Stability: " + round(fuelState * 100, 1) + "%".
		set ship:control:fore to 0.
        return true.
    }

    if not NextStageUllage:empty
    {
        // Out of atmosphere just allow the ship to drift after the motors cut off and hope for stable ignition.
        if Ship:Q > 0
        {
            // Check ullage motor burn time
            local burnTime is LAS_GetRealEngineBurnTime(NextStageUllage[0]).
            
            // If less than 0.05 seconds to go, just go for it
            if burnTime < 0.05
            {
                print "Fuel Stability: " + round(fuelState * 100, 1) + "%".
                set ship:control:fore to 0.
                return true.
            }
            
            // Ramp up ignition chance as we get near ullage burnout
            // Allows stable (95%) igntion at ~0.235s, 75% at ~0.15s, 50% at ~0.07s
            if sqrt(4 * (burnTime - 0.01)) < fuelState
            {
                print "Fuel Stability: " + round(fuelState * 0.01, 1) + "%".
                set ship:control:fore to 0.
                return true.
            }
        }
        else if NextStageUllage[0]:Flameout and NextStageRCS
        {
            // Try RCS.
            rcs on.
            for r in NextStageRCS
                set r:enabled to true.
            set ship:control:fore to 1.
        }
    }

	return false.
}

// LF engine with ullage motors (part 2).
local function UllageStageFire
{
	if NextStageUllage:empty
	{
		rcs on.
		for r in NextStageRCS
			set r:enabled to true.
		set ship:control:fore to 1.
	}
	else
	{
        set Ship:Control:PilotMainThrottle to 1.
		// Fire ullage motors.
		for eng in NextStageUllage
		{
			LAS_IgniteEngine(eng).
		}
	}
    
    set StagingFunction to UllageStageSettle@.
}

local heightWarn is false.
local pressureWarn is false.
local apoWarn is false.

// LF engine with ullage motors (part 1).
local function UllageStageSeparate
{
    if Terminal:Input:HasChar() and Terminal:Input:GetChar() = "s"
    {
        print "Forcing separation".
        print "  Eng FO=" + stageEngines[0]:FlameOut + ", Ig=" + stageEngines[0]:Ignition.
        
        for eng in stageEngines
        {
            eng:Shutdown().
        }
    }
    else
    {
        // Wait for flame out
        if not StageFlameout(Stage:number - 1)
            return false.
        
        local minHeight is LAS_GetPartParam(NextStageEngines[0], "h=", -1).
        if (Ship:Altitude < minHeight)
        {
            if not heightWarn
            {
                print "Separation at " + minHeight + " m.".
                set heightWarn to true.
            }

            return false.
        }
        
        local apoTime is LAS_GetPartParam(NextStageEngines[0], "a=", -1).
        if apoTime >= 0 and ETA:Apoapsis > apoTime
        {
            if not apoWarn
            {
                print "Separation in " + round(ETA:Apoapsis - apoTime, 1) + " s.".
                set apoWarn to true.
            }

            return false.
        }
		
		local maxPressure is LAS_GetPartParam(NextStageEngines[0], "p=", 10).   // 10 kPa is a default ignition chance of 92.5%, 100% at 5 kPA.
        if (Ship:Q * constant:AtmToKPa > maxPressure)
        {
            if not pressureWarn
            {
                print "Presssure too high to stage (" + round(Ship:Q * constant:AtmToKPa, 1) + " kPa), separation at " + maxPressure + " kPa.".
                set pressureWarn to true.
            }

            return false.
        }
    }
	
	set Ship:Control:Fore to 0.
	set Ship:Control:PilotMainThrottle to 1.
    
    // Detach lower stage.
    if DecoupleStage()
        print "Stage " + Stage:Number + " separation.".
		
    set StagingFunction to UllageStageFire@.

    return false.
}

local maxAltitude is 0.

// Parachute descent stage.
local function ParachuteDescent
{
    // Wait until we're descending.
    if Ship:VerticalSpeed > 0
    {
        return false.
    }
	
	set maxAltitude to max(Ship:Altitude, maxAltitude).
	if maxAltitude < 5000
		return false.

    // Do we have decouplers? If so drop boost stage at 80 km.
	if Ship:Altitude <= 80000 or GetBatteryProportion() < 0.05
	{
		if DecoupleStage()
		{
			print "Decoupling return capsule.".
			set StageEngines to LAS_GetStageEngines().
		}
	}

    // Arm chutes as soon as we hit atmosphere.
    if Ship:Q > 1e-8 and not LAS_IsParachuting
    {
        set LAS_IsParachuting to true.
        
        local chutesArmed is false.
        for chute in NextStageChutes
        {
            local modRealChute is chute:GetModule("RealChuteModule").
            if modRealChute:HasEvent("arm parachute")
            {
                modRealChute:DoEvent("arm parachute").
                set chutesArmed to true.
            }
        }
        
        print "Parachutes armed.".
        
        // If we couldn't arm the chutes, just stage.
        return not chutesArmed.
    }

    return false.
}

// Spin stage
local function SpinUp
{
    local minHeight is LAS_GetPartParam(NextStageUllage[0], "h=", -1).
    if minHeight > 0
        return Ship:Altitude >= minHeight.
        
    local burnTime is LAS_GetPartParam(NextStageUllage[0], "t=", -1).
    if burnTime > 0
        return StageFlameout(-1) or LAS_GetStageBurnTime(stageEngines) < burnTime.

    return Alt:Radar >= 30.
}

// Final stage
local function FinalStage
{
    // Do nothing
    return false.
}

// Unknown / not determined yet
local function CheckStageType
{
    set StageEngines to LAS_GetStageEngines().
    local NextStageParts is list().

    if Stage:Number > 0
    {
        set NextStageEngines to LAS_GetStageEngines(Stage:Number - 1).
        set NextStageUllage to LAS_GetStageEngines(Stage:Number - 1, true).
        set NextStageParts to LAS_GetStageParts(Stage:Number - 1).
    }
    else
    {
        set NextStageEngines to list().
        set NextStageUllage to list().
    }

    ShutdownEngines:Clear().
    NextStageDecouplers:Clear().
    NextStageChutes:Clear().

    for p in NextStageParts
    {
        if (p:HasModule("ModuleDecouple") or p:HasModule("ModuleAnchoredDecoupler")) and not p:Tag:Contains("payload")
            NextStageDecouplers:add(p).
        if p:HasModule("ProceduralFairingDecoupler") and p:GetModule("ProceduralFairingDecoupler"):HasEvent("jettison fairing")
            NextStageFairings:add(p:GetModule("ProceduralFairingDecoupler")).
        if p:HasModule("RealChuteModule")
            NextStageChutes:add(p).
        if p:IsType("RCS")
            NextStageRCS:add(p).
    }

    local enginesNeedStartup is false.
    for eng in NextStageEngines
    {
		if eng:Tag:Contains("nostage")
		{
            set StagingFunction to FinalStage@.
            print "Next stage: Final".
			return.
		}
	
        if eng:AllowShutdown and not eng:Ignition
            set enginesNeedStartup to true.
    }

    if enginesNeedStartup
    {
        // Engine staging
        if not NextStageUllage:empty or not NextStageRCS:empty
        {
            set StagingFunction to UllageStageSeparate@.
            print "Next stage: Ullage" + (choose " (rcs)" if NextStageUllage:empty else "").
            set heightWarn to false.
			set pressureWarn to false.
            set apoWarn to false.
        }
        else
        {
            set StagingFunction to HotStage@.
            set HotStageWarmup to 0.8.
            // Check if we need to wait for turbopump spool.
            for eng in NextStageEngines
            {
                if not eng:PressureFed and eng:AllowShutdown
                    set HotStageWarmup to max(HotStageWarmup, 2.5).
				set HotStageWarmup to max(LAS_GetPartParam(eng, "s=", 0), HotStageWarmup).
            }
            print "Next stage: Hot Stage (" + HotStageWarmup + ")".
        }
    }
    else
    {
        if not NextStageUllage:empty and NextStageUllage[0]:Tag:Contains("spin")
        {
            // Have spin motors.
            set StagingFunction to SpinUp@.
            print "Next stage: Spin".
        }
        else if not NextStageChutes:empty
        {
            // Have parachutes, go into descent mode.
            set StagingFunction to ParachuteDescent@.
            print "Next stage: Parachute".
        }
        else if not NextStageDecouplers:empty
        {
            // Just a decoupler, assume this is a booster drop.
            set StagingFunction to BoosterDrop@.
            print "Next stage: Booster Drop".
        }
        else
        {
            // Nothing found.
            set StagingFunction to FinalStage@.
            print "Next stage: Final".
        }
    }
}

local function EnableECForStage
{
    parameter s.
    
    local ECEnabled is 0.
    
    until ECEnabled >= 100 or s < -1
    {
        for p in Ship:Parts
        {
            if p:DecoupledIn = s
            {
                for r in p:resources
                {
                    if r:Name = "Electric Charge"
                    {
                        set r:Enabled to true.
                        set ECEnabled to ECEnabled + r:Amount.
                    }
                }
            }
        }
        set s to s - 1.
    }
}

local function CheckAbort
{    
	local allEngines is list().
    list engines in allEngines.
	
	local doAbort is false.
	if LAS_HasEscapeSystem
	{
		local shipThrust is 0.
		for eng in allEngines
			set shipThrust to shipThrust + eng:Thrust.
		local twr is ShipThrust / (Ship:Mass * Ship:Body:Mu / LAS_ShipPos():SqrMagnitude).
		
		if Ship:Q > 0.1 and Ship:Q * vang(Facing:Vector, SrfPrograde:Vector) > 2
		{
			print "Ship violated Qα constraint (" + round(Ship:Q * vang(Facing:Vector, SrfPrograde:Vector), 2) + "), aborting launch.".
			set doAbort to true.
		}
		if alt:radar < 25000 and TWR < 1.05 - Alt:Radar * 1e-5
		{
			print "Ship violated TWR constraint (" + round(twr, 2) + "), aborting launch.".
			set doAbort to true.
		}
		if Ship:VerticalSpeed < 0
		{
			print "Ship violated vertical speed constraint, aborting launch.".
			set doAbort to true.
		}
	}
	else
	{
		// If less than 1.5 second to ground impact
		if Alt:Radar < -Ship:VerticalSpeed * 1.5
			set doAbort to (Ship:GeoPosition:Position - kscPos:Position):Mag < 1200.
	}

	if doAbort
	{
		// Shutdown all engines
		for eng in allEngines
		{
			eng:Shutdown().
		}
		
		HudText("RSO: Commanded ship destruction.", 5, 2, 15, red, false).

		// Tell all other CPUs to destroy themselves.
		for cpu in Ship:ModulesNamed("kOSProcessor")
		{
			if cpu <> Core
				cpu:Connection:SendMessage("RSO").
		}

		LAS_CrewEscape().

		if Ship:Crew:Empty
			Core:Part:GetModule("ModuleRangeSafety"):DoAction("Range Safety", true).
	}
}

global function LAS_CheckStaging
{
    if not Stage:Ready
        return false.
		
	CheckAbort().

    if StagingFunction()
    {
        EnableECForStage(Stage:Number - 1).
    
        stage.

        set StagingFunction to CheckStageType@.
        set engineSpooling to true.
        
        return true.
    }
    else
    {
        // Check engines for timed burns.
        for eng in stageEngines
        {
            if eng:Ignition
            {
                local burnTime is LAS_GetEngineBurnTime(eng).
                if burnTime = 0
                {
                    print "Shutting down " + eng:Config.
                    eng:Shutdown().
                }
            }
        }
    }
    
    return false.
}

global function LAS_NextStageIsUllage
{
	return StagingFunction = UllageStageFire@.
}

global function LAS_FinalStage
{
	return StagingFunction = FinalStage@.
}

global function LAS_StageReady
{
	return StagingFunction <> CheckStageType@.
}

global function LAS_EnableAllEC
{
    for p in Ship:Parts
    {
        for r in p:resources
        {
            if r:Name = "Electric Charge"
            {
                set r:Enabled to true.
            }
        }
    }
}

global function LAS_CheckPayload
{
    if not PL_FairingsJettisoned
    {
        if Ship:Q < 5e-3
        {
            // Jettison fairings
			local jettisoned is false.
			for fairing in Ship:ModulesNamed("ProceduralFairingDecoupler")
            {
                if fairing:HasEvent("jettison fairing") and not fairing:part:tag:contains("nojettison")
                {
                    if NextStageFairings:Contains(fairing)
                        NextStageFairings:Remove(fairing).
                    
                    fairing:DoEvent("jettison fairing").
                    set jettisoned to true.
                }
            }
            
            if jettisoned
                print "Fairings jettisoned".
            
            set PL_FairingsJettisoned to true.
        }
    }
    else if not PL_PanelsExtended
    {
        if Ship:Q < 1e-5
        {
			for panel in Ship:ModulesNamed("ModuleROSolar")
            {
                if panel:HasAction("extend solar panel") and not panel:part:tag:contains("noextend")
                {
                    panel:DoAction("extend solar panel", true).
                }
            }
			for panel in Ship:ModulesNamed("ModuleDeployableSolarPanel")
            {
                if panel:HasAction("extend solar panel") and not panel:part:tag:contains("noextend")
                {
                    panel:DoAction("extend solar panel", true).
                }
            }
			
			for antenna in Ship:ModulesNamed("ModuleDeployableAntenna")
            {
                if antenna:HasEvent("extend antenna") and not antenna:part:tag:contains("noextend")
                {
                    antenna:DoEvent("extend antenna").
                }
            }
			
            set PL_PanelsExtended to true.
        }
    }
}