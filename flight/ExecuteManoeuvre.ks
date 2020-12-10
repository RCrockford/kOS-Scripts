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

switch to 0.

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

local duration is 0.
local burnStage is stage:Number.
local activeEngines is list().
local fuelName is 0.
local fuelTotal is 0.
local maxFuelFlow is 0.
local massRatio is 0.
local massFlow is 0.
local burnThrust is 0.
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
        }
        
        local activeResources is lexicon().
        
        set shipMass to 0.
        for shipPart in Ship:Parts
        {
            local partStage is choose shipPart:Stage if shipPart:IsType("Decoupler") else shipPart:DecoupledIn.
            if partStage < burnStage
            {
                set shipMass to shipMass + shipPart:Mass.
                
                for r in shipPart:resources
                {
                    if r:Density > 0
                    {
                        if not activeResources:HasKey(r:Name)
                            activeResources:Add(r:Name, r:amount).
                        else
                            set activeResources[r:name] to activeResources[r:name] + r:amount.
                    }
                }
            }
        }

        local maxFlow is 0.
        for k in activeEngines[0]:ConsumedResources:keys
        {
            local res is activeEngines[0]:ConsumedResources[k].
            if res:Density > 0 and activeResources:HasKey(res:Name) and res:Name = k
            {
                if res:MaxFuelFlow > maxFlow
                {
                    set fuelName to res:Name.
                    set fuelTotal to activeResources[res:Name].
                    set maxFlow to res:MaxFuelFlow.
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

if massFlow > 0
{
	// Calc burn duration
	set massRatio to constant:e ^ (dV:Mag * massflow / burnThrust).
	local finalMass is Ship:Mass / massRatio.
	set duration to (Ship:Mass - finalMass) / massflow.
    
    // Calc alignment time
    runpath("0:/flight/AlignTime").
    local alignMargin is GetAlignTime().

	print "Executing manoeuvre in " + FormatTime(burnEta).
	print "  DeltaV: " + round(dV:Mag, 1) + " m/s.".
	print "  Duration: " + round(duration, 1) + " s.".
	print "  Align at: T-" + round(alignMargin, 1) + " s.".
	if not rcsBurn
		print "  Fuel Monitor: " + fuelName + " " + round(fuelTotal, 2) + " => " + round(fuelTotal - maxFuelFlow * duration, 2).
	if rcsBurn
	{
		print "  RCS burn.".
		set spinKick to false.
	}
	if spinKick
	{
		print "  Inertial burn.".
	}
		
	if burnEta > 300 and Addons:Available("KAC")
	{
		// Add a KAC alarm.
		AddAlarm("Raw", burnEta - alignMargin - 30 + Time:Seconds, Ship:Name + " Manoeuvre", Ship:Name + " is nearing its next manoeuvre").
	}

	local burnParams is lexicon(
		"t", duration,
		"eng", not activeEngines:empty,
		"inertial", spinKick,
        "align", alignMargin
	).

	if burnParams:eng
	{
		burnParams:Add("fuelN", fuelName).
		burnParams:Add("mRatio", massRatio).
		burnParams:Add("mFlow", massflow).
		burnParams:Add("fFlow", maxFuelFlow).
		burnParams:Add("stage", burnStage).
	}

	if spinKick
		burnParams:Add("spin", spinRate).

	if not HasNode
	{
		burnParams:Add("eta", burnStart).
		burnParams:Add("dv", dV).
	}

	local fileList is list("flight/ExecuteManoeuvreBurn.ks", "FCFuncs.ks", "flight/TuneSteering.ks").
	if burnParams:eng
		fileList:add("flight/EngineMgmt.ks").

	runpath("0:/flight/SetupBurn", burnParams, fileList).
}