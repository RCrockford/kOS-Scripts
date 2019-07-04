// Ground launch controller.

@lazyglobal off.

parameter engineStart is -1.
parameter targetOrbit is 0.

local liftoffTime is -1.
// Initialise launch parameters
local launchDelay is max(10, engineStart + 2).

// Set launch site for range safety
local launchSite to LAS_ShipPos().

local mainEngines is LAS_GetStageEngines().
local mainEnginesLF is list().  // Liquid fuelled for pre-start.

local startStagger is 0.
local autoStartTime is 0.

print "Main Engines:".
for eng in mainEngines
{
    local engType is "Liquid Fuel, pumped.".
    
    if LAS_EngineIsSolidFuel(eng)
    {
        set engType to "Solid Fuel.".
    }
    else if LAS_EngineIsPressureFed(eng)
    {
        set engType to "Liquid Fuel, pressure fed.".
        set autoStartTime to max(autoStartTime, 2).
        set startStagger to max(startStagger, 0.05).
    }
    else
    {
        set autoStartTime to max(autoStartTime, 5).
        set startStagger to max(startStagger, 0.25).
    }
    
    print "  " + eng:Title + ", " + engType.
    if not LAS_EngineIsSolidFuel(eng)
        mainEnginesLF:add(eng).
}

if engineStart < 0
{
    set engineStart to autoStartTime + startStagger * min(mainEnginesLF:length - 1, 0).
}

set startStagger to min(startStagger, engineStart * 0.2).

print "Ground Launch Controller ready.".
print "  Engine start at T-" + round(engineStart, 2) + ".".

local launchMass is Ship:Mass.
local padFuelling is engineStart <= 0.5 or mainEnginesLF:empty().   // If not pre-spooling engines, then don't worry about pad fuel pumps

// Ship description dump
{
    local logPath is "0:/logs/shipstaging.txt".

    log Ship:Name to logPath.
    log "    mass=" + round(Ship:Mass * 1000, 1) + ", drymass=" + round(Ship:DryMass * 1000, 1) + ", wetmass=" + round(Ship:WetMass * 1000, 1) to logPath.

    local stageWetMass is list().
    local stageDryMass is list().
    
    from {local s is 0.} until s = Stage:Number step {set s to s+1.} do
    {
        stageWetMass:Add(0).
        stageDryMass:Add(0).
    }
        
    for shipPart in Ship:Parts
    {
        // Ignore launch clamps
        if not shipPart:HasModule("LaunchClamp")
        {        
            local partStage is shipPart:DecoupledIn + 1.

            // Unstaged parts go into the top stage mass.
            set partStage to max(partStage, 0).
            set partStage to min(partStage, Stage:Number - 1).
                
            set stageWetMass[partStage] to stageWetMass[partStage] + shipPart:WetMass.
            set stageDryMass[partStage] to stageDryMass[partStage] + shipPart:DryMass.
        }
        else
        {
            if shipPart:HasModule("RefuelingPump")
                set padFuelling to true.
        }
    }

    from {local s is 1.} until s = Stage:Number step {set s to s+1.} do
    {
        set stageWetMass[s] to stageWetMass[s] + stageWetMass[s - 1].
        set stageDryMass[s] to stageDryMass[s] + stageWetMass[s - 1].
    }

	set launchMass to stageWetMass[Stage:Number-1].
    
    from {local s is Stage:Number - 1.} until s < 0 step {set s to s-1.} do
    {
        local massFlow is 0.
        local vacThrust is 0.
        local slThrust is 0.
        
        local stageEngines is LAS_GetStageEngines(s).
        for eng in stageEngines
        {
            set massFlow to massFlow + eng:PossibleThrustAt(0) / eng:VacuumIsp.
            set vacThrust to vacThrust + eng:PossibleThrustAt(0).
            set slThrust to slThrust + eng:PossibleThrustAt(1).
        }
        set massFlow to max(massFlow, 1e-6).

        log "  Stage " + s + ", drymass=" + round(stageDryMass[s] * 1000, 1) + ", wetmass=" + round(stageWetMass[s] * 1000, 1) +
            ", ThrustVac=" + round(vacThrust, 1) + ", IspVac=" + round(vacThrust / massFlow, 1) + ", IspSL=" + round(slThrust / massFlow, 1) to logPath.
    }
}

