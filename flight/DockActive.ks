// Docking active side
@lazyglobal off.

if not HasTarget
{
    print "Waiting for target.".
    wait until hastarget.
}

local tShip is target.
local tPort is target.

if tShip:IsType("DockingPort")
{
    set tShip to tShip:Ship.
}

// Wait for unpack
wait until Ship:Unpacked.

local port is 0.
for p in Ship:Parts
{
    if p:IsType("DockingPort")
    {
        set port to p.
        break.
    }
}

if port:IsType("DockingPort")
{
    print "Controlling from " + port:Title.
    port:ControlFrom().
}
else
{
    set port to Ship:rootpart.
}

local debugGui is GUI(300, 80).
set debugGui:X to 800.
set debugGui:Y to debugGui:Y - 180.
local mainBox is debugGui:AddVBox().
local debugStat1 is mainBox:AddLabel("").
local debugStat2 is mainBox:AddLabel("").
debugGui:Show().

local forePID is pidloop(2, 0, 0.5, -1, 1).
local starPID is pidloop(5, 0.2, 1, -1, 1).
local topPID is pidloop(5, 0.2, 1, -1, 1).

switch to scriptpath():volume.
runoncepath("/FCFuncs").
runpath("/flight/TuneSteering").

runoncepath("/flight/RCSPerf.ks").
local RCSPerf is GetRCSForePerf().
local maxSpeed is max(0.5, min(5, 5 * RCSPerf:thrust / Ship:Mass)).
print "Setting max speed to " + round(maxSpeed, 2) + " m/s".

LAS_Avionics("activate").

rcs on.
lock steering to lookdirup(tPort:Position:Normalized, Facing:UpVector).

local startElements is Ship:Elements:Length.

until (port:IsType("DockingPort") and port:State <> "Ready") or Ship:Elements:Length > startElements
{
    local relV is (tShip:Velocity:Orbit - Ship:Velocity:Orbit).
    
    local targetV is max(maxSpeed / 8, min(tPort:Position:Mag / 10, maxSpeed)).
    
	set debugStat1:Text to "t=" + round(targetV, 2) + " v=" + round(vdot(-relV, tPort:Position:Normalized), 2).
    
    if vdot(Facing:Vector, tPort:Position:Normalized) > 0.999
    {
        set forePID:SetPoint to targetV.
        set ship:control:fore to forePID:Update(Time:Seconds, vdot(-relV, tPort:Position:Normalized)).
        
        local correct is relV:Normalized - tPort:Position:Normalized.
        set ship:control:starboard to starPID:Update(Time:Seconds, -vdot(correct, Facing:StarVector)).
        set ship:control:top to topPID:Update(Time:Seconds, -vdot(correct, Facing:TopVector)).
        
        set debugStat2:Text to "star= " + round(ship:control:starboard, 2) + " top=" + round(ship:control:top, 2).
    }
    else
    {
        set ship:control:fore to 0.
        set ship:control:starboard to 0.
        set ship:control:top to 0.
        
        set debugStat2:Text to "orienting".
    }
    
    wait 0.
}

unlock steering.
set Ship:Control:Neutralize to true.
rcs off.
LAS_Avionics("shutdown").

clearguis().