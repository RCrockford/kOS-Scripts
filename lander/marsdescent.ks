// Lander direct descent system, for safe(!) landings
// Two phase landing system, braking burn attempts to slow the craft to targeted vertical speed in one full thrust burn.
// Descent phase attempts a soft landing on the ground.

@clobberbuiltins on.
@lazyglobal off.

// Wait for unpack
wait until Ship:Unpacked.

switch to scriptpath():volume.

// Setup functions
runpath("/flight/enginemgmt", Stage:Number).
runpath("/flight/tunesteering").

if Ship:Status = "Flying" or Ship:Status = "Sub_Orbital" or Ship:Status = "Escaping"
{
    print "Martian descent system online.".

    runoncepath("/mgmt/readoutgui").
    local readoutGui is RGUI_Create().
    readoutGui:SetColumnCount(80, 3).

    local Readouts is lexicon().

    Readouts:Add("height", readoutGui:AddReadout("Height")).
    Readouts:Add("acgx", readoutGui:AddReadout("Acgx")).
    Readouts:Add("fr", readoutGui:AddReadout("fr")).

    Readouts:Add("throt", readoutGui:AddReadout("Throttle")).
    Readouts:Add("thrust", readoutGui:AddReadout("Thrust")).
    Readouts:Add("status", readoutGui:AddReadout("Status")).

	readoutGui:Show().
    
    unlock steering.
    set Ship:Control:Neutralize to true.
    rcs off.

    wait until Ship:Altitude < Ship:Body:Atm:Height.
	set Ship:Type to "Lander".

	set navmode to "surface".
    
    RGUI_SetText(Readouts:status, "Wait Q").
    
    wait until Ship:Q > 1e-6.
   
    // Switch on all tanks
    for p in Ship:Parts
    {
        for r in p:resources
        {
            set r:enabled to true.
        }
    }
    
    for a in Ship:ModulesNamed("ModuleProceduralAvionics")
    {
        if a:HasEvent("activate avionics")
            a:DoEvent("activate avionics").
    }

    if Ship:ModulesNamed("ProceduralFairingDecoupler"):Empty
    {
        RGUI_SetText(Readouts:status, "Align").
        
        for rc in Ship:ModulesNamed("RealChuteModule")
        {
            if rc:HasEvent("disarm chute")
            {
                rc:DoEvent("disarm chute").
            }
        }

        rcs on.
        lock steering to LookDirUp(SrfRetrograde:Vector, Facing:UpVector).

        wait until vdot(SrfRetrograde:Vector, Facing:Vector) > 0.9995 or Ship:Altitude < 50000.
        wait 1.

        unlock steering.
        set Ship:Control:Neutralize to true.
        rcs off.
    }
    else
    {
        RGUI_SetText(Readouts:status, "Wait Shell").

        until Ship:Airspeed <= 1000
        {
            RGUI_SetText(Readouts:fr, round(Ship:Airspeed, 0) + " > 1000").
            wait 0.05.
        }
        
        for fairing in Ship:ModulesNamed("ProceduralFairingDecoupler")
        {
            if fairing:HasEvent("jettison fairing")
                fairing:DoEvent("jettison fairing").
        }
    }

    RGUI_SetText(Readouts:status, "Wait Chute").
    RGUI_SetText(Readouts:fr, "").

    until Ship:Altitude - Ship:GeoPosition:TerrainHeight < 15000.
    {
        RGUI_SetText(Readouts:height, round(Ship:Altitude - Ship:GeoPosition:TerrainHeight, 0) + " m").
        wait 0.05.
    }
    
    local chutesArmed is false.
    for rc in Ship:ModulesNamed("RealChuteModule")
    {
        if rc:HasEvent("arm parachute")
        {
            rc:DoEvent("arm parachute").
            set chutesArmed to true.
        }
        else if rc:HasEvent("deploy chute")
        {
            rc:DoEvent("deploy chute").
            set chutesArmed to true.
        }
    }

    if not chutesArmed
        chutes on.

    RGUI_SetText(Readouts:status, "Stabilising").

    local curSpeed is Ship:Velocity:Surface:Mag.
    local curTime is Time:Seconds.
    local curAccel is -10.

    until curAccel > -4
    {
        wait 0.05.
        set curAccel to (Ship:Velocity:Surface:Mag - curSpeed) / (Time:Seconds - curTime).
        set curSpeed to Ship:Velocity:Surface:Mag.
        set curTime to Time:Seconds.

        RGUI_SetText(Readouts:acgx, round(curAccel, 3)).
        RGUI_SetText(Readouts:height, round(Ship:Altitude - Ship:GeoPosition:TerrainHeight, 0) + " m").
    }
    
    until stage:number = 0
    {
        wait until stage:ready.
        stage.
    }
    
    wait 0.1.
    
    RGUI_SetText(Readouts:status, "Landing").
    
    rcs on.
    local DescentEngines is list().
	list engines in DescentEngines.

    runpath("/lander/finaldescent", DescentEngines, Readouts, 0).
}