// Check for sufficient thrust
if mainEngines:length > 0
{
    local engineMaxThrust is 0.
    for eng in mainEngines
    {
        set engineMaxThrust to engineMaxThrust + eng:PossibleThrust().
    }
    
    local twr is engineMaxThrust / (launchMass * Ship:Body:Mu / LAS_ShipPos():SqrMagnitude).
    if twr < 1.1
    {
        print "Insufficient thrust for liftoff (TWR=" + round(twr, 2) + ", T=" + round(engineMaxThrust,1) + "kN, W=" + round((launchMass * Ship:Body:Mu / LAS_ShipPos():SqrMagnitude), 1) + "kN).".
        shutdown.
    }
}

if not padFuelling
    print "  No launch pad fuel feed, launching on full thrust.".
    
// Ascent time is estimated as 5 minutes
local leadAngle is 360 * (5 * 60) / Ship:Body:RotationPeriod.
local lock lanDiff to (Ship:Orbit:LAN + leadAngle) - TargetOrbit:LAN.
    
if TargetOrbit:IsType("Orbit")
{
    local waitDiff is lanDiff.
    print "landiff=" + waitDiff.
    if waitDiff > 0.1
        set waitDiff to waitDiff - 360.
    print "landiff=" + waitDiff.
        
    local waitTime is LAS_FormatTime(max(-waitDiff, 0) * Ship:Body:RotationPeriod / 360).
        
    print "Launch window opening in approximately " + waitTime.
}

print "Awaiting Launch command:".

// Wait for command
local cmd is " ".

until cmd = "l"
{
    set cmd to Terminal:Input:GetChar().
    if cmd = "a"
    {
        print "Aborting Launch.".
        break.    // User aborted launch sequence.
    }
    if cmd = "r"
        reboot.     // Direct reboot to allow for easy staging corrections.
}

