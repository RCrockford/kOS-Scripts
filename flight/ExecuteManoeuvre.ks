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

if not HasNode
{
    lock tVec to Ship:Prograde:Vector.
    lock bVec to vcrs(tVec, ship:up:vector):Normalized.
    lock nVec to vcrs(tVec, bVec):Normalized.
    lock dV to tangent * tVec + normal * nVec + binormal * bVec.
    set burnStart to time:Seconds + burnStart.
    lock burnEta to burnStart - time:Seconds.
}
else
{
    lock dV to NextNode:DeltaV.
    lock burnEta to NextNode:eta.
}
runoncepath("0:/FCFuncs").

local duration is 0.
local burnStage is stage:Number.
local activeEngines is list().
local fuelName is 0.
local fuelAmount is 0.

if rcsBurn
{
	runoncepath("0:/flight/RCSPerf.ks").
	local RCSPerf is GetRCSForePerf().

	// Calc burn duration
	local massRatio is constant:e ^ (dV:Mag * RCSPerf:massflow / RCSPerf:thrust).
	local finalMass is Ship:Mass / massRatio.
	set duration to (Ship:Mass - finalMass) / RCSPerf:massflow.
}
else
{
    if spinKick
        set burnStage to burnStage - 1.

    runpath("0:/flight/EngineMgmt", burnStage).
    set activeEngines to EM_GetEngines().
    if activeEngines:Length = 0
    {
        print "No active engines!".
    }
    else
    {
        local massFlow is 0.
        local burnThrust is 0.
        for eng in activeEngines
        {
            set massFlow to massFlow + eng:MaxMassFlow.
            set burnThrust to burnThrust + eng:PossibleThrust.
        }
        local massRatio is constant:e ^ (dV:Mag * massFlow / burnThrust).
		
		local activeResources is lexicon().
        
        local shipMass is 0.
        for shipPart in Ship:Parts
        {
            if shipPart:IsType("Decoupler")
            {
                if shipPart:Stage < burnStage
                {
                    set shipMass to shipMass + shipPart:Mass.
                }
            }
            else if shipPart:DecoupledIn < burnStage
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
        
        local finalMass is shipMass / massRatio.
        set duration to (shipMass - finalMass) / massFlow.

		local startFuelMass is 0.
        
        for eng in activeEngines
        {
            for k in eng:ConsumedResources:keys
            {
                local res is eng:ConsumedResources[k].
                if res:Density > 0 and activeResources:HasKey[res:name]
                {
                    set startFuelMass to startFuelMass + activeResources[res] * res:Density.
                    if fuelName = 0
                    {
                        set fuelName to res:name.
                        set fuelAmount to activeResources[res].
                    }
                }
            }
        }
		
		if startFuelMass > 0 
		{
			local fuelProp is (shipMass - finalMass) / startFuelMass.
			set fuelProp to min(max(0, fuelProp), 1).			
			set fuelAmount to fuelAmount * fuelProp.
		}
    }
}

print "Executing manoeuvre in " + round(burnEta, 1) + " seconds.".
print "  DeltaV: " + round(dV:Mag, 1) + " m/s.".
print "  Duration: " + round(duration, 1) + " s.".
if not rcsBurn
	print "  Fuel Monitor: " + fuelName + " => " + round(fuelAmount, 2).
if rcsBurn
{
    print "  RCS burn.".
    set spinKick to false.
}
if spinKick
{
    print "  Inertial burn.".
}
    
if burnEta > 120 and Addons:Available("KAC")
{
    // Add a KAC alarm.
    AddAlarm("Raw", burnEta - 90 + Time:Seconds, Ship:Name + " Manoeuvre", Ship:Name + " is nearing its next manoeuvre").
}

local burnParams is lexicon(
    "eta", burnEta",
    "dv", dV,
    "fuelN", fuelName,
    "fuelA, fuelAmount,
    "t", duration,
    "eng", not activeEngines:empty,
    "stage", burnStage,
    "inertial", spinKick,
    "spin", spinRate
).

local fileList is list("flight/ExecuteManoeuvreBurn.ks").
if burnParams:engines
{
    fileList:add("FCFuncs.ks").
    fileList:add("flight/EngineMgmt.ks").
}

runpath("0:/flight/SetupBurn", burnParams, fileList).
