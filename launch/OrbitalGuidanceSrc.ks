// Orbital guidance system
// Based on: EXPLICIT GUIDANCE EQUATIONS FOR MULTISTAGE BOOST TRAJECTORIES By Fred Teren
// Valid for an unlimited number of stages (tested with 3 stages).

@lazyglobal off.

//------------------------------------------------------------------------------------------------

local rT is 0.      // Target radial distance
local rvT is 0.     // Target radial velocity
local hT is 0.      // Target angular momentum
local omegaT is 0.  // Target angular speed
local ET is 0.      // Target orbital energy

local stageA is list().         // Steering constant
local stageB is list().         // Steering constant (/sec)
local stageT is list().         // Burn time estimate
local stageOmegaT is list().    // Angular speed at T

local stageExhaustV is list().
local stageAccel is list().
local GuidanceLastStage is -1.
local ConvergeStage is -1.

local tStart is 0.   // Time since last guidance update

local orbitalEnergy is 0.   // Current orbital energy

//------------------------------------------------------------------------------------------------
// Configure guidance

{
    // Default to standard parking orbit.
    local targetPe is 180000.
    local targetAp is 180000.

    if defined LAS_TargetPe
        set targetPe to LAS_TargetPe.
    if defined LAS_TargetAp
        set targetAp to LAS_TargetAp.
    if defined LAS_LastStage
        set GuidanceLastStage to LAS_LastStage.
        
    if targetPe < 100000
    {
        print "Suborbital flight, no orbital guidance.".
    }
    else
    {
        print "Target Orbit: Pe=" + round(targetPe * 0.001, 1) + " km, Ap=" + round(targetAp * 0.001, 1) + " km".

        set targetPe to targetPe + Ship:Body:Radius.
        set targetAp to targetAp + Ship:Body:Radius.

        local a is (targetAp + targetPe) / 2.
        local e is 1 - targetPe / a.
        local L is a * (1 - e * e).

        // Configure target orbital parameters
        set rT to targetPe.
        set rvT to 0.
        set hT to sqrt( Ship:Body:Mu * L ).
        set omegaT to hT / (targetPe * targetPe).
        set ET to -Ship:Body:Mu / (2 * a).

        local allEngines is list().
        list engines in allEngines.
        
        // Size lists
        from {local s is Stage:Number.} until s < 0 step {set s to s - 1.} do
        {
            stageA:add(0).
            stageB:add(0).
            stageT:add(0).
            stageOmegaT:add(0).
            stageExhaustV:add(0).
            stageAccel:add(0).
        }

        // Populate lists
        from {local s is Stage:Number.} until s < 0 step {set s to s - 1.} do
        {
            local decoupler is Ship:RootPart.

            // Sum mass flow for each engine
            local massFlow is 0.
            local stageIsp is 0.
            local engCount is 0.
            local burnTime is -1.
            for eng in allEngines
            {
                if eng:Stage = s and not eng:Title:Contains("Separation") and not eng:Tag:Contains("ullage")
                {
                    set massFlow to massFlow + eng:PossibleThrustAt(0) / (Constant:g0 * eng:VacuumIsp).
                    set stageIsp to stageIsp + eng:VacuumIsp.
                    set engCount to engCount + 1.
                    set burnTime to max(burnTime, LAS_GetEngineBurnTime(eng)).
                    
                    set decoupler to eng:Decoupler.
                }
            }
            
            if not decoupler:IsType("Decoupler")
                set decoupler to Ship:RootPart.
              
            local stageWetMass is 0.
            local stageDryMass is 0.
            
            for shipPart in Ship:Parts
            {
                if not shipPart:HasModule("LaunchClamp")
                {            
                    if shipPart:DecoupledIn < s and shipPart:DecoupledIn >= decoupler:stage
                    {
                        set stageWetMass to stageWetMass + shipPart:WetMass.
                        set stageDryMass to stageDryMass + shipPart:DryMass.
                    }
                    else if shipPart:DecoupledIn < decoupler:stage
                    {
                        set stageWetMass to stageWetMass + shipPart:WetMass.
                        set stageDryMass to stageDryMass + shipPart:WetMass.
                    }
                }
            }
            
            if stageIsp > 0 and massFlow > 0
            {
                set stageIsp to stageIsp / max(engCount, 1).

                if burnTime > 0
                {
                    set stageT[s] to burnTime.
                }
                else
                {
                    // Calc burn time for stage
                    set stageT[s] to (stageWetMass - stageDryMass) / massFlow.
                }
                
                // Initial effective exhaust velocity and acceleration
                set stageExhaustV[s] to Constant:g0 * stageIsp.
                set stageAccel[s] to massFlow * Constant:g0 * stageIsp / max(stageWetMass, 1e-6).

                print "Guidance for stage " + s + ": T=" + round(stageT[s], 2) + " Ev=" + round(stageExhaustV[s], 1) + " a=" + round(stageAccel[s], 2).
            }
        }
    }
}