if cmd = "l"
{
print "Go for Launch!".

if TargetOrbit:IsType("Orbit")
{
    local waitGui is GUI(200).
    local mainBox is waitGui:AddVBox().

    local guiHeading is mainBox:AddLabel("Awaiting launch window").

    // Launch window planning, simply matches ascending nodes.
    local lock lanDiff to (Ship:Orbit:LAN + leadAngle) - TargetOrbit:LAN.
    local waitDiff is lanDiff.
    if waitDiff > 0.08
        set waitDiff to waitDiff - 360.
    local waitTime is max(-waitDiff, 0) * Ship:Body:RotationPeriod / 360.

    local guiTime is mainBox:AddLabel("T-" + Time(waitTime):Clock).
    waitGui:Show().
    
    if waitTime > 60
        kUniverse:Timewarp:WarpTo(Time:Seconds + waitTime - 30).
        
    // Wait until we're within 0.1 degrees.
    until lanDiff < 0.1 and lanDiff > -0.05 and waitTime <= launchDelay
    {
        local t is 1.
        if waitTime > 3600
        {
            set t to mod(waitTime, 1800).
            if t < 10
                set t to t + 1800.
        }
        else if waitTime > 120
        {
            set t to mod(waitTime, 60).
            if t < 1
                set t to t + 60.
        }
        else if waitTime < 30
        {
            if kUniverse:Timewarp:Rate > 1
                kUniverse:Timewarp:CancelWarp().
        }
        
        wait t.
        
        if t > 0
        {
            set waitTime to waitTime - t.
            set guiTime:Text to "T-" + Time(waitTime):Clock.
        }
            
        set waitDiff to lanDiff.
        if waitDiff > 0.1
            set waitDiff to waitDiff - 360.
        set waitTime to max(-waitDiff, 0) * Ship:Body:RotationPeriod / 360.
    }
    kUniverse:Timewarp:CancelWarp().
    
    waitGui:Hide().
    
    set launchDelay to round(max(launchDelay, waitTime), 0).
}

local countdown is launchDelay.
set liftoffTime to Time:Seconds + launchDelay.

local function GLCAbort
{
    local parameter reason.
    
    local allEngines is list().
    list engines in allEngines.

    // Shutdown all engines
    for eng in allEngines
    {
        eng:Shutdown().
    }
    
    print reason.
    print "Aborting launch.". 

    if Ship:Status = "Flying"
    {
        abort on.
        // Wait for launch safety systems to clear the ship.
        wait 0.5.

        // check range safety, if within 1 km downrange of the launch site then RSO will command destruction.
        if Ship:RootPart:HasModule("ModuleRangeSafety")
        {
            local padVector is launchSite - LAS_ShipPos().
            
            if vxcl(LAS_ShipPos():Normalized, padVector):Mag < 1000
            {
                if Alt:Radar < 1000
                {
                    HudText("RSO: Commanded ship destruction.", 5, 2, 15, red, false).
                    Ship:RootPart:GetModule("ModuleRangeSafety"):DoAction("Range Safety", true).
                }
            }
        }
    }
    
    // Release control
    set Ship:Control:Neutralize to true.
    
    Shutdown.
}

// Setup countdown trigger
on ceiling(liftoffTime - Time:Seconds)
{
    set countdown to ceiling(liftoffTime - Time:Seconds).
    print countdown.
    if countdown > 0
        return true.
    else
        return false.
}

when Terminal:Input:HasChar() then
{
    if Terminal:Input:GetChar() = "a" and countdown > 0
        GLCAbort("Received abort command").
}

// Start launch
print "Auto launch sequence started.".
print "Liftoff in T-" + countdown + ".".

// Engine start sequence for liquid fuels
if engineStart > 0.5 and not mainEnginesLF:empty()
{
    wait until liftoffTime - Time:Seconds <= engineStart.

    print "Ignition sequence start.".

    // Throttle up to maximum
    set Ship:Control:PilotMainThrottle to 1.
    
    // Ignite all engines
    for eng in mainEnginesLF
    {
        LAS_IgniteEngine(eng).
        
        // Staggered start for multiple engines.
        wait startStagger.
    }

    local engCount is 1.
    for eng in mainEnginesLF
    {
        if not eng:Ignition()
        {
            GLCAbort(eng:Title + " " + engCount + " failed to ignite.").
        }
        set engCount to engCount + 1.
    }

    // Wait for full thrust
    local engineMaxThrust is 0.
    for eng in mainEnginesLF
    {
        set engineMaxThrust to engineMaxThrust + eng:PossibleThrust().
    }
    
    local engineThrust is 0.
    until Time:Seconds - liftoffTime >= -0.1
    {
        set engineThrust to 0.
        for eng in mainEnginesLF
        {
            set engineThrust to engineThrust + eng:Thrust().
        }

        if engineThrust >= engineMaxThrust * 0.98
        {
            break.
        }
        
        wait 0.1.
    }

    print "Main engines report " + round(100 * engineThrust / max(engineMaxThrust, 0.01), 1) + "% thrust".
    
    if engineThrust < engineMaxThrust * 0.98
    {
        GLCAbort("Main engines failed to reach commanded thrust.").
    }
    
    for eng in mainEnginesLF
    {
        if eng:Name = "ROE-RD108"
        {
            // Reduce roll torque calculation
            print "Increasing roll torque factor for " + eng:Name.
            set SteeringManager:RollTorqueFactor to 8.
            break.
        }
    }
}
    
// Wait for countdown
wait until countdown = 0 or not padFuelling.

local liftoffHeading is Ship:Facing.
lock Steering to liftoffHeading.

// Stage any boosters and launch clamps
if mainEngines:length() > mainEnginesLF:length()
    print "Booster Ignition".

set Ship:Control:PilotMainThrottle to 1.
stage.

wait 0.1.

until Ship:VerticalSpeed >= 5 and Ship:Status = "Flying"
{
    // Check for vertical movement
    if Ship:VerticalSpeed < -0.5
    {
        GLCAbort("Failed to achieve liftoff.").
    }
    wait 0.
}

print "Liftoff!".
}
// End of GLC, handoff to flight.