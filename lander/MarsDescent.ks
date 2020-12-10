// Lander direct descent system, for safe(!) landings
// Two phase landing system, braking burn attempts to slow the craft to targeted vertical speed in one full thrust burn.
// Descent phase attempts a soft landing on the ground.

@lazyglobal off.

// Wait for unpack
wait until Ship:Unpacked.

switch to scriptpath():volume.

// Setup functions
runpath("0:/flight/EngineMgmt", Stage:Number).
runpath("0:/flight/TuneSteering").

if Ship:Status = "Flying" or Ship:Status = "Sub_Orbital" or Ship:Status = "Escaping"
{
    print "Martian descent system online.".

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
    
    set debugStat:Text to "Waiting for dynamic pressure".

    wait until Ship:Q > 1e-6.
   
    set debugStat:Text to "Aligning retrograde".
    
    for rc in Ship:ModulesNamed("RealChuteModule")
    {
        if rc:HasEvent("disarm chute")
        {
            rc:DoEvent("disarm chute").
            set chutesArmed to true.
        }
    }
    
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

    rcs on.
    lock steering to LookDirUp(SrfRetrograde:Vector, Facing:UpVector).

    wait until vdot(SrfRetrograde:Vector, Facing:Vector) > 0.9995 or Ship:Altitude < 50000.
    wait 1.

    unlock steering.
    set Ship:Control:Neutralize to true.
    rcs off.

    set debugStat:Text to "Waiting for chute altitude".

    wait until Ship:Altitude - Ship:GeoPosition:TerrainHeight < 15000.
    
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

    wait until Alt:Radar < 2500.
    
    for hs in Ship:ModulesNamed("ModuleDecouple")
    {
        if hs:HasEvent("jettison heat shield")
        {
            hs:DoEvent("jettison heat shield").
        }
    }
    
    wait 0.1.
    
    rcs on.
    local DescentEngines is list().
	list engines in DescentEngines.

	when Alt:Radar < 100 then { legs on. gear on. brakes on. }

    runpath("/lander/FinalDescent", DescentEngines, debugStat, targetPos).
}
