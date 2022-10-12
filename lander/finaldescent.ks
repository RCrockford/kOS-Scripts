@lazyglobal off.

parameter DescentEngines.
parameter Readouts.
parameter targetPos.
parameter canAbort is false.
parameter ignoreTarget is lexicon("pressed", false).

local enginesOn is Ship:Control:PilotMainThrottle > 0.
local needUllage is false.
local multiIgnition is true.

for eng in DescentEngines
{
    if not eng:Ignition
        set enginesOn to false.
    if eng:ullage
        set needUllage to true.
    if eng:Ignitions >= 0 and eng:Ignitions < 10
        set multiIgnition to false.
}

if needUllage
    set multiIgnition to false.

runoncepath("/lander/landerthrottle", DescentEngines, enginesOn).
if needUllage
    runpath("/flight/enginemgmt", Stage:Number).
    
local FuelEngines is DescentEngines.
if DescentEngines:Length = 0
{
    set FuelEngines to list().
    for eng in Ship:RCS
    {
        if eng:ForeByThrottle
            FuelEngines:Add(eng).
    }
}

local ullageTime is 0.
if needUllage and not enginesOn
{
    set ullageTime to EM_IgDelay().
}

local burnThrust is LanderMaxThrust().

print "Descent mode active".

set Ship:Type to "Lander".
local steerVec is SrfRetrograde:Vector.
lock steering to LookDirUp(steerVec, Facing:UpVector).

local shipBounds is Ship:Bounds.

// Touchdown speed
local vT is 0.8.
local abortMode is false.
local engFailTime is 0.
local radarHeight is shipBounds:BottomAltRadar.
local killThrott is false.
local cutThrott is 0.75.
local ignThrottle is 0.9 - FuelEngines:Length * 0.0125.
local bingoFuel is not Readouts:HasKey("fuel").

if LanderMinThrottle() < 0.9
{
    set cutThrott to LanderMinThrottle().
    set ignThrottle to 0.85 + LanderMinThrottle() * 0.15.
}

local hSpeedPID is PIDLoop(0.25, 0, 0.2, -2, 2).
local steerPID is PIDLoop(1, 0.05, 0.6, -1, 1).

