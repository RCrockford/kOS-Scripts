// Raise or lower one of the apsides using RCS or engines

@lazyglobal off.

parameter burnRadius.		// Set to apsis + body:Radius where the burn will occur
parameter targetApsis.		// Set to the new radius of the other apside.
parameter burnETA.			// Function to give ETA to burn apsis

parameter useEngines is false.
parameter timeOffset is 0.	// For offsetting for comms

switch to 0.

// Calc required dV
local currentV is sqrt(Ship:Body:Mu * Ship:Orbit:SemiMajorAxis * (1 - Ship:Orbit:Eccentricity^2)) / burnRadius.

local targetA is (burnRadius + targetApsis) / 2.
local targetEcc is (max(targetApsis, burnRadius) - min(targetApsis, burnRadius)) / (targetApsis + burnRadius).
local targetV is sqrt(Ship:Body:Mu * targetA * (1 - targetEcc^2)) / burnRadius.

local deltaV is abs(targetV - currentV).

runpath("0:/flight/FlightFuncs").
local burnDur is CalcBurnDuration(deltaV, useEngines).
set burnDur:HalfBurn to burnDur:HalfBurn + timeOffset.

local burnAtAp is abs(burnETA() - eta:Apoapsis) < Ship:Orbit:Period * 0.25.

print "Executing manoeuvre at " + (choose "Ap" if burnAtAp else "Pe") + (choose "-" if burnDur:halfBurn > 0 else "+") + round(abs(burnDur:halfBurn), 1) + " seconds.".
print "  DeltaV: " + round(deltaV, 1) + " m/s.".
print "  Duration: " + round(burnDur:duration, 1) + " s.".

if burnDur:duration < Ship:Orbit:Period * 0.25
{
	if burnETA() - burnDur:halfBurn > 240 and Addons:Available("KAC")
	{
		// Add a KAC alarm.
		AddAlarm("Raw", (burnETA() - burnDur:halfBurn) - 180 + Time:Seconds, Ship:Name + " Manoeuvre", Ship:Name + " is nearing its next manoeuvre").
	}

	local burnParams is lexicon(
		"sma", targetA,
		"ap", burnAtAp,
		"t", burnDur:halfBurn
	).
	
	runpath("0:/flight/TuneSteering").

	if useEngines
		runpath("0:/flight/SetupBurn", burnParams, list("flight/ChangeApsisBurn.ks", "FCFuncs.ks", "flight/EngineMgmt.ks")).
	else
		runpath("0:/flight/SetupBurn", burnParams, list("flight/ChangeApsisRCS.ks")).
}
else
{
	print "Burn too long relative to orbit, aborting.".
}