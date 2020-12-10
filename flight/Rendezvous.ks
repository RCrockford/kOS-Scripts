// Ship to ship rendezvous
@lazyglobal off.

parameter minDist is 50.
parameter tShip is target.

// Wait for unpack
wait until Ship:Unpacked.

local debugGui is GUI(300, 80).
set debugGui:X to 800.
set debugGui:Y to debugGui:Y - 180.
local mainBox is debugGui:AddVBox().
local debugStat1 is mainBox:AddLabel("").
local debugStat2 is mainBox:AddLabel("").
local debugStat3 is mainBox:AddLabel("").
debugGui:Show().

switch to scriptpath():volume.

runoncepath("/FCFuncs").
runpath("/flight/TuneSteering").

local forePID is pidloop(2, 0, 0.5, 0, 1).
local starPID is pidloop(5, 0.2, 1, -1, 1).
local topPID is pidloop(5, 0.2, 1, -1, 1).

local lock phaseAngle to 0.//arccos(vdot((tShip:Position - Body:Position):Normalized, -Body:Position:Normalized)).
local lock oNorm to vcrs(Velocity:Orbit, -Body:Position):Normalized.
local lock orbitNormal to oNorm * (choose 1 if vdot(oNorm, vcrs((tShip:Position - Body:Position):Normalized, -Body:Position:Normalized)) > 0 else -1).

local lock relV to (tShip:Velocity:Orbit * angleaxis(phaseAngle, orbitNormal) - Ship:Velocity:Orbit).
local lock targetPos to choose tShip:Position if tShip:Unpacked else tShip:Position - tShip:Velocity:Orbit * 0.02.
local lock targetDir to targetPos:Normalized * angleaxis(phaseAngle, orbitNormal).

local function updateStat1
{
	set debugStat1:Text to "d=" + round(targetPos:Mag, 1) + " v=" + round(relV:Mag, 2) + " f=" + round(arccos(max(-1, min(1, vdot(-relV:Normalized, targetDir)))), 1).
}

if targetPos:Mag <= 1000 and (vdot(-relV, targetDir) < 0 or (vdot(-relV, targetDir) < 1 and targetPos:Mag > minDist * 2))
{
    set debugStat2:Text to "Boosting for intercept".

    LAS_Avionics("activate").
    rcs on.
    
    local lock aimDir to targetDir * -2.
    lock steering to lookdirup((relV - aimDir):Normalized, Facing:UpVector).

    wait until vdot(Facing:Vector, (relV - aimDir):Normalized) > 0.999.
    
    set ship:control:fore to 1.

    until vdot(-relV, targetDir) > 2 or (vdot(-relV, targetDir)> 0.5 and targetPos:Mag <= minDist * 2)
    {
        wait 0.
        updateStat1().
    }
    set ship:control:fore to 0.
}

LAS_Avionics("shutdown").
rcs off.

set debugStat2:Text to "Coasting to intercept".
until targetPos:Mag <= max(5000, relV:Mag * 100)
{
	updateStat1().
    wait 0.05.
}
kUniverse:Timewarp:CancelWarp().

// check for engine braking
runoncepath("/flight/FlightFuncs").
runoncepath("/flight/RCSPerf.ks").
local burnDur is CalcBurnDuration(relV:Mag, true):duration.
local RCSPerf is GetRCSForePerf().

local lock interceptTime to (targetPos:Mag - minDist) / -vdot(relV, targetDir).
local lock massRatio to constant:e ^ (relV:Mag * RCSPerf:massflow / RCSPerf:Thrust).
local lock finalMass to Ship:Mass / massRatio.
local lock brakeTime to (Ship:Mass - finalMass) / RCSPerf:massflow.

runpath("/flight/AlignTime").
local alignMargin is GetAlignTime().

