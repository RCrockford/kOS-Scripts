// Ship to ship rendezvous

@lazyglobal off.

parameter tShip is target.
parameter minDist is 50.

// Wait for unpack
wait until Ship:Unpacked.

local debugGui is GUI(300, 80).
set debugGui:X to -150.
set debugGui:Y to debugGui:Y - 480.
local mainBox is debugGui:AddVBox().
local debugStat1 is mainBox:AddLabel("").
local debugStat2 is mainBox:AddLabel("").
local debugStat3 is mainBox:AddLabel("").
debugGui:Show().

runoncepath("0:/flight/RCSPerf.ks").
local RCSPerf is GetRCSForePerf().
set maxAccel to RCSPerf:thrust / Ship:Mass.

rcs off.

local relV is (tShip:Velocity:Orbit - Ship:Velocity:Orbit).
until tShip:Distance <= minDist and relV:Mag < 0.01
{
	set debugStat1:Text to "d=" + round(tShip:Distance, 1) + " v=" + round(relV:Mag, 2).
	
	local headingCorrect is vdot(tShip:Direction:Vector, relV:Normalized).	
	set debugStat2:Text to "hc=" + round(HeadingCorrect, 4).
	
	local brakeTime is relV:Mag / maxAccel.

	// Solution to quadratic equation of motion.
	local interceptDist is tShip:Distance - minDist.
	local interceptVel is relV:Mag * headingCorrect.
	
	local tRoot is interceptVel^2 + 2 * maxAccel * interceptDist.
	if tRoot > 0
		set tRoot to sqrt(tRoot)
	else
		set tRoot to 0.
	
	local interceptTime is (-interceptVel + tRoot) / (-2 * interceptDist).
	local interceptTime2 is (-interceptVel - tRoot) / (-2 * interceptDist).
	if interceptTime2 >= 0 and interceptTime2 < interceptTime
		set interceptTime to interceptTime2.
	
	set debugStat3:Text to "bt=" + round(brakeTime, 1) + " it=" + round(interceptTime, 1).
	
	// Allow a little margin
	if brakeTime < interceptTime * 1.1
	{
		if not rcs
		{
			rcs on.
			lock steering to lookdirup(relV:Normalized, Facing:UpVector).
		}
		set fore to 1.
	}
	else
	{
		set fore to 0.
		if headingCorrect < 0.95
		{
			// Correct heading
			set ship:control:starboard to vdot(Facing:starvector, relV:Normalized).
			set ship:control:top to vdot(Facing:upvector, relV:Normalized).
		}
		else
		{
			set ship:control:starboard to 0.
			set ship:control:top to 0.
		}
	}

	wait 0.
	
	set relV to (tShip:Velocity:Orbit - Ship:Velocity:Orbit).
}

unlock steering.
set Ship:Control:Neutralize to true.
rcs off.
