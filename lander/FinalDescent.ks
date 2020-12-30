@lazyglobal off.

parameter DescentEngines.
parameter debugStat.
parameter targetPos.
parameter canAbort is false.

local burnThrust is 0.
local enginesOn is Ship:Control:PilotMainThrottle > 0.
local needUllage is false.

for eng in DescentEngines
{
    set burnThrust to burnThrust + eng:PossibleThrust.
    if not eng:Ignition
        set enginesOn to false.
    if eng:ullage
        set needUllage to true.
}

if burnThrust = 0
{
    local allrcs is list().
    list rcs in allrcs.
    for r in allrcs
    {
        if r:forebythrottle
            set burnThrust to burnThrust + r:AvailableThrust.
    }
    if burnThrust > 0
    {
        set enginesOn to false.
        set needUllage to false.
        print "Using RCS for descent".
    }
}

runoncepath("/lander/LanderThrottle", DescentEngines, enginesOn).

print "Descent mode active".

set Ship:Type to "Lander".
lock steering to LookDirUp(SrfRetrograde:Vector, Facing:UpVector).

// Touchdown speed
local vT is 0.5.
local abortMode is false.
local radarHeight is Ship:Bounds:BottomAltRadar.

until radarHeight < 2
{
    local maxAccel is burnThrust / Ship:Mass.
    local localGrav is Ship:Body:Mu / LAS_ShipPos():SqrMagnitude.
    
    // Use minimal height directly below and projected forwards
    set radarHeight to Ship:Bounds:BottomAltRadar.
    local h is min(radarHeight, Ship:Altitude - Body:GeopositionOf(SrfPrograde:Vector * radarHeight):TerrainHeight) - 1.
    set h to max(h, 0.1).

    // Commanded vertical acceleration is accel needed to reach vT in the height available
    local acgx is -(vT^2 - Ship:VerticalSpeed^2) / (2 * h).
    if Ship:VerticalSpeed > -vT
        set acgx to -acgx.

    local fr is (acgx + localGrav) / maxAccel.
    
    local f is fr / vdot(Facing:Vector, Up:Vector).
    local reqThrottle is max(0, min(f, 1)).
    if not enginesOn and reqThrottle >= 0.9
    {
        print "Ignition, rt= " + round(reqThrottle, 3).
        if needUllage
            EM_Ignition().
        LanderEnginesOn().
        set enginesOn to true.
    }
    LanderSetThrottle(reqThrottle).

    local debugStr to "h=" + round(h, 1) + " acgx=" + round(acgx, 3) + " fr=" + round(fr, 3) + " f=" + round(f, 3).
    if targetPos:IsType("GeoCoordinates")
        set debugStr to debugStr + " d=" + round(targetPos:Distance) + " m".
    set debugStat:Text to debugStr.
    
    if canAbort and Ship:VerticalSpeed < -8
    {
        if enginesOn and Ship:Control:PilotMainThrottle > 0 and not EM_CheckThrust(0.25 * Ship:Control:PilotMainThrottle)
        {
            set abortMode to true.
            print "Detected engine failure, aborting!".
            break.
        }
    }
    
    if not legs and Alt:Radar <= 50
    {
        legs on.
        gear on.
        brakes on.
    }

    wait 0.
}

if not abortMode
{
    lock steering to LookDirUp(Up:Vector, Facing:UpVector).
    
    local shipBounds is Ship:Bounds.

    until Ship:Status = "Landed" or Ship:Status = "Splashed"
    {
        LanderSetThrottle(-vT - Ship:VerticalSpeed).
        local debugStr to "h=" + round(shipBounds:BottomAltRadar, 1) + " fr=" + round(-vT - Ship:VerticalSpeed, 3) + " f=" + round(-vT - Ship:VerticalSpeed, 3).
        if targetPos:IsType("GeoCoordinates")
            set debugStr to debugStr + " d=" + round(targetPos:Distance) + " m".
        set debugStat:Text to debugStr.
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
    for eng in DescentEngines
        eng:Shutdown.

    local starVec is Body:GeoPositionOf(shipBounds:Extents:Mag * Facing:StarVector):Position - Body:GeoPositionOf(-shipBounds:Extents:Mag * Facing:StarVector):Position.
    local foreVec is Body:GeoPositionOf(shipBounds:Extents:Mag * Facing:ForeVector):Position - Body:GeoPositionOf(-shipBounds:Extents:Mag * Facing:ForeVector):Position.
    local slopeVec is vcrs(foreVec, starVec):Normalized.
    if vdot(slopeVec, Up:Vector) < 0
        set slopeVec to -slopeVec.

    lock steering to LookDirUp(slopeVec, Facing:UpVector).
    wait 0.5.

    // Maintain attitude control until ship settles to prevent roll overs.
    until Ship:Velocity:Surface:Mag < 0.1 and Ship:AngularVel:Mag < 0.01
    {
        set debugStat:Text to "v=" + round(Ship:Velocity:Surface:Mag, 2) + " / 0.1 a=" + round(Ship:AngularVel:Mag, 4) + " / 0.01".
    }

    unlock steering.
    set Ship:Control:Neutralize to true.
    rcs off.

    LAS_Avionics("shutdown").
    ClearGUIs().

    runpath("/lander/setstability").

    print "Landing completed".
}