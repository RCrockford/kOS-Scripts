wait until Ship:Unpacked.

local allEng is list().
list engines in allEng.

lock throttle to 1.
set ship:control:pilotmainthrottle to 1.

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
local engineStats is lexicon().
local runCount is 8.

for eng in allEng
{
	engineStats:add(eng:config, lexicon("time", 0, "impulse", 0, "ignition", 0, "fullThrust", 0, "part", eng)).
	
	local engName to eng:Name + "[" + eng:config + "] M=" + eng:Mass + " Thr=" + eng:PossibleThrustAt(0).
		
    from {local s is 1.} until s > runCount step {set s to s+1.} do
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
        local igTime is 0.
        local fullTime is 0.
		until (time:seconds - start) >= CalcFullSpoolTime(eng) * 1.2 and fullTime > 0
		{
			wait 0.
			local tickThrust is eng:thrust / eng:Maxthrust.
			local tickTime is time:Seconds.
			set impulse to impulse + (tickThrust + prevThrust) * 0.5 * (tickTime - prevTick).
            
            if tickThrust > 0.01 and igTime = 0
                set igTime to tickTime - start.
            if tickThrust > 0.99 and fullTime = 0
                set fullTime to tickTime - start.

			set prevThrust to tickThrust.
			set prevTick to tickTime.
		}
		local runTime is time:seconds - start.
		
		print " Run complete: " + round(impulse, 4) + " impulse in " + round(runTime, 3) + " seconds".
		
		set engineStats[eng:config]:Impulse to engineStats[eng:config]:Impulse + impulse.
		set engineStats[eng:config]:Time to engineStats[eng:config]:Time + runTime.
        set engineStats[eng:config]:ignition to engineStats[eng:config]:ignition + igTime.
		set engineStats[eng:config]:fullThrust to engineStats[eng:config]:fullThrust + fullTime.
        
		eng:shutdown.
		wait until eng:thrust = 0.
	}
	
	print "Test complete".
}

for k in engineStats:keys
{
	print k:PadRight(16) + " Ignition: " + round(engineStats[k]:Ignition / runCount, 3) + "/" + CalcIgnitionTime(engineStats[k]:Part)
        + " Spool: " + round((engineStats[k]:Time - engineStats[k]:Impulse) / runCount, 3) + "/" + CalcSpoolTime(engineStats[k]:Part)
        + " Full: " + round(engineStats[k]:FullThrust / runCount, 3) + "/" + CalcFullSpoolTime(engineStats[k]:Part).
}
}

local function CalcIgnitionTime
{
    parameter eng.
    local respRate is 3.0 / log10(max(1.1, sqrt(eng:Mass * eng:PossibleThrustAt(0)^2))).
    return 0.08 + (choose 0.7 if eng:PressureFed else 2.5) / respRate.
}

local function CalcSpoolTime
{
    parameter eng.
    local respRate is 3.0 / log10(max(1.1, sqrt(eng:Mass * eng:PossibleThrustAt(0)^2))).
    return 0.08 + (choose 1 if eng:PressureFed else 2.8) / respRate.
}

local function CalcFullSpoolTime
{
    parameter eng.
    local respRate is 3.0 / log10(max(1.1, sqrt(eng:Mass * eng:PossibleThrustAt(0)^2))).
    return 0.08 + (choose 1.86 if eng:PressureFed else 3.66) / respRate.
}