wait until Ship:Unpacked.

local allEng is list().
list engines in allEng.

local n is list().
for e in allEng
{
    if e:AllowShutdown
        n:Add(e).
}

set Ship:Control:MainThrottle to 1.

// Ignition
for e in n
    e:Activate.

local start is Time:Seconds.
local nextPrint is 0.05.

until n[0]:Thrust >= n[0]:PossibleThrust
{
    if n[0]:Thrust >= n[0]:PossibleThrust * nextPrint
    {
        print round(Time:Seconds - start, 3) + ": " + n[0]:config + " thr=" + round(100 * n[0]:Thrust / n[0]:PossibleThrust, 1) + "%".
        set nextPrint to round(n[0]:Thrust / (n[0]:PossibleThrust * 0.5), 1) * 0.5 + 0.05.
    }
	wait 0.
}

// Cutoff engines
for e in n
    e:Shutdown.

