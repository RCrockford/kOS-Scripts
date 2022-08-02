// Orbital manoeuvres using KSP flight planner

@lazyglobal off.

parameter spinRate.
parameter rcsBurn is false.
parameter spinKick is false.
parameter tangent is 0.
parameter normal is 0.
parameter binormal is 0.
parameter burnStart is 0.

// Wait for unpack
wait until Ship:Unpacked.

switch to scriptpath():volume.

local dV is 0.

if not HasNode
{
    set dV to V(tangent, normal, binormal).
    set burnStart to time:Seconds + burnStart.
    lock burnEta to burnStart - time:Seconds.
}
else
{
    set dV to NextNode:DeltaV.
    lock burnEta to NextNode:eta.
}
runoncepath("0:/FCFuncs").
runoncepath("0:/flight/FlightFuncs").
runoncepath("0:/mgmt/ResourceWalk").

local burnStage is stage:Number.
local activeEngines is list().
local fuelName is 0.
local fuelTotal is 0.
local fuelCapacity is 0.
local maxFuelFlow is 0.
local massFlow is 0.
local burnThrust is 0.
local residuals is 0.
local shipMass is Ship:Mass.

if rcsBurn
{
    runoncepath("0:/flight/RCSPerf.ks").
    local RCSPerf is GetRCSForePerf().
	
	set massFlow to RCSPerf:massFlow.
	set burnThrust to RCSPerf:thrust.
}
else
{
    if spinKick
        set burnStage to burnStage - 1.

    runpath("0:/flight/EngineMgmt", burnStage).
    if EM_GetEngines():Length = 0
    {
        local eng is list().
        list engines in eng.
        if eng:Length = 1 and not eng[0]:AllowShutdown
        {
            set burnStage to burnStage - 1.
            runpath("0:/flight/EngineMgmt", burnStage).
        }
    }
    
    set activeEngines to EM_GetEngines().
    if activeEngines:Length = 0
    {
        print "No active engines for stage " + burnStage.
    }
    else
    {
        for eng in activeEngines
        {
            set massFlow to massFlow + eng:MaxMassFlow.
            set burnThrust to burnThrust + eng:PossibleThrust.
            set residuals to max(residuals, eng:residuals).
        }
        
        set shipMass to 0.
        for shipPart in Ship:Parts
        {
            local partStage is choose shipPart:Stage if shipPart:IsType("Decoupler") else shipPart:DecoupledIn.
            if partStage < burnStage
                set shipMass to shipMass + shipPart:Mass.
        }

        local activeResources is GetConnectedResources(activeEngines[0]).
        
        local maxFlow is 0.
        for k in activeEngines[0]:ConsumedResources:keys
        {
            local res is activeEngines[0]:ConsumedResources[k].
            if res:Density > 0 and activeResources:HasKey(res:Name) and res:Name = k
            {
                if res:MaxMassFlow > maxFlow
                {
                    set fuelName to res:Name.
                    set fuelTotal to activeResources[res:Name]:Amount.
                    set fuelCapacity to activeResources[res:Name]:Capacity.
                    set maxFlow to res:MaxMassFlow.
                }
            }
        }
        
        set maxFuelFlow to 0.
        for eng in activeEngines
        {
            if eng:ConsumedResources:HasKey(fuelName)
            {
                local res is eng:ConsumedResources[fuelName].
                set maxFuelFlow to maxFuelFlow + res:MaxFuelFlow.
            }
        }
    }
}

if CheckControl() and massFlow > 0
{
	// Calc burn duration
	local massRatio is constant:e ^ (dV:Mag * massflow / burnThrust).
	local finalMass is shipMass / massRatio.
	local duration is (shipMass - finalMass) / massflow.
    
    // Calc alignment time
    runpath("0:/flight/AlignTime").
    local alignMargin is GetAlignTime().

	print "Executing manoeuvre in " + FormatTime(burnEta).
	print "  DeltaV: " + round(dV:Mag, 1) + " m/s.".
	print "  Duration: " + round(duration, 1) + " s.".
	print "  Align at: T-" + round(alignMargin, 1) + " s.".
	if not rcsBurn
    {
        if fuelTotal > 0
        {
            local finalFuel is fuelTotal - maxFuelFlow * duration.
            print "  Fuel: " + fuelName + " " + round(fuelTotal, 2) + " => " + round(fuelTotal - maxFuelFlow * duration, 2) +
                " (" + round(100 * finalFuel / fuelCapacity, 2) + "% / " + round(100 * residuals, 2) + "%)".
        }
        if activeEngines:Length > 0 and addons:available("tf")
        {
            local eng is activeEngines[0].
            local ratedTime is Addons:TF:RatedBurnTime(eng).
            if ratedTime > 0
            {
                local burnTime is Addons:TF:RunTime(eng) + duration.
                print "  Reliability: " + round(100 * Addons:TF:Reliability(eng, burnTime), 2) + "% Ignition: " +  + round(100 * Addons:TF:IgnitionChance(eng), 2) + "% t: " + round(burnTime, 1) + " / " + round(ratedTime) + "s".
            }
        }
    }
	if rcsBurn
	{
		print "  RCS burn.".
		set spinKick to false.
	}
	if spinKick
	{
		print "  Inertial burn.".
	}
		
	if burnEta - alignMargin > 900 and Addons:Available("KAC")
	{
		// Add a KAC alarm.
        local alarmMargin is choose 600 if burnEta - alignMargin > 3600 else 60.
		local alrm is AddAlarm("Raw", burnEta - alignMargin - alarmMargin + Time:Seconds, Ship:Name + " Manoeuvre", Ship:Name + " is nearing its next manoeuvre").
        wait 0.
        set alrm:Action to "KillWarp".
	}

	local burnParams is lexicon(
		"t", duration,
		"eng", activeEngines:length,
        "align", alignMargin
	).

	if burnParams:eng
	{
		burnParams:Add("mFlow", massflow).
		burnParams:Add("thr", burnThrust).
		burnParams:Add("fFlow", maxFuelFlow).
		burnParams:Add("stage", burnStage).
	}

	if spinKick
		burnParams:Add("spin", spinRate).

	if not HasNode
	{
		burnParams:Add("eta", burnStart).
		burnParams:Add("dvx", dV:X).
		burnParams:Add("dvy", dV:Y).
		burnParams:Add("dvz", dV:Z).
	}

	local fileList is list("flight/ExecuteBurn.ks", "FCFuncs.ks", "flight/TuneSteering.ks").
	if burnParams:eng > 0
    {
		fileList:add("flight/EngineMgmt.ks").
        fileList:add("flight/ExecuteBurnEng.ks").
    }
    else
    {
        fileList:add("flight/ExecuteBurnRCS.ks").
    }

	runpath("0:/flight/SetupBurn", burnParams, fileList).
}