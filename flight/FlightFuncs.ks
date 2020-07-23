@lazyglobal off.

global function CalcBurnDuration
{
	parameter deltaV.
	parameter useEngines.

	local massFlow is 0.
	local burnThrust is 0.

	if useEngines
	{
		runpath("0:/flight/EngineMgmt", Stage:Number).
		local activeEngines to EM_GetEngines().

		for eng in activeEngines
		{
			set massFlow to massFlow + eng:MaxMassFlow.
			set burnThrust to burnThrust + eng:PossibleThrust.
		}
		print "Engine thrust=" + round(burnThrust, 1) + " kN massFlow=" + round(massFlow * 1000, 1) + " kg/s.".
	}
	else
	{
		// Get RCS stats
		runoncepath("0:/flight/RCSPerf.ks").
		local RCSPerf is GetRCSForePerf().
		set massFlow to RCSPerf:massflow.
		set burnThrust to RCSPerf:thrust.
		print "RCS thrust=" + round(burnThrust * 1000, 1) + " N massFlow=" + round(massFlow * 1000, 1) + " kg/s.".
	}

	set burnThrust to max(burnThrust, 1e-6).
	set massFlow to max(massFlow, 1e-6).
	
	local ret is lexicon().

	// Calc burn duration
	local massRatio is constant:e ^ (deltaV * massflow / burnThrust).
	local finalMass is Ship:Mass / massRatio.
	ret:add("duration", (Ship:Mass - finalMass) / massflow).

	set massRatio to constant:e ^ (0.5 * deltaV * massflow / burnThrust).
	set finalMass to Ship:Mass / massRatio.
	ret:add("halfBurn", (Ship:Mass - finalMass) / massflow).
	
	return ret.
}

global function FormatTime
{
    parameter t.

    local fmt is "".
    if t > (30 * 3600)
        set fmt to round(t / (24 * 3600), 2):ToString() + " days".
    else if t > (90 * 60)
        set fmt to round(t / 3600, 2):ToString() + " hours".
    else if t > 90
        set fmt to round(t / 60, 2):ToString() + " minutes".
    else
        set fmt to round(t, 1):ToString() + " seconds".
        
    return fmt.
}

global function CalcMeanAnom
{
	parameter trueAnom.

	local eccAnom is arctan2(sqrt(1-Ship:Orbit:Eccentricity^2) * sin(trueAnom), Ship:Orbit:Eccentricity + cos(trueAnom)).
	return eccAnom - Ship:Orbit:Eccentricity * sin(eccAnom) * Constant:RadToDeg.
}