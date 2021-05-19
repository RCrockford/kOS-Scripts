// Lander direct descent system, for safe(!) landings
// Two phase landing system, braking burn attempts to slow the craft to targeted vertical speed in one full thrust burn.
// Descent phase attempts a soft landing on the ground.

@lazyglobal off.

// Wait for unpack
wait until Ship:Unpacked.

switch to scriptpath():volume.

if Ship:Status = "Flying" or Ship:Status = "Sub_Orbital" or Ship:Status = "Escaping"
{
    print "Venusian descent system online.".

	local debugGui is GUI(400, 80).
    set debugGui:X to 160.
    set debugGui:Y to debugGui:Y + 240.
    local mainBox is debugGui:AddVBox().

    local debugStat is mainBox:AddLabel("Awaiting atmospheric interface").
	debugGui:Show().
    
    unlock steering.
    set Ship:Control:Neutralize to true.
    rcs off.

    wait until Ship:Altitude < Ship:Body:Atm:Height.
	set Ship:Type to "Lander".

	set navmode to "surface".
    
    for panel in Ship:ModulesNamed("ModuleROSolar")
    {
        if panel:HasAction("retract solar panel")
        {
            panel:DoAction("retract solar panel", true).
        }
    }
    for panel in Ship:ModulesNamed("ModuleDeployableSolarPanel")
    {
        if panel:HasAction("retract solar panel")
        {
            panel:DoAction("retract solar panel", true).
        }
    }

    if Ship:ModulesNamed("ProceduralFairingDecoupler"):Empty
    {
        set debugStat:Text to "Aligning retrograde".
        
        for rc in Ship:ModulesNamed("RealChuteModule")
        {
            if rc:HasEvent("disarm chute")
            {
                rc:DoEvent("disarm chute").
                set chutesArmed to true.
            }
        }
        
        for a in Ship:ModulesNamed("ModuleProceduralAvionics")
        {
            if a:HasEvent("activate avionics")
                a:DoEvent("activate avionics").
        }

        rcs on.
        lock steering to LookDirUp(SrfRetrograde:Vector, Facing:UpVector).

        wait until vdot(SrfRetrograde:Vector, Facing:Vector) > 0.9995 or Ship:Q > (0.08 * Constant:kPaToAtm).
        wait until Ship:Q > (0.08 * Constant:kPaToAtm).

        unlock steering.
        set Ship:Control:Neutralize to true.
        rcs off.

        stage.
    }
    else
    {
        set debugStat:Text to "Waiting for aeroshell deployment".

        wait until Ship:Airspeed <= 1000.
        
        for fairing in Ship:ModulesNamed("ProceduralFairingDecoupler")
        {
            if fairing:HasEvent("jettison fairing")
                fairing:DoEvent("jettison fairing").
        }
    }

    set debugStat:Text to "Waiting for chute altitude".

    wait until Ship:Altitude - Ship:GeoPosition:TerrainHeight < 1000.
    
    for panel in Ship:ModulesNamed("ModuleROSolar")
    {
        if panel:HasAction("extend solar panel")
        {
            panel:DoAction("extend solar panel", true).
        }
    }
    for panel in Ship:ModulesNamed("ModuleDeployableSolarPanel")
    {
        if panel:HasAction("extend solar panel")
        {
            panel:DoAction("extend solar panel", true).
        }
    }
    
    if stage:number > 0
        stage.
    
    local chutesArmed is false.
    for rc in Ship:ModulesNamed("RealChuteModule")
    {
        if rc:HasEvent("deploy chute")
        {
            rc:DoEvent("deploy chute").
            set chutesArmed to true.
        }
    }

    if not chutesArmed
        chutes on.
        
    set debugStat:Text to "Waiting for heatshield altitude".

    wait until Alt:Radar < 200.

    // Drop all payload bases and heatshields
    for hs in Ship:ModulesNamed("ModuleDecouple")
    {
        if hs:HasEvent("decouple")
            hs:DoEvent("decouple").
        else if hs:HasEvent("decouple top node")
            hs:DoEvent("decouple top node").
        else if hs:HasEvent("decoupler staging")
            hs:DoEvent("decoupler staging").
    }
    for hs in Ship:ModulesNamed("ModuleAnchoredDecoupler")
    {
        if hs:HasEvent("decouple")
            hs:DoEvent("decouple").
        else if hs:HasEvent("decouple top node")
            hs:DoEvent("decouple top node").
        else if hs:HasEvent("decoupler staging")
            hs:DoEvent("decoupler staging").
    }
    wait 0.
    for hs in Ship:ModulesNamed("ModuleDecouple")
    {
        if hs:HasEvent("jettison heat shield")
        {
            hs:DoEvent("jettison heat shield").
        }
    }
    
    if stage:number > 0
        stage.

    legs on.
    gear on.
}
