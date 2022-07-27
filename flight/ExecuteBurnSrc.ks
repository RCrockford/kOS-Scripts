@lazyglobal off.

wait until Ship:Unpacked.

local p is lexicon(open("1:/burn.csv"):readall:string:split(",")).
for k in p:keys
    set p[k] to p[k]:ToScalar(0).

local lock tVec to Prograde:Vector.
local lock bVec to vcrs(tVec, up:vector):Normalized.
local lock nVec to vcrs(tVec, bVec):Normalized.

local dV is 0.
if HasNode
    lock burnETA to NextNode:eta.
else
    lock burnETA to p:eta - Time:Seconds.

print "Align in " + round(burnETA - p:align, 0) + " seconds (T-" + round(p:align) + ").".

wait until burnETA <= p:align.

kUniverse:Timewarp:CancelWarp().

if scriptpath():ToString[0] = "0"
{
    print "Waiting for downlink".
    wait until HomeConnection:IsConnected.
}

print "Aligning ship".

local debugGui is GUI(350, 80).
set debugGui:X to 100.
set debugGui:Y to debugGui:Y + 300.
local mainBox is debugGui:AddVBox().
local debugStat is mainBox:AddLabel("Aligning ship").
debugGui:Show().

runoncepath("/FCFuncs").
runpath("flight/TuneSteering").

local ignitionTime is 0.
local mainEng is 0.
if p:eng > 0
{
    runpath("/flight/EngineMgmt", p:stage).
    set ignitionTime to EM_IgDelay().
    set mainEng to EM_GetEngines()[0].
}

global function CheckHeading
{
    if HasNode and nextNode:eta <= p:align
        set dV to NextNode:deltaV.
    else if p:haskey("dVx")
        set dV to tVec * p:dVx + nVec * p:dVy + bVec * p:dVz.
}

global function RollControl
{
    local cmdroll is 0.
    local rollRate is vdot(Facing:Vector, Ship:AngularVel).
    if p:haskey("spin") and vdot(dV:Normalized, Facing:Vector) > 0.999
    {
        // spin up
        if abs(rollRate) > p:spin * 1.25
        {
            set cmdroll to 0.1.
        }
        else if abs(rollRate) > p:spin and abs(rollRate) < p:spin * 1.2
        {
            set cmdroll to -0.1.
        }
        else
        {
            set cmdroll to -1.
        }
    }
    else
    {
        if abs(rollRate) < 0.01
            set cmdroll to choose -0.0001 if rollRate < 0 else 0.0001.
    }
    set ship:control:roll to cmdroll.
}

LAS_Avionics("activate").
CheckHeading().

rcs on.
lock steering to LookDirUp(dV:Normalized, Facing:UpVector).
local statText is "Aligning ship".

until burnETA <= ignitionTime
{
    RollControl().
    CheckHeading().

    local err is vang(dV:Normalized, Facing:Vector).
    local omega is  vxcl(Facing:Vector, Ship:AngularVel):Mag * 180 / Constant:Pi.
    set debugStat:Text to statText + ", <color=" + (choose "#ff8000" if err > 0.5 else "#00ff00") + ">Δθ: " + round(err, 2)
        + "°</color> <color=" + (choose "#ff8000" if err / max(omega, 1e-4) > burnETA - ignitionTime else "#00ff00") + ">ω: " + round(omega, 3) + "°/s</color> roll: " + round(vdot(Facing:Vector, Ship:AngularVel), 6).

    // Pre-ullage
    if ignitionTime > 0 and burnETA <= ignitionTime + 8
    {
        if Ship:Control:Fore > 0
        {
            if mainEng:FuelStability >= 0.99
                set Ship:Control:Fore to 0.
        }
        else
        {
            if mainEng:FuelStability < 0.98  
                set Ship:Control:Fore to 1.
        }
        set statText to "Ullage".
    }
    wait 0.
}

print "Starting burn T-" + round(ignitionTime, 2).

// If we have engines, ignite them.
if p:eng > 0
    runpath("flight/ExecuteBurnEng", p, debugStat, dV).
else
    runpath("flight/ExecuteBurnRCS", p, debugStat).
ClearGuis().
