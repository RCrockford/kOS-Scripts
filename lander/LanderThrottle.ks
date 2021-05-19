@lazyglobal off.

parameter DescentEngines.
parameter enginesActive is false.

local minThrottle is 0.
local throttleClamp is 0.

for eng in DescentEngines
{
    set minThrottle to max(eng:MinThrottle, minThrottle).
    if eng:ullage or eng:Ignitions >= 0
        set throttleClamp to 0.01.  // Prevent shutdown
}

local throttleGroups is list().
local unassignedEngines is DescentEngines:Copy().

if minThrottle >= 0.9
{
    until unassignedEngines:Length < 2
    {
        local eng1 is unassignedEngines[0].
        local eng1vec is vxcl(Facing:Vector, eng1:Position):Normalized.
        
        local engIt is unassignedEngines:Iterator.
        until not engIt:Next
        {
            if vdot(eng1vec, vxcl(Facing:Vector, engIt:Value:Position):Normalized) < -0.999
            {
                throttleGroups:Add(list(eng1, engIt:Value)).
                unassignedEngines:Remove(engIt:Index).
                unassignedEngines:Remove(0).
                break.
            }
        }
        
        if unassignedEngines:Length > 0 and eng1 = unassignedEngines[0]
            break.
    }
    
    print "Found " + throttleGroups:Length + " throttle groups and " + unassignedEngines:Length + " unassigned".
    
    if not unassignedEngines:Empty
    {
        throttleGroups:Clear().
        set unassignedEngines to DescentEngines:Copy().
    }
    
    set Ship:Control:PilotMainThrottle to 0.
}

global function LanderEnginesOn
{
    set enginesActive to true.
}

global function LanderSetThrottle
{
    parameter reqThrottle.

    if minThrottle < 0.9
    {
        local newThrottle to max(throttleClamp, min((reqThrottle - minThrottle) / (1 - minThrottle), 1)).
        set Ship:Control:PilotMainThrottle to newThrottle.
    }
    else if enginesActive
    {
        // 2 Hz PWM
        local t is Time:Seconds * 2.
        for eng in unassignedEngines
        {
            if reqThrottle >= (t - floor(t))
                eng:Activate.
            else
                eng:Shutdown.
        }
        local minReq is 0.
        for grp in throttleGroups
        {
            if reqThrottle >= (t - floor(t)) / throttleGroups:Length + minReq
            {
                for eng in grp
                    eng:Activate.
            }
            else
            {
                for eng in grp
                    eng:Shutdown.
            }
            set minReq to minReq + 1 / throttleGroups:Length.
        }
        set Ship:Control:PilotMainThrottle to 1.
    }
}

