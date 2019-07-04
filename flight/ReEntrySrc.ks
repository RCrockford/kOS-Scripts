// ReEntry burn

@lazyglobal off.

parameter targetPe is 80.       // In km
// Lat or long depending on orbital inclination. If inclination is > 60 degrees then it's lat.
parameter burnLatLong is 200.   // Default to immediate.

// Wait for unpack
wait until Ship:Unpacked.

if Ship:Status = "Sub_Orbital" or Ship:Status = "Orbiting"
{
    runoncepath("FCFuncs").
    
    if abs(burnLatLong) > 180
    {
        print "Re-entry immediately, target Pe: " + round(targetPe, 1) + " km.".
    }
    else if abs(Ship:Obt:Inclination) > 60 and abs(Ship:Obt:Inclination) < 120
    {
        print "Re-entry at Lat: " + burnLatLong + ", target Pe: " + round(targetPe, 1) + " km.".

        local targetLatitude is burnLatLong - 360 * (30 / Ship:Obt:Period).    // Lead by 30 seconds for orientation.
        if targetLatitude < -90
            set targetLatitude to -180 - targetLatitude.
        if targetLatitude > 90
            set targetLatitude to 180 - targetLatitude.

        wait until Ship:Latitude > targetLatitude - 0.5 and Ship:Latitude < targetLatitude + 0.5.
    }
    else
    {
        print "Re-entry at Long: " + burnLatLong + ", target Pe: " + round(targetPe, 1) + " km.".

        local targetLongitude is burnLatLong - 360 * (30 / Ship:Obt:Period).    // Lead by 30 seconds for orientation.
        if targetLongitude < -180
            set targetLongitude to targetLongitude + 360.
        if targetLongitude > 180
            set targetLongitude to targetLongitude - 360.
            
        print "Orient at Long: " + targetLongitude.

        wait until Ship:Longitude > targetLongitude - 0.5 and Ship:Longitude < targetLongitude + 0.5.
    }
    
    set targetPe to targetPe * 1000.
    
    rcs on.
    lock steering to Ship:Retrograde.
    
    if abs(burnLatLong) > 180
    {
        // Just wait for alignment.
        wait until abs(SteeringManager:AngleError) < 0.2 and (Ship:AngularVel:SqrMagnitude - (vdot(Ship:Facing:Vector, Ship:AngularVel)^2) < 1e-4).
    }
    else if abs(Ship:Obt:Inclination) > 60 and abs(Ship:Obt:Inclination) < 120
    {
        wait until Ship:Latitude > burnLatLong - 0.1 and Ship:Latitude < burnLatLong + 0.1.
    }
    else
    {
        wait until Ship:Longitude > burnLatLong - 0.1 and Ship:Longitude < burnLatLong + 0.1.
    }
    
    if Ship:Obt:Periapsis > targetPe
    {
        print "Commencing re-entry burn.".
        
        runpath("flight/EngineManagement", Stage:Number).
        
        // If no thrust from engines then we have none, so do an RCS burn
        local rcsBurn is false.
        if not EM_IgniteManoeuvreEngines()
        {
            set Ship:Control:Fore to 1.
            set rcsBurn to true.
        }
        
        local shipMass is Ship:mass.
        until Ship:Obt:Periapsis <= targetPe
        {
            wait 0.1.
            // Check for out of fuel (no mass change means no fuel burn).
            if shipMass = Ship:mass
            {
                print "Out of fuel, aborting burn.".
                break.
            }
            set shipMass to Ship:Mass.
        }
        
        // Release controls, engines off.
        set Ship:Control:Fore to 0.
        set Ship:Control:MainThrottle to 0.
    }

    set Ship:Control:Neutralize to true.
    rcs off.

    // Arm parachutes
    local chutesArmed is false.
    for p in Ship:Parts
    {
        if p:HasModule("RealChuteModule")
        {
            local modRealChute is p:GetModule("RealChuteModule").
            if modRealChute:HasEvent("arm parachute")
            {
                modRealChute:DoEvent("arm parachute").
                set chutesArmed to true.
            }
        }
    }
    
    if not chutesArmed
        chutes on.
        
    print "Parachutes armed.".
}
