@lazyglobal off.

parameter DescentEngines.
parameter enginesActive is false.

if exists("/mgmt/diffthrottle.ks")
    runoncepath("/mgmt/diffthrottle").

local minThrottle is 0.
local throttleClamp is 0.

local minThrust is 0.
local maxThrust is 0.

for eng in DescentEngines
{
    set minThrust to minThrust + eng:MinThrottle * eng:PossibleThrust.
    set maxThrust to maxThrust + eng:PossibleThrust.
    if eng:ullage or eng:Ignitions >= 0
        set throttleClamp to 0.01.  // Prevent shutdown
}
for eng in Ship:RCS
{
    if eng:ForeByThrottle
        set maxThrust to maxThrust + eng:AvailableThrust.
}

set minThrottle to minThrust / maxThrust.

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
else
{
    print "Min throttle: " + round(minThrottle * 100, 1) + "%".
}

global function LanderEnginesOn
{
    set enginesActive to true.
    if minThrottle < 0.9
        for eng in DescentEngines
            eng:Activate.
}

global function LanderEnginesOff
{
    set enginesActive to false.
    for eng in DescentEngines
        eng:Shutdown.
}

global function LanderMaxThrust
{
    return maxThrust.
}

local diffEngines is list().

global function LanderSetupDiffThrottle
{
    set diffEngines to SetupDiffThrottle(DescentEngines).
}

global function LanderCanThrottle
{
    return minThrottle < 0.9.
}

global function LanderMinThrottle
{
    return minThrottle.
}

global function LanderSetThrottle
{
    parameter reqThrottle.

    if enginesActive
    {
        if minThrottle < 0.9
        {
            local newThrottle to max(throttleClamp, min((reqThrottle - minThrottle) / (1 - minThrottle), 1)).
            if diffEngines:Length > 0
            {
                local reqPitch is SteeringManager:Actuation:X * 0.5.
                local reqYaw is SteeringManager:Actuation:Z * 0.5.
                
                for eng in diffEngines
                {
                    local limit is newThrottle + eng:pitch * reqPitch + eng:yaw * reqYaw.
                    set eng:eng:ThrustLimit to sqrt(max(limit, 0)) * 100.
                }
                set Ship:Control:PilotMainThrottle to 1.
            }
            else
            {
               set Ship:Control:PilotMainThrottle to newThrottle.
            }
        }
        else
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
    else
    {
        set Ship:Control:PilotMainThrottle to throttleClamp.
    }
}