until radarHeight < 2
{
    local maxAccel is burnThrust / Ship:Mass.
    local localGrav is Ship:Body:Mu / LAS_ShipPos():SqrMagnitude.

    // Use minimal height directly below and projected forwards
    set radarHeight to shipBounds:BottomAltRadar.
    local h is min(radarHeight, Ship:Altitude - Body:GeopositionOf(SrfPrograde:Vector * radarHeight):TerrainHeight) - 1.
    set h to max(h, 0.1).

    // Commanded vertical acceleration is accel needed to reach vT in the height available
    local vSpeed is Ship:VerticalSpeed - localGrav * ullageTime.
    local nextH is h - vSpeed * ullageTime.
    local acgx is -(vT^2 - vSpeed^2) / (2 * nextH).
    
    local targetDist is -1.
    if targetPos:IsType("GeoCoordinates")
    {
        set targetDist to targetPos:AltitudePosition(Ship:Altitude):Mag.
    }

    // Prevent too much tip over in final descent
    local tiltMul is max(0.999 - min(Ship:GroundSpeed * 0.1, 0.25), vdot(SrfRetrograde:Vector, Up:Vector)).
    set steerVec to Up:Vector * tiltMul + vxcl(Up:Vector, SrfRetrograde:Vector) * sqrt(1 - tiltMul).
    local steerMode is false.
    
    if not bingoFuel and targetDist <= 100 and (targetDist >= 5 or Ship:GroundSpeed > 0.5) and h > 5 and not ignoreTarget:pressed and vdot(Facing:Vector, Up:Vector) > 0.9
    {
        if targetDist >= 10
        {
            // Slow descent while steering
            local responseT is -8.
            set acgx to 6 * Ship:VerticalSpeed / responseT.
            set steerMode to true.
        }

        local targetVec is vxcl(Up:Vector, targetPos:Position).
        local targetSpeed is -hSpeedPID:Update(Time:Seconds, targetVec:Mag).
    
        local horizVel is vxcl(Up:Vector, Ship:Velocity:Surface).
        local targetVel is targetVec:Normalized * targetSpeed.
        local hAccel is steerPID:Update(Time:Seconds, (horizVel - targetVel):Mag).
        
        if Readouts:HasKey("steermul")
            RGUI_SetText(Readouts:steermul, round(targetSpeed, 2) + "m/s", RGUI_ColourNormal).
            
        if abs(horizVel:Mag) < hSpeedPID:MaxOutput * 1.05
        {
            set steerVec to Up:Vector.
            set hAccel to hAccel * (horizVel - targetVel):Normalized.
            set ship:control:starboard to vdot(Facing:StarVector, hAccel).
            set ship:control:top to vdot(Facing:TopVector, hAccel).
        }
    }
    else
    {
        set ship:control:starboard to 0.
        set ship:control:top to 0.
    }

    local fr is (acgx + localGrav) / maxAccel.

    if fr > ignThrottle * 0.8 or steerMode
        set killThrott to false.
    else if Ship:VerticalSpeed > -(vT * (vdot(SrfRetrograde:Vector, Up:Vector) + 0.5))
        set killThrott to true.
    if killThrott
        set fr to 0.

    local f is fr / max(vdot(Facing:Vector, Up:Vector), 0.7).
    local reqThrottle is max(0, min(f, 1)).
    if not enginesOn and ((reqThrottle >= ignThrottle and vdot(Facing:Vector, SrfRetrograde:Vector) > 0.8 and (Ship:VerticalSpeed < -10 or h < 50)) or (steerMode and vdot(Facing:Vector, Up:Vector) > 0.99))
    {
        if needUllage
            EM_Ignition().
        LanderEnginesOn().
        set enginesOn to true.
        set ullageTime to 0.
    }
    else if multiIgnition and enginesOn and reqThrottle < cutThrott
    {
        LanderEnginesOff().
        set enginesOn to false.
    }
    LanderSetThrottle(reqThrottle).

    RGUI_SetText(Readouts:height, round(h, 1) + " m", RGUI_ColourNormal).
    RGUI_SetText(Readouts:acgx, round(acgx, 3), RGUI_ColourNormal).
    RGUI_SetText(Readouts:fr, round(fr, 3), RGUI_ColourNormal).
    
    if targetPos:IsType("GeoCoordinates")
    {
        local wpBearing is vang(vxcl(up:vector, TargetPos:Position), vxcl(up:vector, Ship:Velocity:Surface)).
        RGUI_SetText(Readouts:dist, round(targetDist, 1) + " m", RGUI_ColourNormal).
        RGUI_SetText(Readouts:bearing, round(wpBearing, 3) + "°", RGUI_ColourNormal).
    }

    if Readouts:HasKey("fuel")
    {
        local fuelStatus is CurrentFuelStatus(FuelEngines).
        RGUI_SetText(Readouts:Δv, round(fuelStatus[1], 1) + " m/s", RGUI_ColourNormal).
        RGUI_SetText(Readouts:margin, round(fuelStatus[1]  - Ship:Velocity:Surface:Mag, 1) + " m/s", RGUI_ColourNormal).
        RGUI_SetText(Readouts:fuel, round(fuelStatus[0] * 100, 1) + "%", RGUI_ColourGood).
        
        local ΔVmargin is 2 * sqrt(2 * h / (Body:Mu / Body:Position:SqrMagnitude)) * (Body:Mu / Body:Position:SqrMagnitude).
        if not bingoFuel and fuelStatus[1] < Ship:Velocity:Surface:Mag + ΔVmargin
            set bingoFuel to true.
    }
    
    RGUI_SetText(Readouts:throt, round(100 * reqThrottle, 1) + "%", RGUI_ColourNormal).

    local thrustData is LanderCalcThrust(FuelEngines).
    RGUI_SetText(Readouts:thrust, round(100 * min(thrustData:current / max(LanderMaxThrust(), 0.001), 2), 2) + "%", 
        choose RGUI_ColourGood if thrustData:current > thrustData:nominal * 0.75 else
        (choose RGUI_ColourNormal if thrustData:current > thrustData:nominal * 0.25 else RGUI_ColourFault)).

    if canAbort and Ship:VerticalSpeed < -8
    {
        if enginesOn and thrustData:current < thrustData:nominal * 0.25
        {
            if Time:Seconds - engFailTime > 1
            {
                set abortMode to true.
                print "Detected engine failure, aborting!".
                break.
            }
        }
        else
        {
            set engFailTime to Time:Seconds.
        }
    }

    if not legs and radarHeight <= 100
    {
        legs on.
        gear on.
        brakes on.
        local checkBounds is time:seconds + 3.
        when checkBounds >= time:seconds then
        {
            set shipBounds to Ship:Bounds.
        }
    }

    wait 0.
}