//------------------------------------------------------------------------------------------------

local function UpdateGuidance
{
    // Clamp s incase we run off the end (just keep running final stage guidance).
    local s is max(Stage:Number, GuidanceLastStage).
    // Don't update during final few seconds of stage as divergence will cause issues.
    if stageT[s] < 10
    {
        return.
    }
    
    // Calc reference frame
    local r is LAS_ShipPos():Mag.
    local r2 is LAS_ShipPos():SqrMagnitude.
    local rv is vdot(Ship:Velocity:Orbit, LAS_ShipPos():Normalized).
    local h is vcrs(LAS_ShipPos(), Ship:Velocity:Orbit):Mag.
    local hVec is vcrs(LAS_ShipPos(), Ship:Velocity:Orbit):Normalized.
    local omega is h / r2.
    local deltaT is MissionTime - tStart.
    
    // Calculate current peformance
    local StageEngines is LAS_GetStageEngines().
    local currentIsp is 0.
    local currentThrust is 0.
    local ratedThrust is 0.
    local engCount is 0.
    for eng in StageEngines
    {
        if eng:Thrust > 0 and not eng:Title:Contains("Separation") and not eng:Tag:Contains("ullage")
        {
            set currentIsp to currentIsp + eng:Isp.
            set currentThrust to currentThrust + eng:Thrust.
            set ratedThrust to ratedThrust + eng:PossibleThrust.
            set engCount to engCount + 1.
        }
    }
    
    // Engines off? No guidance.
    if engCount < 1 or currentThrust < ratedThrust * 0.4 or currentIsp < 1e-4
    {
        return.
    }
    
    set currentIsp to currentIsp / engCount.
    
    // Setup current stage
    local exhaustV is Constant:g0 * currentIsp.
    local accel is currentThrust / Ship:Mass.
    local tau is exhaustV / accel.

    local lastStage is max(ConvergeStage, GuidanceLastStage + 1).
    
    until s < lastStage
    {
        // determine next stage (skip anything with no engines)
        local nextStage is s-1.
        until stageExhaustV[nextStage] > 0
            set nextStage to nextStage-1.
    
        // Inter stage guidance
        set stageA[s] to stageA[s] + stageB[s] * deltaT.
        set stageT[s] to max(stageT[s] - deltaT, 1).
        local T is min(stageT[s], tau - 1).

        local accelS is accel / (1 - T / tau).
        
        // Current flight integrals
        local b0 is -exhaustV * ln(1 - T / tau). // delta V
        local b1 is b0 * tau - exhaustV * T.
        local c0 is b0 * T - b1.
        local c1 is c0 * tau - exhaustV * (T*T) * 0.5.
        
        // State at staging
        local rS is r + rv * T + c0 * stageA[s] + c1 * stageB[s].
        local rvS is rv + b0 * stageA[s] + b1 * stageB[s].
        local omegaS is stageOmegaT[s].
        
        // Heading derivatives
        local fr is stageA[s] + (Ship:Body:Mu / r2 - (omega * omega) * r) / accel.
        local frS is stageA[s] + stageB[s] * T + (Ship:Body:Mu / (rS * rS) - (omegaS * omegaS) * rS) / accelS.
        local fdr is (frS - fr) / T.
        
        local ftheta is 1 - (fr*fr) * 0.5. // - (fh * fh) * 0.5.
        local fdtheta is -(fr * fdr).// + fh * fdh).
        local fddtheta is -0.5 * ((fdr * fdr)). // + (fdh * fdh)).
        
        // Angular momentum gain at staging
        local b2 is b1 * tau - exhaustV * (T * T) * 0.5.
        local hS is h + (r + rS) * 0.5 * (ftheta * b0 + fdtheta * b1 + fddtheta * b2).

        // Tangental and angular speed at staging
        set omegaS to hS / (rS * rS).
        set stageOmegaT[s] to omegaS.  // feedback to next update
        
        // guidance discontinuities at staging.
        local x is Ship:Body:Mu / (rS * rS) - (omegaS * omegaS) * rS.
        local y is 1 / accelS - 1 / stageAccel[nextStage].
        local deltaA is x * y.
        local deltaB is -x * (1 / exhaustV - 1 / stageExhaustV[nextStage]) + (3 * (omegaS * omegaS) - 2 * Ship:Body:Mu / (rS ^ 3)) * rvS * y.
        
        // Next stage flight integrals
        set exhaustV to stageExhaustV[nextStage].
        set accel to stageAccel[nextStage].
        set tau to exhaustV / accel.
        local T2 is min(stageT[nextStage], tau - 1).
        set accelS to accel / (1 - T2 / tau).

        local nb0 is -exhaustV * ln(1 - T2 / tau). // delta V
        local nb1 is nb0 * tau - exhaustV * T2.
        local nc0 is nb0 * T2 - nb1.
        local nc1 is nc0 * tau - exhaustV * (T2*T2) * 0.5.

        // Final state of next stage
        local rS2 is rT.
        local rvS2 is rvT.
        if nextStage > GuidanceLastStage
        {
            set rS2 to rS + rvS * T2 + nc0 * stageA[nextStage] + nc1 * stageB[nextStage].
            set rvS2 to rvS + nb0 * stageA[nextStage] + nb1 * stageB[nextStage].
        }
        
        // Update guidance for current stage
        local M00 is b0 + nb0.
        local M01 is b1 + nb1 + nb0 * T.
        local M10 is c0 + nc0 + b0 * T2.
        local M11 is c1 + b1 * T2 + nc0 * T + nc1.

        local Mx is rvS2 - rv - nb0 * deltaA - nb1 * deltaB.
        local My is rS2 - r - rv * (T + T2) - nc0 * deltaA - nc1 * deltaB.
        
        local det is M00 * M11 - M01 * M10.
        if (abs(det) > 1e-7)
        {
            set stageA[s] to (M11 * Mx - M01 * My) / det.
            set stageB[s] to (M00 * My - M10 * Mx) / det.
        }
        
        // Update next stage guidance using staging state at start
        set stageA[nextStage] to deltaA + stageA[s]+ stageB[s] * T.
        set stageB[nextStage] to deltaB + stageB[s].
        
        // Loop to next stage
        set s to nextStage.
        
        // Next stage reference frame
        set r to rS.
        set r2 to rS * rS.
        set rv to rvS.
        set h to hS.
        set omega to omegaS.
        set deltaT to 0.
    }
    
    if s = GuidanceLastStage
    {
        // Final stage guidance
        set stageA[s] to stageA[s] + stageB[s] * deltaT.
        set stageT[s] to stageT[s] - deltaT.
        local T is min(stageT[s], tau - 1).

        local accelT is accel / (1 - T / tau).
        
        // Heading derivatives
        local fr is stageA[s] + (Ship:Body:Mu / r2 - (omega * omega) * r) / accel.
        local frT is stageA[s] + stageB[s] * T + (Ship:Body:Mu / (rT * rT) - (omegaT * omegaT) * rT) / accelT.
        local fdr is (frT - fr) / T.

        local ftheta is 1 - (fr*fr) * 0.5. // - (fh * fh) * 0.5.
        local fdtheta is -(fr * fdr).// + fh * fdh).
        local fddtheta is -0.5 * ((fdr * fdr)). // + (fdh * fdh)).

        // Calculate required delta V
        local dh is hT - h.
        local meanRadius is (r + rT) * 0.5.
        
        local deltaV is dh / meanRadius.
        set deltaV to deltaV + exhaustV * T * (fdtheta + fddtheta * tau).
        set deltaV to deltaV + fddtheta * exhaustV * (T*T) * 0.5.
        set deltaV to deltaV / (ftheta + (fdtheta + fddtheta * tau) * tau).
        
        // Calculate new estimate for T
        set T to tau * (1 - constant:e ^ (-deltaV / exhaustV)).
        set stageT[s] to T.
        
        // Update A, B with new T estimate
        local b0 is deltaV.
        local b1 is b0 * tau - exhaustV * T.
        local c0 is b0 * T - b1.
        local c1 is c0 * tau - exhaustV * (T*T) * 0.5.
        
        local Mx is rvT - rv.
        local My is rT - r - rv * T.
        
        local det is b0 * c1 - b1 * c0.
        if (abs(det) > 1e-7)
        {
            set stageA[s] to (c1 * Mx - b1 * My) / det.
            set stageB[s] to (b0 * My - c0 * Mx) / det.
        }

        set tStart to MissionTime.
    }
}

