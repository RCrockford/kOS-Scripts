@lazyglobal off.

// Wait for unpack
wait until Ship:Unpacked.

local cellType is "apollo fuel cell".

// Toggle cells off then back on to make sure they have correct config
from {local i is 0.} until i = 2 step {set i to i + 1.} do
{
    local statesValid is false.

    local startTime is Time:Seconds.
    until statesValid or Time:Seconds > startTime + 4
    {
        set statesValid to true.
        for pc in Ship:ModulesNamed("ProcessController")
        {
            local runningEvt is 0.
            local dumpEvt is 0.
            for evt in pc:AllEventNames
            {
                if evt:contains(cellType)
                    set runningEvt to evt.
                if evt:contains("dump")
                    set dumpEvt to evt.
            }
            
            if runningEvt:IsType("String") and dumpEvt:IsType("String")
            {
                local cellName is runningEvt:Split(":")[0].
                if (i = 1) <> runningEvt:contains("running")
                {
                    pc:DoEvent(runningEvt).
                    set statesValid to false.
                }   
                if (i = 1) = dumpEvt:contains("none")
                {
                    pc:DoEvent(dumpEvt).
                    set statesValid to false.
                }
            }
        }

        wait 0.1.
    }
}

for pc in Ship:ModulesNamed("ProcessController")
{
    local runningEvt is 0.
    local dumpEvt is 0.
    for evt in pc:AllEventNames
    {
        if evt:contains(cellType)
            set runningEvt to evt.
        if evt:contains("dump")
            set dumpEvt to evt.
    }
    if runningEvt:IsType("String") and dumpEvt:IsType("String")
    {
        print "Current state: " + runningEvt + ", " + dumpEvt.
    }
}
