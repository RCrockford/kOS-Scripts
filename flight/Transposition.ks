// Docking active side
@lazyglobal off.

// Wait for unpack
if not Ship:Unpacked
{
    print "Wait for Unpack".
    wait until Ship:Unpacked.
}

parameter stageToDecouple is true.

local tPort is 0.
local portList is Ship:DockingPorts.

if Ship:PartsTagged("transpos"):Length > 0
{
    local decoupler is Ship:PartsTagged("transpos")[0].
    print "Decoupling " + decoupler:title.

    if stageToDecouple
    {
        stage.
    }
    else if decoupler:HasModule("ModuleDecouple")
    {
        decoupler:GetModule("ModuleDecouple"):DoEvent("decouple").
        wait 0.
    }
}

for p in portList
{
    if p:Ship <> ship
    {
        set tPort to p.
        break.
    }
}

local port is choose Ship:DockingPorts[0] if Ship:DockingPorts:Length > 0 else Ship:rootpart.

if port:IsType("DockingPort")
{
    print "Controlling from " + port:Title.
    port:ControlFrom().
}

if not (tPort:IsType("Part") or tPort:IsType("Vessel"))
{
    if not HasTarget
    {
        print "Waiting for target.".
        wait until hastarget.
    }
    set tPort to target.
}
else
{
    set target to tPort.
}

local tShip is tPort.
if tShip:IsType("Part")
{
    set tShip to tPort:Ship.
}

print "Detached from Lander".

clearguis().
local debugGui is GUI(300, 80).
set debugGui:X to 800.
set debugGui:Y to debugGui:Y - 180.
local mainBox is debugGui:AddVBox().
local debugStat1 is mainBox:AddLabel("").
local debugStat2 is mainBox:AddLabel("").
debugGui:Show().

local forePID is pidloop(2, 0, 0.5, -1, 1).
local starPID is pidloop(2, 0, 0.2, -1, 1).
local topPID is pidloop(2, 0, 0.2, -1, 1).

switch to scriptpath():volume.
runoncepath("/FCFuncs").
runpath("flight/TuneSteering").

LAS_Avionics("activate").

rcs on.

lock steering to lookdirup(-tPort:Position:Normalized, Facing:UpVector).

local clearDist is ship:Bounds:Size:Mag * 2.
local lock relV to (Ship:Velocity:Orbit - tShip:Velocity:Orbit).
local lock targetDist to (tPort:Position - port:Position):Mag.

local moveDist is clearDist.
local lock movePosCurrent to tPort:Position + tPort:Facing:Vector * tPort:Position:Mag.
local lock movePosFixed to tPort:Position + tPort:Facing:Vector * moveDist.
local movePos is movePosCurrent@.

runoncepath("/flight/RCSPerf").
local rcsPerf is GetRCSPerf().

local foreAccel is rcsPerf:Fore:thrust / Ship:Mass.
local starAccel is rcsPerf:Star:thrust / Ship:Mass.
local topAccel is rcsPerf:Up:thrust / Ship:Mass.

local starPosPID is pidloop(0.2, 0.02, 0.08, -starAccel * 4, starAccel * 4).
local topPosPID is pidloop(0.2, 0.02, 0.08, -topAccel * 4, topAccel * 4).
set starPID:kP to 1.25 / starAccel.
set topPID:kP to 1.25 / topAccel.
set starPID:kD to 0.25 / starAccel.
set topPID:kD to 0.25 / topAccel.

local function UpdateLateral
{
    set starPID:SetPoint to -starPosPID:Update(Time:Seconds, vdot(movePos(), Facing:StarVector)).
    set topPID:SetPoint to -topPosPID:Update(Time:Seconds, vdot(movePos(), Facing:TopVector)).
    set ship:control:starboard to starPID:Update(Time:Seconds, vdot(relV, Facing:StarVector)).
    set ship:control:top to topPID:Update(Time:Seconds, vdot(relV, Facing:TopVector)).
}

if vdot(Facing:Vector, tPort:Position:Normalized) < 0.999
{
    set debugStat2:Text to "Thrusting clear".
    set forePID:SetPoint to foreAccel * 10.

    until targetDist >= clearDist
    {
        set debugStat1:Text to "t=" + round(forePID:SetPoint, 2) + " v=" + round(vdot(relV, tPort:Position:Normalized), 2) + " d=" + round(targetDist, 1) + "/" + round(clearDist, 1) + " m=" + round(movePos():Mag, 2).
        
        set ship:control:fore to forePID:Update(Time:Seconds, vdot(-relV, tPort:Position:Normalized)).
        UpdateLateral().
        
        wait 0.
    }

    set forePID:SetPoint to -0.05.

    until abs(vdot(relV, tPort:Position:Normalized)) < 0.05 and movePos():Mag < 0.1
    {
        set debugStat1:Text to "t=" + round(0.05, 2) + " v=" + round(vdot(relV, tPort:Position:Normalized), 2) + " m=" + round(movePos():Mag, 2).

        set ship:control:fore to forePID:Update(Time:Seconds, vdot(-relV, tPort:Position:Normalized)).
        UpdateLateral().
        
        if abs(vdot(relV, tPort:Position:Normalized)) > 0.05
            set debugStat2:Text to "Stopping".
        else
            set debugStat2:Text to "Positioning".

        wait 0.
    }
    
    set moveDist to max(moveDist, tPort:Position:Mag).
    set movePos to movePosFixed@.

    lock steering to lookdirup(tPort:Position:Normalized, Facing:UpVector).

    set debugStat2:Text to "Orienting".

    until vdot(Facing:Vector, tPort:Position:Normalized) > 0.999 and movePos():Mag < moveDist / 50
    {
        set debugStat1:Text to " v=" + round(vdot(relV, tPort:Position:Normalized), 2) + " f=" + round(vang(Facing:Vector, tPort:Position:Normalized), 1) + " m=" + round(movePos():Mag, 2).

        set ship:control:fore to forePID:Update(Time:Seconds, -vdot(movePos(), Facing:Vector)).
        set ship:control:starboard to starPID:Update(Time:Seconds, -vdot(movePos(), Facing:StarVector)).
        set ship:control:top to topPID:Update(Time:Seconds, -vdot(movePos(), Facing:TopVector)).
        
        wait 0.
    }
    
    set movePos to movePosCurrent@.
}

lock steering to lookdirup(tPort:Position:Normalized, Facing:UpVector).

local startElements is Ship:Elements:Length.
set forePID:kP to 5.

set debugStat2:Text to "Approaching".
until Ship:Elements:Length > startElements
{
    local targetV is max(4, min(targetDist - 4, 16)) * foreAccel.
	set debugStat1:Text to "t=" + round(targetV, 2) + " v=" + round(vdot(relV, tPort:Position:Normalized), 2) + " d=" + round(targetDist, 1) + " m=" + round(movePos():Mag, 2).
    
    set forePID:SetPoint to targetV.
    set ship:control:fore to forePID:Update(Time:Seconds, vdot(relV, tPort:Position:Normalized)).
    UpdateLateral().
    
    wait 0.
}

unlock steering.
set Ship:Control:Neutralize to true.
rcs off.
LAS_Avionics("shutdown").

clearguis().
clearvecdraws().