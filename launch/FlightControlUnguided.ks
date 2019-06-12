@lazyglobal off.

// Some basic telemetry.
local maxQ is Ship:Q.

local function checkMaxQ
{
    if maxQ > 0
    {
        if maxQ > Ship:Q
        {
            print "Max Q: " + round(maxQ * constant:AtmToKPa, 3) + " kPa.".
            set maxQ to -1.
        }
        else
        {
            set maxQ to Ship:Q.
        }
    }
}

until False
{
    if maxQ > 0
        checkMaxQ().
    
    LAS_CheckStaging().
    
    wait 0.05.
}

print "Auto launch disengaged.".

// Release control
set Ship:Control:Neutralize to true.
