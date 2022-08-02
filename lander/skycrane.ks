@lazyglobal off.

// Wait for unpack
parameter DescentEngines.
parameter readoutGui.
parameter waypointPos.

local heightKp is 0.5.
local heightKi is 0.01.
local heightKd is 0.25.

local speedKp is 2.
local speedKi is 0.1.
local speedKd is 0.2.

local steerKp is 0.1.
local steerKi is 0.0.
local steerKd is 0.05.

local heightPID is PIDLoop(heightKp, heightKi, heightKd, -4, 4).
local speedPID is PIDLoop(speedKp, speedKi, speedKd, -1, 1).
local hSpeedPID is PIDLoop(0.25, 0, 2, -12, 12).
local steerPID is PIDLoop(steerKp, steerKi, steerKd, -0.2, 0.2).

// Drop braking stage if required.
if DescentEngines:Length < 4
{
    print "Sky crane settling.".

    local f is SrfRetrograde:Vector.
    lock steering to LookDirUp(f, Facing:UpVector).
    
    local engThrust is 0.
    for eng in DescentEngines
        set engThrust to engThrust + eng:PossibleThrust.
    
    until vdot(Facing:Vector, Up:Vector) > 0.78 and (Ship:AngularVel:Mag < 0.05 or Ship:VerticalSpeed < -8)
    {
        LanderSetThrottle((Ship:Body:Mu / Body:Position:SqrMagnitude) / (max(vdot(Facing:Vector, Up:Vector), 0.8) * engThrust / Ship:Mass) - Ship:VerticalSpeed * 0.1).
        local steerData is LanderSteering(-Body:Position, Ship:Velocity:Surface, 0).
        local steerVec is steerData:vec.
        local fr is vdot(SrfRetrograde:Vector, Up:Vector).
        set fr to min(max(fr, 0.8), 0.999).
        set f to fr * Up:Vector + sqrt(1 - fr * fr) * steerVec.
        wait 0.
    }
    
    LanderEnginesOff().
    stage.
    wait until stage:ready.
}

local shipBounds is Ship:bounds.
local lock radarHeight to shipBounds:BottomAltRadar.

local TargetHeight is radarHeight.
local targetPos is waypointPos.
if not targetPos:IsType("GeoCoordinates")
    set targetPos to Ship:GeoPosition.

local CraneEngines is list().
until CraneEngines:Length > 0
{
    wait 0.
    EM_ResetEngines(Stage:Number).
    set CraneEngines to EM_GetEngines().
}

print "Sky crane active.".

readoutGui:ClearAll().
local Readouts is lexicon().

Readouts:Add("vspeed", readoutGui:AddReadout("VSpeed")).
Readouts:Add("vaccel", readoutGui:AddReadout("VAccel")).
Readouts:Add("throt", readoutGui:AddReadout("Throttle")).

Readouts:Add("hspeed", readoutGui:AddReadout("HSpeed")).
Readouts:Add("haccel", readoutGui:AddReadout("HAccel")).
Readouts:Add("limit", readoutGui:AddReadout("Limit")).

Readouts:Add("Δv", readoutGui:AddReadout("Δv")).
Readouts:Add("margin", readoutGui:AddReadout("Margin")).
Readouts:Add("fuel", readoutGui:AddReadout("Fuel")).

Readouts:Add("dist", readoutGui:AddReadout("Distance")).
Readouts:Add("alt", readoutGui:AddReadout("Target")).
Readouts:Add("height", readoutGui:AddReadout("Height")).

local engThrust is 0.
for eng in CraneEngines
{
    set eng:ThrustLimit to 100.
    set engThrust to engThrust + eng:PossibleThrust.
}

runpath("/lander/LanderThrottle", CraneEngines).

GatherFuelStatus(CraneEngines).
local bingoFuel is false.
local ejectMode is false.

LanderSetupDiffThrottle().
LanderEnginesOn().

local steerVec is Up:Vector.
lock steering to lookdirup(steerVec, Facing:UpVector).

