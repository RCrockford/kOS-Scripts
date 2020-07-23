// ReEntry burn
@lazyglobal off.

// Wait for unpack
wait until Ship:Unpacked.

if Ship:Status = "Sub_Orbital" or Ship:Status = "Orbiting"
{
    print "Orienting for re-entry.".
    
	runoncepath("0:/FCFuncs").
	LAS_Avionics("activate").
	
	for rcs in Ship:ModulesNamed("ModuleRCSFX")
	{
		if rcs:HasField("rcs")
		{
			rcs:SetField("rcs", true).
		}
	}
	
	rcs on.
	lock steering to LookDirUp(Prograde:Vector, Facing:UpVector).

	wait until vdot(Prograde:Vector, Facing:Vector) > 0.999998.
	until Stage:Number = 0
	{
		wait until stage:ready.
		stage.
	}
	
    local fileList is list().
    local burnParams is lexicon().
    
	fileList:Add("flight/ReEntryLanding.ks").

    runpath("0:/flight/SetupBurn", burnParams, fileList).
}
