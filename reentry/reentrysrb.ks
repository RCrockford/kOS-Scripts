// ReEntry burn
@lazyglobal off.

// Wait for unpack
wait until Ship:Unpacked.

parameter targetStage is 0.
parameter retroBurn is false.

switch to scriptpath():volume.

if Ship:Status = "Sub_Orbital" or Ship:Status = "Orbiting"
{
    print "Orienting for re-entry.".
    
	runoncepath("/fcfuncs").
	LAS_Avionics("activate").
	
	for rcs in Ship:ModulesNamed("ModuleRCSFX")
	{
		if rcs:HasField("rcs")
		{
			rcs:SetField("rcs", true).
		}
	}
	
	local lock aimVec to choose Retrograde:Vector if retroBurn else Prograde:Vector.
	
	rcs on.
	lock steering to LookDirUp(aimVec, Facing:UpVector).

	wait until vdot(aimVec, Facing:Vector) > 0.999995.
	until Stage:Number = targetStage
	{
		wait until stage:ready.
		stage.
	}
    
    wait 5.
	wait until vdot(aimVec, Facing:Vector) > 0.999995.
	
    if scriptpath():ToString[0] = "0"
    {
        local fileList is list().
        local burnParams is lexicon().
        
        fileList:Add("reentry/reentrylanding.ks").

        runpath("/flight/setupburn", burnParams, fileList, "re-entry").
    }
    else
    {
        runpath("reentry/reentrylanding.ks").
    }
}