if core:tag:contains("hoverdock")
{
    print "Waiting for docking target".
    lock steering to LookDirUp(Up:Vector, Facing:UpVector).
    
    until HasTarget and target:IsType("DockingPort")
    {
        local maxAccel is burnThrust / Ship:Mass.
        local localGrav is Ship:Body:Mu / LAS_ShipPos():SqrMagnitude.
        LanderSetThrottle(localGrav / maxAccel).
        
        RGUI_SetText(Readouts:throt, round(100 * (-vT - Ship:VerticalSpeed), 1) + "%", RGUI_ColourNormal).
        
        RGUI_SetText(Readouts:height, round(shipBounds:BottomAltRadar, 1) + " m", RGUI_ColourNormal).
        RGUI_SetText(Readouts:fr, round(-vT - Ship:VerticalSpeed, 3), RGUI_ColourNormal).
        
        if targetPos:IsType("GeoCoordinates")
            RGUI_SetText(Readouts:dist, round(targetPos:Distance) + " m", RGUI_ColourNormal).

        wait 0.
    }
    
    runpath("/bases/dockside").
}
else if not abortMode
{
    lock steering to LookDirUp(Up:Vector, Facing:UpVector).
    set shipBounds to Ship:Bounds.

    until Ship:Status = "Landed" or Ship:Status = "Splashed"
    {
        LanderSetThrottle(-vT - Ship:VerticalSpeed).
        
        RGUI_SetText(Readouts:throt, round(100 * (-vT - Ship:VerticalSpeed), 1) + "%", RGUI_ColourNormal).
        
        RGUI_SetText(Readouts:height, round(shipBounds:BottomAltRadar, 1) + " m", RGUI_ColourNormal).
        RGUI_SetText(Readouts:fr, round(-vT - Ship:VerticalSpeed, 3), RGUI_ColourNormal).
        
        if targetPos:IsType("GeoCoordinates")
            RGUI_SetText(Readouts:dist, round(targetPos:Distance) + " m", RGUI_ColourNormal).

        wait 0.
    }

    print "Touchdown speed: " + round(-Ship:VerticalSpeed, 2) + " m/s".
    if targetPos:IsType("GeoCoordinates")
    {
        if targetPos:Distance >= 1000
            print "Waypoint distance: " + round((targetPos:Position - Ship:GeoPosition:Position):Mag * 0.001, 2) + " km".
        else
            print "Waypoint distance: " + round((targetPos:Position - Ship:GeoPosition:Position):Mag, 1) + " m".
    }

    set Ship:Control:PilotMainThrottle to 0.
    LanderEnginesOff().

    local starVec is Body:GeoPositionOf(shipBounds:Extents:Mag * Facing:StarVector):Position - Body:GeoPositionOf(-shipBounds:Extents:Mag * Facing:StarVector):Position.
    local foreVec is Body:GeoPositionOf(shipBounds:Extents:Mag * Facing:ForeVector):Position - Body:GeoPositionOf(-shipBounds:Extents:Mag * Facing:ForeVector):Position.
    local slopeVec is vcrs(foreVec, starVec):Normalized.
    if vdot(slopeVec, Up:Vector) < 0
        set slopeVec to -slopeVec.

    lock steering to LookDirUp(slopeVec, Facing:UpVector).
    wait 0.5.

    // Maintain attitude control until ship settles to prevent roll overs.
    wait until Ship:Velocity:Surface:Mag < 0.1 and Ship:AngularVel:Mag < 0.01.

    unlock steering.
    set Ship:Control:Neutralize to true.
    rcs off.

    LAS_Avionics("shutdown").
    ClearGUIs().
    
    for panel in Ship:ModulesNamed("ModuleROSolar")
        if panel:HasAction("extend solar panel")
            panel:DoAction("extend solar panel", true).

    for panel in Ship:ModulesNamed("ModuleDeployableSolarPanel")
        if panel:HasAction("extend solar panel")
            panel:DoAction("extend solar panel", true).

    for antenna in Ship:ModulesNamed("ModuleDeployableAntenna")
        if antenna:HasEvent("extend antenna")
            antenna:DoEvent("extend antenna").

    //runpath("/lander/setstability").

    print "Landing completed".
}