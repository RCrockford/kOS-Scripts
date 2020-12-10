wait until Ship:Unpacked.

local allEng is list().
list engines in allEng.

lock throttle to 1.

local allValid is true.
for eng in allEng
{
	eng:Activate.
	wait 0.1.
	if eng:maxThrust < 0.1
	{
		print "Unable to test engine " + eng:Name + "[" + eng:config + "]" + ": No fuel flow".
		set allValid to false.
	}
	eng:shutdown.
}

if allValid
{
local totalImpulse is lexicon().
local totalTime is lexicon().

for eng in allEng
{
	totalImpulse:add(eng:config, 0).
	totalTime:add(eng:config, 0).
	
	local engName to eng:Name + "[" + eng:config + "]".
		
    from {local s is 1.} until s > 10 step {set s to s+1.} do
	{
		print engName + " test run " + s.
		
		local impulse is 0.
		
		eng:shutdown.
		wait until eng:thrust = 0.

		wait 0.
		eng:Activate.
		local start is Time:Seconds.
		local prevTick is start.
		local prevThrust is 0.
		until time:seconds - start >= 8
		{
			wait 0.
			local tickThrust is eng:thrust / eng:Maxthrust.
			local tickTime is time:Seconds.
			set impulse to impulse + (tickThrust + prevThrust) * 0.5 * (tickTime - prevTick).
			set prevThrust to tickThrust.
			set prevTick to tickTime.
		}
		local runTime is time:seconds - start.
		
		print " Run complete: " + round(impulse, 4) + " impulse in " + round(runTime, 3) + " seconds".
		
		set totalImpulse[eng:config] to totalImpulse[eng:config] + impulse.
		set totalTime[eng:config] to totalTime[eng:config] + runTime.
		
		eng:shutdown.
		wait until eng:thrust = 0.
	}
	
	print "Test complete: " + round(totalImpulse[eng:config], 4) + " impulse in " + round(totalTime[eng:config], 3) + " seconds".
}

for k in totalImpulse:keys
{
	print k + " Spool time: " + round((totalTime[k] - totalImpulse[k]) / 10, 3) + " seconds".
}
}