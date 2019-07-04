// Orbital manoeuvres using Principia's flight planner

@lazyglobal off.

parameter burnParam.
parameter rcsBurn is false.
parameter spinKick is false.
parameter tangent is 0.
parameter normal is 0.
parameter binormal is 0.
parameter burnStart is 0.

// Wait for unpack
wait until Ship:Unpacked.

if not HasNode
{
    lock tVec to Ship:Prograde:Vector.
    lock bVec to vcrs(tVec, ship:up:vector):Normalized.
    lock nVec to vcrs(tVec, bVec):Normalized.
    lock dV to tangent * tVec + normal * nVec + binormal * bVec.
    set burnStart to time:Seconds + burnStart.
    lock burnEta to burnStart - time:Seconds.
}
else
{
    lock dV to NextNode:DeltaV.
    lock burnEta to NextNode:eta.
}
runoncepath("FCFuncs").

local duration is burnParam.
local burnStage is stage:Number.
local activeEngines is list().
local massRatio is 1.

local lock shipCtrl to Ship:Control.

if not rcsBurn
{
    if spinKick
        set burnStage to burnStage - 1.

    runpath("flight/EngineManagement", burnStage).
    set activeEngines to EM_GetManoeuvreEngines().
    if activeEngines:Length = 0
    {
        print "No active engines!".
    }
    else
    {
        local massFlow is 0.
        local burnThrust is 0.
        for eng in activeEngines
        {
            local possThrust is eng:PossibleThrustAt(0).
            set massFlow to massFlow + possThrust / (Constant:g0 * eng:VacuumIsp).
            set burnThrust to burnThrust + possThrust.
        }
        set massRatio to constant:e ^ (dV:Mag * massFlow / burnThrust).
        
        local shipMass is 0.
        for shipPart in Ship:Parts
        {
            if shipPart:IsType("Decoupler")
            {
                if shipPart:Stage < burnStage
                {
                    set shipMass to shipMass + shipPart:Mass.
                }
            }
            else if shipPart:DecoupledIn < burnStage
            {
                set shipMass to shipMass + shipPart:Mass.
            }
        }
        
        local finalMass is shipMass / massRatio.
        set duration to (shipMass - finalMass) / massFlow.
    }
}

print "Executing manoeuvre in " + round(burnEta, 1) + " seconds.".
print "  DeltaV: " + round(dV:Mag, 1) + " m/s.".
print "  Duration: " + round(duration,1) + " s.".
if rcsBurn
{
    print "  RCS burn.".
    set spinKick to false.
}
if spinKick
{
    print "  Inertial burn.".
}
    
if burnEta > 120 and Addons:Available("KAC")
{
    // Add a KAC alarm.
    AddAlarm("Raw", burnEta - 90 + Time:Seconds, Ship:Name + " Manoeuvre", Ship:Name + " is nearing its next manoeuvre").
}

print "Waiting for manoeuvre".

wait until burnEta < 60.

print "Aligning ship.".

local ignitionTime is 0.
if not rcsBurn
{
    set ignitionTime to EM_GetIgnitionDelay().
}

rcs on.
lock steering to dV:Normalized.

if spinKick
{
    // spin up
    set shipCtrl:Roll to -1.
    until burnEta <= ignitionTime
    {
        local rollRate is vdot(Ship:Facing:Vector, Ship:AngularVel).
        if abs(rollRate) > burnParam * 1.25
        {
            set shipCtrl:Roll to 0.1.
        }
        else if abs(rollRate) > burnParam and abs(rollRate) < burnParam * 1.2
        {
            set shipCtrl:Roll to -0.1.
        }

        wait 0.
    }
    
    set shipCtrl:Roll to -0.1.
}
else
{
    wait until burnEta <= ignitionTime.
}

// If we have engines, prep them to ignite.
if not activeEngines:empty
{
    EM_IgniteManoeuvreEngines().
    
    print "Starting engine burn.".

    // If this is a spun kick stage, then decouple it.
    if spinKick and Stage:Ready
    {
        unlock steering.
        set shipCtrl:Neutralize to true.
        rcs off.
        stage.
    }
}
else
{
    // Otherwise assume this is an RCS burn
    print "Starting RCS burn.".
    set shipCtrl:Fore to 1.
}

if rcsBurn
{
    wait duration.
}
else
{
    local finalMass is ship:Mass / massRatio.
    wait until Ship:Mass <= finalMass.
}

// Cutoff engines
set shipCtrlMainThrottle to 0.
for eng in activeEngines
{
    eng:Shutdown().
}
if not activeEngines:empty
    print "MECO".

unlock steering.
set shipCtrl:Neutralize to true.
rcs off.