//------------------------------------------------------------------------------------------------

global function LAS_GetGuidanceAim
{
    if rT <= 0
        return V(0,0,0).
    
    local s is Stage:Number.
    local t is MissionTime - tStart.

    local r is LAS_ShipPos():Mag.
    local r2 is LAS_ShipPos():SqrMagnitude.
    local downtrack is vcrs(vcrs(LAS_ShipPos(), Ship:Velocity:Orbit):Normalized, LAS_ShipPos():Normalized).
    local omega is vdot(Ship:Velocity:Orbit, downtrack) / r.
    
    // Calculate current peformance
    local StageEngines is LAS_GetStageEngines().
    local currentThrust is 0.
    for eng in StageEngines
    {
        if eng:Thrust > 0 and not eng:Title:Contains("Separation") and not eng:Tag:Contains("ullage")
        {
            set currentThrust to currentThrust + eng:Thrust.
        }
    }
    local accel is currentThrust / Ship:Mass.
    
    // Engines off? No guidance.
    if currentThrust > 1e-3
    {
        // Calculate radial heading vector
        local fr is stageA[s] + stageB[s] * t.
        // Add gravity and centifugal force term.
        set fr to fr + (Ship:Body:Mu / r2 - (omega * omega) * r) / accel.

        // Construct aim vector
        if abs(fr) < 0.999
        {
            return fr * LAS_ShipPos():Normalized + sqrt(1 - fr * fr) * downtrack.
        }
    }

    return V(0,0,0).
}

