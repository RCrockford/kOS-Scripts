// Ship to ship rendezvous
@lazyglobal off.

parameter minDist is 100.
parameter tShip is target.
parameter allowEng is false.

// Wait for unpack
wait until Ship:Unpacked.

switch to scriptpath():volume.

runpath("/rdvz/rdvzfuncs").

local lock targetPos to tShip:Position.
local lock headingVec to tShip:Position.
local relV is V(0,0,0).

LAS_Avionics("shutdown").
rcs off.

Rdvz_SetStatus("Coasting").
set relV to Rdvz_UpdateReadouts(targetPos@).

print "Target Distance: " + round(targetPos:Mag / 1000, 2) + " km".
until targetPos:Mag <= 5000 and relV:Mag > 0.001
{
    wait 0.05.
	set relV to Rdvz_UpdateReadouts(targetPos@).
}
kUniverse:Timewarp:CancelWarp().

runoncepath("/flight/flightfuncs").
runoncepath("/flight/rcsperf.ks").
local RCSPerf is GetRCSAftPerf().

if allowEng
{
    // check for engine braking
    local burnDur is CalcBurnDuration(relV:Mag, true):duration.
    
    local lock interceptTime to (targetPos:Mag - minDist) / vdot(relV, targetPos:Normalized).
    local lock massRatio to constant:e ^ (relV:Mag * RCSPerf:massflow / RCSPerf:Thrust).
    local lock finalMass to Ship:Mass / massRatio.
    local lock brakeTime to (Ship:Mass - finalMass) / RCSPerf:massflow.

    runpath("/flight/aligntime").
    local alignMargin is GetAlignTime().

    local activeEngines is EM_GetEngines().

    print "Eng: " + activeEngines:Length + " r.h=" + round(vdot(relV, targetPos:Normalized), 3).
    if activeEngines:Length > 0 and vdot(relV, targetPos:Normalized) > 5 and targetPos:Mag > minDist
    {
        print "It: " + round(interceptTime, 1) + " Burn: " + round(burnDur, 2) + " RCS: " + round(brakeTime, 1).

        until burnDur < 2 and (brakeTime < 60 or burnDur < 0.5)
        {
            local interceptSpeed is 4 * rcsPerf:thrust / Ship:Mass.     // plan for a 4 second stop with RCS
            local lock correctVel to targetPos:Normalized * interceptSpeed - relV.
            lock steering to lookdirup(correctVel:Normalized, Facing:UpVector).
            
            local lastItTime is interceptTime + 1.
            until rcs and (interceptTime <= EM_IgDelay() + burnDur + 5 or interceptTime > lastItTime) and vang(Facing:Vector, correctVel) < 15
            {
                if not rcs and interceptTime < EM_IgDelay() + burnDur + alignMargin
                {
                    rcs on.
                    LAS_Avionics("activate").
                    kUniverse:Timewarp:CancelWarp().
                }
                set relV to Rdvz_UpdateReadouts(targetPos@, interceptSpeed).
                Rdvz_SetStatus("it=" + round(interceptTime, 2)).
                set lastItTime to interceptTime.
                wait 0.05.
            }

            print "Ignition bt=" + round(burnDur, 1) + " it=" + round(interceptTime, 2) + " / " + round(lastItTime, 2).

            Rdvz_SetStatus("Ignition").
            EM_Ignition().
            
            Rdvz_SetStatus("Burning").
            local prevCorrect is correctVel:Mag.
            local prevT is Time:Seconds.
            local curAccel is correctVel:Mag.
            
            until correctVel:Mag < curAccel * 0.1 or vang(correctVel, Facing:Vector) > 15
            {
                wait 0.
                set relV to Rdvz_UpdateReadouts(targetPos@, interceptSpeed).
                set curAccel to (correctVel:Mag - prevCorrect) / (Time:Seconds - prevT).
                set prevCorrect to correctVel:Mag.
                set prevT to Time:Seconds.
            }
            
            EM_Shutdown().
            
            set burnDur to CalcBurnDuration(relV:Mag, true):duration.
        }
    }
}

local function approachPos
{
    local tPos is targetPos.
    return tPos - tPos:Normalized * minDist * 0.98.
}

rcs on.
LAS_Avionics("activate").

if targetPos:Mag > minDist
{
    Rdvz_SetStatus("Approaching").
    Rdvz_TargetApproach(approachPos@, headingVec@, 2 * rcsPerf:thrust / Ship:Mass, max(relV:Mag, min(max(1, 16 * rcsPerf:thrust / Ship:Mass), 5)), minDist * 0.02).
}

Rdvz_SetStatus("Stopping").
Rdvz_TargetApproach(targetPos@, headingVec@, 0, 0, minDist).

Rdvz_SetStatus("Settling").
lock steering to "kill".

wait until Ship:AngularVel:Mag < 0.01.

unlock steering.
set Ship:Control:Neutralize to true.
rcs off.
LAS_Avionics("shutdown").

clearguis().
