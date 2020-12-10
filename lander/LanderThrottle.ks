@lazyglobal off.

parameter DescentEngines.

local minThrottle is 0.
local throttleClamp is 0.

for eng in DescentEngines
{
    set minThrottle to max(eng:MinThrottle, minThrottle).
    if eng:ullage or eng:Ignitions >= 0
        set throttleClamp to 0.01.  // Prevent shutdown
}

global function LanderSetThrottle
{
    parameter reqThrottle.

    if minThrottle < 0.9
    {
        local newThrottle to max(throttleClamp, min((reqThrottle - minThrottle) / (1 - minThrottle), 1)).
        set Ship:Control:PilotMainThrottle to newThrottle.
    }
    else
    {
        set threshold to threshold * (0.95 - Ship:Control:PilotMainThrottle * 0.05).
        if reqThrottle > threshold
            set Ship:Control:PilotMainThrottle to 1.
        else
            set Ship:Control:PilotMainThrottle to 0.
    }
}