//------------------------------------------------------------------------------------------------
// Call just before starting guidance updates

global function LAS_StartGuidance
{
    if rT <= 0
        return.
        
    // Update estimate for T for active stage
    set stageT[Stage:Number] to LAS_GetStageBurnTime().
    
    // Setup initial orbital energy
    set orbitalEnergy to Ship:Velocity:Orbit:sqrMagnitude / 2 - Ship:Body:Mu / LAS_ShipPos():Mag.
    
    // Auto calculate final guidance stage
    if GuidanceLastStage < 0
    {
        local r is LAS_ShipPos():Mag.
        local h is vcrs(LAS_ShipPos(), Ship:Velocity:Orbit):Mag.
    
        local deltaVReq is (hT - h) * 2.2 / (rT + r).   // This gives a fairly reasonable guess at the required deltaV.
        local deltaV is 0.
        from {local i is Stage:Number.} until i < 0 step {set i to i - 1.} do
        {
            if stageExhaustV[i] > 0
            {
                set deltaV to deltaV - stageExhaustV[i] * ln(1 - stageT[i] * stageAccel[i] / stageExhaustV[i]).
                set GuidanceLastStage to i.
                if deltaV >= deltaVReq
                    break.
            }
        }
        
        print "Last guidance stage: " + GuidanceLastStage.
    }
    
    // Converge guidance    
    set ConvergeStage to Stage:Number.

    local count is 0.
    until ConvergeStage < GuidanceLastStage
    {
        local A is stageA[ConvergeStage].
        set tStart to MissionTime.
        
        UpdateGuidance().
        
        if abs(stageA[ConvergeStage] - A) < 0.01
            set ConvergeStage to ConvergeStage - 1.
            
        set count to count + 1.
        if count > 30
            break.
    }
    
    if ConvergeStage < GuidanceLastStage
        print "Guidance converged successfully.".
    else
        print "Guidance failed to converge.".
}

//------------------------------------------------------------------------------------------------

global function LAS_GuidanceUpdate
{
    if rT <= 0
        return.
        
    // Guidance updates once per second
    if MissionTime - tStart < 0.98
        return.
        
    UpdateGuidance().
}

//------------------------------------------------------------------------------------------------

global function LAS_GuidanceCutOff
{
    if rT <= 0
        return false.

    local prevE is orbitalEnergy.
    
    set orbitalEnergy to Ship:Velocity:Orbit:sqrMagnitude / 2 - Ship:Body:Mu / LAS_ShipPos():Mag.
    
    // Have we reached final orbital energy, or likely to reach it within half the next time step?
    return orbitalEnergy + (orbitalEnergy - prevE) * 0.5 >= ET.
}