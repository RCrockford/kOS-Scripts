@lazyglobal off.

// Wait for unpack
wait until Ship:Unpacked.

Core:DoEvent("Open Terminal").

lights on.

print "Ready to begin test:".

// Wait for command
local cmd is " ".

until cmd = "s"
{
    set cmd to Terminal:Input:GetChar().
}

local logPath is "0:/logs/teststand.csv".

local allEngines is list().
list engines in allEngines.

set Ship:Control:PilotMainThrottle to 1.

for eng in allEngines
{
	print "Testing engine: " + eng:Title.
	
	local startTime is Time:Seconds.
	log eng:Title to logPath.
	log "T,Thrust,ThrustPc" to logPath.
	
	eng:Activate().
	
	until eng:Thrust / eng:PossibleThrust > 0.99 or eng:Flameout
	{
		log round(Time:Seconds - startTime, 3) + "," + round(eng:Thrust, 2) + "," + round(100 * eng:Thrust / eng:PossibleThrust, 3) to logPath.
		wait 0.
	}
	
	eng:Shutdown.
	
	wait 1.
}

print "Test complete".