local function ControlUpdate
{
    if targetHeight > 10
        set HeightPID:SetPoint to max(Ship:GeoPosition:TerrainHeight, min(targetPos:TerrainHeight, Ship:GeoPosition:TerrainHeight + 100)) + TargetHeight.
    else
        set HeightPID:SetPoint to TargetHeight.
    local localGrav is (Body:Mu / Body:Position:SqrMagnitude).
    local maxAccel is engThrust / Ship:Mass.
    
    set speedPID:MinOutput to min(localGrav - maxAccel, -1).
    set speedPID:MaxOutput to max(maxAccel - localGrav, 1).
    set HeightPID:MinOutput to speedPID:MinOutput * 4.
    set HeightPID:MaxOutput to speedPID:MaxOutput * 4.
    
    set steerPID:MinOutput to -max(0.1, min(0.6 * (maxAccel / localGrav - 1), 1)).
    set steerPID:MaxOutput to -steerPID:MinOutput.
    set hSpeedPID:MinOutput to steerPID:MinOutput * maxAccel * 3.
    set hSpeedPID:MaxOutput to steerPID:MaxOutput * maxAccel * 3.

    if targetHeight > 10
        set speedPID:SetPoint to heightPID:Update(Time:Seconds, Ship:Altitude).
    else
        set speedPID:SetPoint to heightPID:Update(Time:Seconds, radarHeight).
    local speedAccel is speedPID:Update(Time:Seconds, Ship:VerticalSpeed).
    local targetAccel is localGrav + speedAccel.
    
    local targetVec is vxcl(Up:Vector, targetPos:Position).
    local targetSpeed is -hSpeedPID:Update(Time:Seconds, targetVec:Mag).
    
    local horizVel is vxcl(Up:Vector, Ship:Velocity:Surface).
    local targetVel is targetVec:Normalized * targetSpeed.
    local hAccel is steerPID:Update(Time:Seconds, (horizVel - targetVel):Mag).
    
    if ejectMode
    {
        set steerVec to Up:Vector + (horizVel - targetVel):Normalized.
        LanderSetThrottle(1).
    }
    else
    {
        set steerVec to Up:Vector + hAccel * (horizVel - targetVel):Normalized.
        LanderSetThrottle(targetAccel / maxAccel).
    }
    
    local ΔVmargin is 2 * sqrt(2 * TargetHeight / (Body:Mu / Body:Position:SqrMagnitude)) * (Body:Mu / Body:Position:SqrMagnitude).
    local fuelStatus is CurrentFuelStatus(CraneEngines).
    if not bingoFuel and fuelStatus[1] < Ship:Velocity:Surface:Mag + ΔVmargin
    {
        set bingoFuel to true.
        print "Bingo Fuel".
    }
    
    ReadoutGUI_SetText(Readouts:vspeed, round(speedPID:SetPoint, 2), ReadoutGUI_ColourNormal).
    ReadoutGUI_SetText(Readouts:vaccel, round(speedAccel, 2), ReadoutGUI_ColourNormal).
    ReadoutGUI_SetText(Readouts:throt, round(100 * targetAccel / maxAccel, 1) + "%", ReadoutGUI_ColourNormal).

    ReadoutGUI_SetText(Readouts:hspeed, round(targetSpeed, 2) + " m", ReadoutGUI_ColourNormal).
    ReadoutGUI_SetText(Readouts:haccel, round(hAccel, 3), ReadoutGUI_ColourNormal).
    ReadoutGUI_SetText(Readouts:limit, round(hSpeedPID:MaxOutput, 2), ReadoutGUI_ColourNormal).

    ReadoutGUI_SetText(Readouts:Δv, round(fuelStatus[1], 1) + " m/s", ReadoutGUI_ColourNormal).
    ReadoutGUI_SetText(Readouts:margin, round(fuelStatus[1]  - (Ship:Velocity:Surface:Mag + ΔVmargin), 3) + " m/s", ReadoutGUI_ColourNormal).
    if bingoFuel
        ReadoutGUI_SetText(Readouts:fuel, round(fuelStatus[0] * 100, 1) + "% Bingo", ReadoutGUI_ColourFault).
    else
        ReadoutGUI_SetText(Readouts:fuel, round(fuelStatus[0] * 100, 1) + "%", ReadoutGUI_ColourGood).
        
    ReadoutGUI_SetText(Readouts:dist, round(targetVec:Mag, 1) + " m", ReadoutGUI_ColourNormal).
    ReadoutGUI_SetText(Readouts:alt, round(HeightPID:SetPoint, 1) + " m", ReadoutGUI_ColourNormal).
    ReadoutGUI_SetText(Readouts:height, round(radarHeight, 2) + " m", ReadoutGUI_ColourNormal).
        
    return targetVec:Mag.
}

print "Flying to target".

set TargetHeight to 50.
local dist is 100.

until dist < 20 or bingoFuel
{
    set dist to ControlUpdate().
    set TargetHeight to max(TargetHeight, dist).
    wait 0.
}

print "Setting down payload".

set TargetHeight to 3.

//until radarHeight < 5 and abs(Ship:Velocity:Surface:Mag) < 0.5
until radarHeight < 15
{
    local dist is ControlUpdate().
    if bingoFuel or dist > 40
        set targetPos to ship:geoPosition.
    wait 0.
}

until Stage:number = 0
{
    if stage:ready
        stage.
    
    ControlUpdate().
    wait 0.
}

set shipBounds to Ship:bounds.

if waypointPos:Distance >= 1000
    print "Waypoint distance: " + round((waypointPos:Position - Ship:GeoPosition:Position):Mag * 0.001, 2) + " km".
else
    print "Waypoint distance: " + round((waypointPos:Position - Ship:GeoPosition:Position):Mag, 1) + " m".

print "Ejecting crane".

// Dump crane
set TargetHeight to 100.
set targetPos to Body:GeoPositionOf(targetPos:Position + Facing:StarVector * 2000).

set ejectMode to true.

until radarHeight > 60 and Ship:GroundSpeed > 20
{
    ControlUpdate().
    wait 0.
}

ClearGUIs().
LanderEnginesOff().
