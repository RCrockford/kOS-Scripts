// Orbital manoeuvres using Principia's flight planner

@lazyglobal off.

parameter preRotate is true.
parameter rcsBurn is false.

// Wait for unpack
wait until Ship:Unpacked.

if not Addons:Principia:HasManoeuvre
{
    print "No planned manoeuvres found.".
}
else
{
    runpathonce("FCFunctions").

    local manoeuvre is Addons:Principia:NextManoeuvre.
    
    print "Executing manoeuvre in " + round(manoeuvre:eta, 1) + " seconds, deltaV: " + round(manoeuvre:deltaV:Mag, 1) + " m/s, duration: " + round(manoeuvre:duration,2) + " s.".
    
    // Pre-rotate to burn alignment.
    if  preRotate
    {
        print "Rotating to manoeuvre heading".
    
        rcs on.
        lock steering to manoeuvre:deltaV:Normalized.
        
        wait until vdot(manoeuvre:deltaV:Normalized, Ship:Facing:ForeVector) > 0.999 and Ship:AngularVel < 0.001
        rcs off.
    }
    
    if manoeuvre:eta > 65 and Addons:Available("KAC")
    {
        // Add a KAC alarm.
        Addons:KAC:AddAlarm("Raw", manoeuvre:eta - 60 + Time:Seconds, Ship:Name + " Manoeuvre", Ship:Name + " is nearing its next manoeuvre").
    }
    
    wait until manoeuvre:eta < 30.

    print "Manoeuvre in " + round(manoeuvre:eta, 1) + " seconds, RCS on.".
    
    local ignitionTime is 0.
    local activeEngines is list().
    
    if not rcsBurn
    {
        // Prep engines
        runpath("flight/EngineManagement").

        set ignitionTime to EM_GetIgnitionTime().
        set activeEngines to EM_GetManoeuvreEngines().
    }

    rcs on.
    lock steering to manoeuvre:deltaV:Normalized.
    
    wait until manoeuvre:eta <= ignitionTime.
    
    local approxAccel is 0.
    
    // If we have engines, prep them to ignite.
    if not activeEngines:empty
    {
        local currentThrust is EM_IgniteManoeuvreEngines().
        set approxAccel to currentThrust / Ship:Mass.
    }
    else
    {
        // Otherwise assume this is an RCS burn
        set Ship:Control:Fore to 1.
        
        local deltaVreq is manoeuvre:deltaV:Mag.
        local t is Time:seconds.
        wait 0.1.

        set approxAccel to (deltaVreq - manoeuvre:deltaV:Mag) / (Time:Seconds - t).
    }
    
    print "Starting burn.".
    
    until manoeuvre:deltaV:Mag < approxAccel * 0.05.
    {
        print "dV=" +  manoeuvre:deltaV + ", t=" +  round(manoeuvre:duration,2).
    
        if manoeuvre:duration > 1
            wait 1.
    }
    
    // Cutoff engines
    set Ship:Control:MainThrottle to 0.
    for eng in activeEngines
    {
        eng:Shutdown().
    }

    set Ship:Control:Neutralize to true.
    rcs off.
}