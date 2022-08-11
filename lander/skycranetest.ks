@lazyglobal off.

// Wait for unpack
wait until Ship:Unpacked.
switch to scriptpath():volume.

ClearGUIs().

global flightGui is Gui(300).
set flightGui:X to 200.
set flightGui:Y to flightGui:Y + 60.

local mainBox is flightGui:AddHBox().
local labelBox is mainBox:AddVBox().
set labelBox:style:width to 150.
local controlBox is mainBox:AddVBox().
set controlBox:style:width to 150.

local function CreateTextEdit
{
    parameter lbl.
    parameter str.
    parameter dlg.

    local newLabel is labelBox:AddLabel(lbl).
    set newLabel:Style:Height to 25.
    
    local newControl is controlBox:AddTextField(str).
    set newControl:Style:Height to 25.
    set newControl:OnConfirm to dlg.
    set newControl:Enabled to false.
    
    return newControl.
}

local TargetHeight is max(50, round(Alt:Radar)).
local TargetLat is Ship:Latitude.
local TargetLng is Ship:Longitude.

local heightKp is 0.5.
local heightKi is 0.01.
local heightKd is 0.25.

local speedKp is 2.
local speedKi is 0.2.
local speedKd is 1.

local steerKp is 0.1.
local steerKi is 0.0.
local steerKd is 0.05.
local steerLimit is 0.2.

local TargetHeightText is CreateTextEdit("Target Height", TargetHeight:ToString, { parameter str. set TargetHeight to str:ToNumber(TargetHeight). }).
local TargetLatText is CreateTextEdit("Target Lat", TargetLat:ToString, { parameter str. set TargetLat to str:ToNumber(TargetLat). }).
local TargetLngText is CreateTextEdit("Target Lng", TargetLng:ToString, { parameter str. set TargetLng to str:ToNumber(TargetLng). }).

flightGui:Show.

local heightPID is PIDLoop(heightKp, heightKi, heightKd, -4, 4).
local speedPID is PIDLoop(speedKp, speedKi, speedKd, -1, 1).
local hSpeedPID is PIDLoop(0.5, 0, 1, -12, 12).
local steerPID is PIDLoop(steerKp, steerKi, steerKd, -steerLimit, steerLimit).

local mainEngines is list().
list engines in mainEngines.

local engThrust is 0.
for eng in mainEngines
    set engThrust to engThrust + eng:PossibleThrust.

runpath("/lander/landerthrottle", mainEngines).

local steerVec is Up:Vector.
lock steering to lookdirup(steerVec, Facing:UpVector).

LanderSetupDiffThrottle().
LanderEnginesOn().

local minThrottle is mainEngines[0]:MinThrottle.

local shipBounds is ship:bounds.
local lock radarHeight to shipBounds:BottomAltRadar.

local function ControlUpdate
{
    set HeightPID:SetPoint to max(Ship:GeoPosition:TerrainHeight, LatLng(TargetLat, TargetLng):TerrainHeight) + TargetHeight.
    local localGrav is (Body:Mu / Body:Position:SqrMagnitude).
    local maxAccel is engThrust / Ship:Mass.
    
    set speedPID:MinOutput to localGrav - maxAccel.
    set speedPID:MaxOutput to maxAccel - localGrav.
    set HeightPID:MinOutput to speedPID:MinOutput * 4.
    set HeightPID:MaxOutput to speedPID:MaxOutput * 4.

    set speedPID:SetPoint to heightPID:Update(Time:Seconds, Ship:Altitude).
    local speedAccel is speedPID:Update(Time:Seconds, Ship:VerticalSpeed).
    local targetAccel is localGrav + speedAccel.
    
    local targetPos is LatLng(TargetLat, TargetLng).
    set targetPos to vxcl(Up:Vector, targetPos:Position).
    local targetSpeed is -hSpeedPID:Update(Time:Seconds, targetPos:Mag).

    print "Accel: " + round(targetAccel, 2) + " / " + round(maxAccel, 2) + " thr=" + round(targetAccel / maxAccel, 3) + "              " at (0,0).
    print "Speed: " + round(speedPID:SetPoint, 2) + " / " + round(speedAccel, 2) + " [" + round(speedPID:MaxOutput, 1) + "]              " at (0,1).
    print "Dist:  " + round(targetPos:Mag, 2) + " / " + round(targetSpeed, 3) + " h=" + round(radarHeight, 2) + "            " at (0,2).
        
    local horizVec is vxcl(Up:Vector, Ship:Velocity:Surface).
    local targetVec is targetPos:Normalized * targetSpeed.
    local hSpeed is steerPID:Update(Time:Seconds, (horizVec - targetVec):Mag).
    set steerVec to Up:Vector + hSpeed * (horizVec - targetVec):Normalized.
    
    print "Steer: " + round((horizVec - targetVec):Mag, 3) + " / " + round(hSpeed, 3) + "                " at (0,3).
    
    LanderSetThrottle(targetAccel / maxAccel).
    
    return targetPos:Mag.
}

until radarHeight > 5
{
    ControlUpdate().
    wait 0.
}

set TargetLng to 177.868845.
set TargetHeight to 20.

until ControlUpdate() < 20
{
    wait 0.
}

set TargetHeight to 3.

until ControlUpdate() < 2 and radarHeight < 5 and abs(Ship:VerticalSpeed) < 0.2
{
    wait 0.
}

until Stage:number = 0
{
    if stage:ready
        stage.
    
    ControlUpdate().
    wait 0.
}

local tryLand is (engThrust * minThrottle / Ship:Mass) < (Body:Mu / Body:Position:SqrMagnitude) * 0.9.
if tryLand
{
    set TargetHeight to 40.
    set TargetLat to TargetLat - 0.0004.
    
    until ControlUpdate() < 20
        wait 0.

    set TargetHeight to 2.5.

    until radarHeight < 3 and Ship:VerticalSpeed> -0.2
    {
        ControlUpdate().
        wait 0.
    }
}
else
{
    set TargetHeight to 100.
    set TargetLat to TargetLat - 0.001.

    set hSpeedPID:MinOutput to -40.
    set hSpeedPID:MaxOutput to 40.
    set steerPID:MinOutput to -1.
    set steerPID:MaxOutput to 1.

    until radarHeight > 60
    {
        ControlUpdate().
        wait 0.
    }
}

LanderEnginesOff().