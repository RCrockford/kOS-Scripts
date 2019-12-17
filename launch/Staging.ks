// Staging functionality functions for the LAS

@lazyglobal off.

local StageEngines is list().
local NextStageEngines is list().
local NextStageDecouplers is list().
local NextStageUllage is list().
local NextStageChutes is list().
local ShutdownEngines is list().

local StagingFunction is CheckStageType@.

local LAS_IsParachuting is false.
local nextStageHasRCS is false.
local engineSpooling is true.

local function StageFlameout
{
    parameter anyEngine.

    local allFlamedOut is true.
    local anyFlamedOut is false.
    local allSpooled is true.

    for eng in stageEngines
    {
        // If any engine is producing less than 10% nominal thrust, consider it burned out.
        if not eng:Flameout() and (engineSpooling or eng:Thrust >= eng:PossibleThrust * 0.1)
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
    
    if allSpooled
        set engineSpooling to false.

    if anyEngine
        return anyFlamedOut.
    else
        return allFlamedOut.
}

local function DecoupleStage
{
    if not NextStageDecouplers:empty
    {
        // Fire all decouplers
        for decoup in NextStageDecouplers
        {
            local modDecouple is 0.
			if decoup:HasModule("ModuleDecouple")
				set modDecouple to decoup:GetModule("ModuleDecouple").
			else
				set modDecouple to decoup:GetModule("ModuleAnchoredDecoupler").
            if modDecouple:HasEvent("decouple")
                modDecouple:DoEvent("decouple").
            else if modDecouple:HasEvent("decouple top node")
                modDecouple:DoEvent("decouple top node").
        }

        set NextStageDecouplers to list().
        
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
    local drop is StageFlameout(true).

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

// LF engine with ullage motors (part 2).
local function UllageStageSettle
{
    local fuelState is LAS_GetFuelStability(NextStageEngines).
    
    if fuelState >= 99
    {
        // Fire engines (i.e. stage).
		print "Fuel Stability: " + round(fuelState, 1) + "%".
        return true.
    }
    
    // Check ullage motor burn time
    local burnTime is 0.
    if LAS_EngineIsSolidFuel(NextStageUllage[0])
    {
        local fuelMass is 0.
        for res in NextStageUllage[0]:Resources
        {
            set fuelMass to fuelMass + res:Amount * res:Density * 1000.
        }
        
        set burnTime to fuelMass / NextStageUllage[0]:FuelFlow.
    }
    else
    {
        // Not sure this will work. Better to add functions to kOS maybe.
        set burnTime to LAS_GetStageBurnTime(NextStageUllage).
    }
    
	// If less than 0.05 seconds to go, just go for it
	if burnTime < 0.05
	{
		print "Fuel Stability: " + round(fuelState, 1) + "%".
		return true.
	}
	
    // Ramp up ignition chance as we get near ullage burnout
	// Allows stable (95%) igntion at ~0.235s, 75% at ~0.15s, 50% at ~0.07s
    if sqrt(4 * (burnTime - 0.01)) < (fuelState * 0.01)
	{
		print "Fuel Stability: " + round(fuelState, 1) + "%".
		return true.
	}
	
	return false.
}

local heightWarn is false.
local pressureWarn is false.

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
        if not StageFlameout(false)
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
    
    // Detach lower stage.
    if DecoupleStage()
        print "Stage " + Stage:Number + " separation.".

    // Fire ullage motors.
    for eng in NextStageUllage
    {
        LAS_IgniteEngine(eng).
    }
    
    set StagingFunction to UllageStageSettle@.

    return false.
}

// Parachute descent stage.
local function ParachuteDescent
{
    // Wait until we're descending.
    if Ship:VerticalSpeed > 0
    {
        return false.
    }

    // Do we have decouplers? If so drop boost stage at 80 km.
	if Ship:Altitude <= 80000 or GetBatteryProportion() < 0.05
	{
		if DecoupleStage()
			print "Decoupling return capsule.".
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
        return StageFlameout(true) or LAS_GetStageBurnTime(stageEngines) < burnTime.

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

    set ShutdownEngines to list().
    set NextStageDecouplers to list().
    set NextStageChutes to list().

    for p in NextStageParts
    {
        if (p:HasModule("ModuleDecouple") or p:HasModule("ModuleAnchoredDecoupler")) and not p:Tag:Contains("payload")
            NextStageDecouplers:add(p).
        if p:HasModule("RealChuteModule")
            NextStageChutes:add(p).
        if p:HasModule("ModuleRCSFX")
            set nextStageHasRCS to true.
    }

    local enginesNeedStartup is false.
    for eng in NextStageEngines
    {
        if not LAS_EngineIsSolidFuel(eng) and not eng:Ignition
            set enginesNeedStartup to true.
    }

    if enginesNeedStartup
    {
        // Engine staging
        if not NextStageUllage:empty
        {
            set StagingFunction to UllageStageSeparate@.
            print "Next stage: Ullage".
            set heightWarn to false.
            set pressureWarn to false.
        }
        else
        {
            set StagingFunction to HotStage@.
            set HotStageWarmup to 0.6.
            // Check if we need to wait for turbopump spool.
            for eng in NextStageEngines
            {
                if not LAS_EngineIsPressureFed(eng) and not LAS_EngineIsSolidFuel(eng)
                    set HotStageWarmup to 2.5.
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

global function LAS_CheckStaging
{
    if not Stage:Ready
        return false.

    if StagingFunction()
    {
        if nextStageHasRCS
            rcs on.
    
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
                    print "Shutting down " + eng:Title.
                    eng:Shutdown().
                }
            }
        }
    }
    
    return false.
}

global function LAS_FinalStage
{
	return StagingFunction = FinalStage@.
}