local activeEngines is EM_GetEngines().
if activeEngines:Length > 0
{
    print "It: " + round(interceptTime, 1) + " Burn: " + round(burnDur, 2) + " RCS: " + round(brakeTime, 1).

    if burnDur >= 2 or (brakeTime >= 60 and burnDur >= 0.5)
    {
        local interceptSpeed is -4.
        local lock aimDir to targetDir * interceptSpeed.
        lock steering to lookdirup((relV - aimDir):Normalized, Facing:UpVector).
        
        set debugStat2:Text to "Coasting to ignition".
        local lastItTime is interceptTime + 1.
        until rcs and (interceptTime <= EM_IgDelay() + burnDur + 5 or interceptTime > lastItTime) and vdot(Facing:Vector, (relV - aimDir):Normalized) > 0.5
        {
            if not rcs and interceptTime < EM_IgDelay() + burnDur + alignMargin
            {
                rcs on.
                LAS_Avionics("activate").
            }
            updateStat1().
            set debugStat3:Text to "bt=" + round(burnDur, 1) + " it=" + round(interceptTime, 2) + " am=" + round(alignMargin, 1).
            set lastItTime to interceptTime.
            wait 0.05.
        }

        print "Ignition bt=" + round(burnDur, 1) + " it=" + round(interceptTime, 2) + " / " + round(lastItTime, 2).

        set debugStat2:Text to "Ignition".
        EM_Ignition().
        
        set debugStat2:Text to "Engine braking".
        until (relV - aimDir):Mag < 0.5 and (brakeTime + alignMargin) < interceptTime
        {
            // Target velocity should be less than the velocity that can be stopped in intercept time, so set bt=it and invert the rocket equation
            local targetFinalMass is Ship:Mass - interceptTime * RCSPerf:MassFlow.
            local targetMassRatio is Ship:Mass / finalMass.
            set interceptSpeed to -max(1, min(ln(targetMassRatio) * RCSPerf:Thrust / RCSPerf:MassFlow, 8)).
        
            updateStat1().
            set debugStat3:Text to "m=" + round((relV - aimDir):Mag, 1) + " rcs_bt=" + round(brakeTime, 1) + " spd=" + round(interceptSpeed, 1).
            wait 0.
        }
        
        EM_Shutdown().
    }
}

lock steering to lookdirup(-relV:Normalized, Facing:UpVector).

// RCS braking
until targetPos:Mag <= minDist and relV:Mag < 0.5
{
	updateStat1().
	
	set debugStat3:Text to "bt=" + round(brakeTime, 1) + " it=" + round(interceptTime, 1).
    
    if not rcs and targetPos:Mag < 2500
    {
        rcs on.
        LAS_Avionics("activate").
    }
    
    if rcs and vdot(-relV:Normalized, Facing:Vector) > 0.999
    {
        local correct is relV:Normalized - targetDir.
        set ship:control:starboard to starPID:Update(Time:Seconds, vdot(correct, Facing:StarVector)).
        set ship:control:top to topPID:Update(Time:Seconds, vdot(correct, Facing:TopVector)).
        
        set ship:control:fore to -forePID:Update(Time:Seconds, interceptTime - brakeTime).
    }
    else
    {
        set ship:control:fore to 0.
        set ship:control:starboard to 0.
        set ship:control:top to 0.
    }

    if ship:control:fore < -0.1
        set debugStat2:Text to "RCS Braking".
    else if abs(ship:control:starboard) >= 0.05 or abs(ship:control:top) >= 0.05
        set debugStat2:Text to "Correcting course".
    else
        set debugStat2:Text to "Coasting (RCS)".

	wait 0.
}

rcs on.
LAS_Avionics("activate").
lock steering to "kill".

set debugStat2:Text to "Stopping".
until relV:Mag <= 0.02
{
    set ship:control:starboard to -starPID:Update(Time:Seconds, vdot(relV, Facing:StarVector) * 2).
    set ship:control:top to -topPID:Update(Time:Seconds, vdot(relV, Facing:TopVector) * 2).
    set ship:control:fore to -forePID:Update(Time:Seconds, vdot(relV, Facing:Vector) * 2).

    UpdateStat1().
    wait 0.
}
set debugStat2:Text to "Settling".

set ship:control:fore to 0.
set ship:control:starboard to 0.
set ship:control:top to 0.

wait until Ship:AngularVel:Mag < 1e-3.

unlock steering.
set Ship:Control:Neutralize to true.
rcs off.
LAS_Avionics("shutdown").

clearguis().