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
local eccT is 0.    // Target eccentricty.
local LT is 0.      // Target semilatus rectum

local incT is -1.   // Target inclination
local aeroHeading is 90.
local oTarget is 0. // Target orbitable / direction

local stageA is list().         // Steering constant
local stageB is list().         // Steering constant (/sec)
local stageT is list().         // Burn time estimate
local stageTFull is list().     // Burn time estimate
local stageOmegaT is list().    // Angular speed at T

local guidanceValid is false.
local stageChange is false.
local yawK is 0.                // Yaw steering gain factor

local stageExhaustV is list().
local stageAccel is list().
local stageGuided is list().
local GuidanceLastStage is -1.

local tStart is 0.   // Time since last guidance update

local orbitalEnergy is 0.   // Current orbital energy

local debugGui is GUI(320).
set debugGui:X to -150.
set debugGui:Y to debugGui:Y - 320.
local mainBox is debugGui:AddVBox().

local debugStat is mainBox:AddLabel("Inactive").
local debugTarget is mainBox:AddLabel("").
local debugFr is mainBox:AddLabel("").
local debugStages is list().

//------------------------------------------------------------------------------------------------
// Configure guidance

{
    // Default to standard parking orbit.
    local targetPe is 180000.
    local targetAp is 180000.
    local targetSMA is 0.

    if defined LAS_TargetPe
        set targetPe to LAS_TargetPe * 1000.
	if defined LAS_TargetAp
        set targetAp to LAS_TargetAp * 1000.
    if defined LAS_LastStage
        set GuidanceLastStage to LAS_LastStage.

    if targetPe < 100000
    {
        print "Suborbital Flight: Ap=" + round(targetAp * 0.001, 1) + " km".

        set targetAp to targetAp + Ship:Body:Radius.

        // Configure target orbital parameters
        set rT to targetAp.
        set rvT to 0.
        set hT to 0.
    }
    else
    {
		local a is 0.
		if defined LAS_TargetSMA
		{
			if LAS_TargetSMA > 0
			{
				set targetAp to 2 * LAS_TargetSMA - targetPe - 2 * Ship:Body:Radius.
				print "Target Orbit: Pe=" + round(targetPe * 0.001, 1) + " km, Ap=" + round(targetAp * 0.001, 1) + " km".
			}
			else
			{
				print "Target Orbit: Pe=" + round(targetPe * 0.001, 1) + " km, hyperbolic, A=" + round(targetAp * 0.001, 1) + " km".
			}

			set targetPe to targetPe + Ship:Body:Radius.			
			set a to LAS_TargetSMA.
		}
		else
		{
			print "Target Orbit: Pe=" + round(targetPe * 0.001, 1) + " km, Ap=" + round(targetAp * 0.001, 1) + " km".

			set targetPe to targetPe + Ship:Body:Radius.
			set targetAp to targetAp + Ship:Body:Radius.

			set a to (targetAp + targetPe) / 2.
		}

        set eccT to 1 - targetPe / a.
        set LT to a * (1 - eccT * eccT).

        // Configure target orbital parameters
        set rT to targetPe.
        set rvT to 0.
        set hT to sqrt(Ship:Body:Mu * LT).
        set omegaT to hT / (targetPe * targetPe).
        set ET to -Ship:Body:Mu / (2 * a).
	}

	set debugTarget:Text to "rT = " + round((rT - Ship:Body:Radius) / 1000, 1) + " km, rvT = " + round(rvT, 1) + " m/s vTh=" + round(omegaT * rT, 1) + " m/s".
	
	//log "Stage,Alt,vTh,Lat,Anom,dAnom" to "0:/logs/lat.csv".

	// Size lists
	from {local s is Stage:Number - 1.} until s < 0 step {set s to s - 1.} do
	{
		stageA:add(0).
		stageB:add(0).
		stageT:add(0).
		stageTFull:Add(0).
		stageOmegaT:add(0).
		stageExhaustV:add(0).
		stageAccel:add(0).
		stageGuided:add(false).
		debugStages:Insert(0, mainBox:AddLabel("")).
	}

	// Populate lists
	from {local s is Stage:Number - 1.} until s < 0 step {set s to s - 1.} do
	{
		local stagePerf is LAS_GetStagePerformance(s).
	
		set stageT[s] to stagePerf:BurnTime.
		set stageTFull[s] to stagePerf:BurnTime.
		set stageExhaustV[s] to stagePerf:eV.
		set stageAccel[s] to stagePerf:Accel.
		set stageGuided[s] to stagePerf:Guided.
		
		// If engine was lit in the previous stage, only use sustainer time
		if stagePerf:litPrevStage
			set stageT[s] to stageT[s] - stageT[s+1].
			
		set stageTFull[s] to stageT[s].
		
		set debugStages[s]:Text to "S" + s + ": Ev=" + round(stageExhaustV[s], 1) + " a=" + round(stageAccel[s], 2) + " T=" + round(stageT[s], 1) + " G=" + stageGuided[s].
	}

	debugGui:Show().
}

//------------------------------------------------------------------------------------------------

local function UpdateTarget
{
    parameter deltaAnom.

    // Update estimate for required true anomaly
    local trueAnom is Ship:Orbit:TrueAnomaly.
    local trueAnomM is oTarget:Orbit:TrueAnomaly.

    local trueAnomT is trueAnomM + deltaAnom - trueAnom.
	
	local newRT is LT / (1 + eccT * cos(trueAnomT)).
	local newrvT is sqrt(Ship:Body:Mu / LT) * eccT * sin(trueAnomT).

    //set rT to LT / (1 + eccT * cos(trueAnomT)).
    //set rvT to sqrt(Ship:Body:Mu / LT) * eccT * sin(trueAnomT).

    set debugTarget:Text to "rT = " + round((newRT - Ship:Body:Radius) / 1000, 1) + " km, rvT = " + round(newrvT, 1) + " m/s".
}

//------------------------------------------------------------------------------------------------

local function UpdateGuidance
{
	parameter startStage.
	
    // Clamp s incase we run off the end (just keep running final stage guidance).
    local s is max(startStage, GuidanceLastStage).

    // Don't update during final few seconds of stage as divergence will cause issues.
    if stageT[s] < 10
    {
        set debugStat:Text to "T < 10 for s=" + s.
        kUniverse:TimeWarp:CancelWarp().
		set stageChange to true.
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

    // Calculate current performance
    local currentMassFlow is 0.
    local currentThrust is 0.
    local ratedThrust is 0.
    local engCount is 0.

	if startStage <> Stage:Number
	{
		set currentThrust to stageAccel[startStage] * Ship:Mass.
		set ratedThrust to currentThrust.
		set currentMassFlow to ratedThrust / stageExhaustV[startStage].
		set engCount to 1.
	}
	else
	{
		local StageEngines is LAS_GetStageEngines().
		for eng in StageEngines
		{
			if eng:Thrust > 0
			{
				set currentMassFlow to currentMassFlow + eng:MassFlow.
				set currentThrust to currentThrust + eng:Thrust.
				set ratedThrust to ratedThrust + eng:PossibleThrust.
				set engCount to engCount + 1.
			}
		}
		
		local thrustReq is 0.4.
		if stageChange
			set thrustReq to 0.98.

		// Engines off? No guidance.
		if engCount < 1 or currentThrust < ratedThrust * thrustReq or currentMassFlow <= 0
		{
			set debugStat:Text to "No Thrust: eng=" + engCount + " Thr=" + round(100 * currentThrust / max(ratedThrust, 0.001), 1) + "% Isp=" + round(currentThrust / (max(currentMassFlow, 1e-6) * Constant:g0), 1) + " vTh=" + round(omega * r, 1).
			set guidanceValid to false.
			return.
		}

		set stageChange to false.
	}

    // Setup current stage
    local exhaustV is currentThrust / currentMassFlow.
    local accel is currentThrust / Ship:Mass.
    local tau is exhaustV / accel.

    set debugStat:Text to "Nominal: Thr=" + round(100 * currentThrust / ratedThrust, 1) + "% Isp=" + round(exhaustV / constant:g0, 1) + " vTh=" + round(omega * r, 1).

    local lastStage is GuidanceLastStage + 1.

	// Update estimate for T for active stage
	if (startStage = Stage:Number and s > GuidanceLastStage) or hT <= 0
	{
		set stageT[s] to LAS_GetStageBurnTime() + deltaT.
	}

	if hT <= 0
	{
		set s to GuidanceLastStage.
	}

    local b0 is 0.
    local b1 is 0.
    local b2 is 0.

    local ftheta is 0.
    local fdtheta is 0.
    local fddtheta is 0.

    local newYawK is 0.
    local deltaAnom is 0.

    local function calcHeadingDerivs
    {
        parameter rS.
        parameter omegaS.
        parameter accelS.
        parameter T.

        // Heading derivatives
        local fr is stageA[s] + (Ship:Body:Mu / r2 - (omega * omega) * r) / accel.
        local frS is stageA[s] + stageB[s] * T + (Ship:Body:Mu / (rS * rS) - (omegaS * omegaS) * rS) / accelS.
        local fdr is (frS - fr) / T.

        local fh is 0.
        local fdh is 0.

        if incT >= 0 or oTarget:IsType("Orbitable") or oTarget:IsType("Vector")
        {
            local hdot is 0.
            local d is 1.

            // Assume downtrack isn't changing much
            local downtrack is vcrs(hVec, LAS_ShipPos():Normalized).

            if oTarget:IsType("Orbitable")
            {
                set hdot to vdot(hVec, oTarget:Position:Normalized).
                set d to vdot(downtrack:Normalized, oTarget:Position:Normalized).
            }
            else
            {
                local incDiff is Ship:Orbit:Inclination - incT.
                set hdot to -sin(incDiff).
                set d to cos(incDiff).
            }

			local vtheta is omega * r.
			local vthetaT is omegaT * rT.

            local allT is T.
            from {local i is s - 1.} until i < GuidanceLastStage step {set i to i - 1.} do
            {
                set allT to allT + stageT[i].
            }

            local d1 is d / vtheta.
            local d2 is (d / vthetaT - d1) / allT.

            if yawK = 0
                set yawK to (d1*d1*b0 + 2*d1*d2*b1 + d2*d2*b2).

			if vtheta < 4500
			{
				set fh to -sqrt(1 - vdot(vcrs(LAS_ShipPos():Normalized, Heading(aeroHeading, 0):Vector), hVec)^2).
			}
			else
			{
				set fh to hdot * d1 / yawK.
			}
			set fdh to fh * d2 / d1.
			
			//set debugStat:Text to "hdot=" + round(hdot, 4) + " d=" + round(d, 4) + " fh=" + round(hdot * d1 / yawK, 4).

            if s = startStage
            {
                set newYawK to newYawK + (d1*d1*b0 + 2*d1*d2*b1 + d2*d2*b2).
            }
        }

        set ftheta to 1 - ((fr * fr) - (fh * fh)) * 0.5.
        set fdtheta to -(fr * fdr + fh * fdh).
        set fddtheta to -0.5 * (fdr * fdr + fdh * fdh).
    }

    until s < lastStage
    {
        // determine next stage (skip anything with no engines)
        local nextStage is s-1.
        until stageExhaustV[nextStage] > 0
            set nextStage to nextStage-1.

        local nextStageKick is (nextStage = GuidanceLastStage) and not stageGuided[nextStage].

        // Inter stage guidance
        set stageA[s] to stageA[s] + stageB[s] * deltaT.
        set stageT[s] to max(stageT[s] - deltaT, 1).
        local T is max(min(stageT[s], tau - 1), 1).

        local accelS is accel / (1 - T / tau).

        // Current flight integrals
        set b0 to -exhaustV * ln(1 - T / tau). // delta V
        set b1 to b0 * tau - exhaustV * T.
        set b2 to b1 * tau - exhaustV * (T * T) * 0.5.
        local c0 is b0 * T - b1.
        local c1 is c0 * tau - exhaustV * (T*T) * 0.5.

        // State at staging
        local rS is r + rv * T + c0 * stageA[s] + c1 * stageB[s].
        local rvS is rv + b0 * stageA[s] + b1 * stageB[s].
        local omegaS is max(stageOmegaT[s], omega).

        // Heading derivatives
        calcHeadingDerivs(rS, omegaS, accelS, T).

        // Angular momentum gain at staging
        local hS is h + (r + rS) * 0.5 * (ftheta * b0 + fdtheta * b1 + fddtheta * b2).

        if oTarget:IsType("Orbitable")
        {
            // calc delta anom
            local c2 is c1 * tau - exhaustV * T^3 / 6.
            local d3 is h * rv / r^3.
            local d4 is (hS * rvS / rS^3 - d3) / T.

            local dA is T * h / (r*r)
                + (ftheta * c0 + fdtheta * c1 + fddtheta * c2) / ((r + rS) * 0.5)
                - d3 * T*T - d4 * T^3 / 3.
            set deltaAnom to deltaAnom + dA.
        }

        // Tangental and angular speed at staging
        set omegaS to hS / (rS * rS).
        set stageOmegaT[s] to omegaS.  // feedback to next update

        // guidance discontinuities at staging.
        local x is Ship:Body:Mu / (rS * rS) - (omegaS * omegaS) * rS.
        local y is 1 / accelS - 1 / stageAccel[nextStage].
        local deltaA is x * y.
        local deltaB is -x * (1 / exhaustV - 1 / stageExhaustV[nextStage]) + (3 * (omegaS * omegaS) - 2 * Ship:Body:Mu / (rS ^ 3)) * rvS * y.

        if nextStageKick
            set deltaB to stageB[nextStage] - stageB[s].

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
			local newA is (M11 * Mx - M01 * My) / det.
			local newB is (M00 * My - M10 * Mx) / det.
            set stageA[s] to (stageA[s] + newA) * 0.5.
            set stageB[s] to (stageB[s] + newB) * 0.5.
        }

        set debugStages[s]:text to "S" + s + ": A=" + round(stageA[s],3) + " B=" + round(stageB[s],3) + " T=" + round(stageT[s],2).

        // Update next stage guidance using staging state at start
        set stageA[nextStage] to deltaA + stageA[s] + stageB[s] * T.
        if not nextStageKick
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
        set stageT[s] to stageT[s] - deltaT.
        local T is max(min(stageT[s], tau - 1), 1).
		local accelT is accel / (1 - T / tau).

        // Current flight integrals
        set b0 to -exhaustV * ln(1 - T / tau). // delta V
        set b1 to b0 * tau - exhaustV * T.
        set b2 to b1 * tau - exhaustV * (T * T) * 0.5.

        if hT <= 0
		{
			// Suborbital guidance
			local accelS is accel / (1 - T / tau).

			local c0 is b0 * T - b1.

			// State at burnout
			local rS is r + rv * T + c0 * stageA[s].
			local rvS is rv + b0 * stageA[s] + b1 * stageB[s].
			local omegaS is max(stageOmegaT[s], omega).

			calcHeadingDerivs(rS, omegaS, accelT, T).

			// Angular momentum gain at burnout
			local hS is h + (r + rS) * 0.5 * (ftheta * b0 + fdtheta * b1 + fddtheta * b2).

			// Tangental and angular speed at burnout
			set omegaS to hS / (rS * rS).
			set stageOmegaT[s] to omegaS.  // feedback to next update

			// Average acceleration over coast phase
			local accS is omegaS * omegaS * rS - Ship:Body:mu / (rS*rS).
			// Assume omegaS has minimal change during coast
			local accF is omegaS * omegaS * rT - Ship:Body:mu / (rT*rT).
			local accC is (accS + accF) * 0.5.

			local T2 is (rvT - rvS) / accC.

			local rF is rS + rvS * T2 + 0.5 * accC * T2 * T2.
			local A2 is 1.
			if rF > rT
				set A2 to -1.

			local rS2 is r + rv * T + c0 * A2.
			local rvS2 is rv + b0 * A2.

			set T2 to (rvT - rvS2) / accC.
			local rF2 is rS2 + rvS2 * T2 + 0.5 * accC * T2 * T2.

			set stageA[s] to A2 + (stageA[s] - A2) * (rT - rF2) / (rF - rF2).
		}
        else if not stageGuided[s]
        {
            // Final stage spin kick
			set stageA[s] to stageA[s] + stageB[s] * deltaT.

			// Heading derivatives
            local fr is stageA[s] + (Ship:Body:Mu / r2 - (omega * omega) * r) / accel.

            set ftheta to 1 - (fr * fr) * 0.5.
            set fdtheta to 0.
            set fddtheta to 0.

			// Calculate required delta V
			local dh is hT - h.
			local meanRadius is (r + rT) * 0.5.

			local deltaV is dh / meanRadius.
			set deltaV to deltaV / ftheta.

			// Calculate new estimate for T
			if deltaV > 0
			{
				set T to tau * (1 - constant:e ^ (-deltaV / exhaustV)).
				set stageT[s] to (stageT[s] + T) * 0.5.
			}

			// Update A, B with new T estimate
			set b0 to deltaV.
			set b1 to b0 * tau - exhaustV * T.
			local c0 is b0 * T - b1.
			local c1 is c0 * tau - exhaustV * (T*T) * 0.5.

			local Mx is rvT - rv.
			local My is rT - r - rv * T.

			local det is b0 * c1 - b1 * c0.
			if (abs(det) > 1e-7)
			{
				local newA is (c1 * Mx - b1 * My) / det.
				set stageA[s] to (stageA[s] + newA) * 0.5.
			}

			if startStage > GuidanceLastStage
			{
				// prevent T going too low and cutting off guidance updates
				set stageT[s] to max(stageT[s], 10).
			}
        }
        else
		{
			// Guidance has diverged, try resetting.
			if abs(stageA[s]) > 3
			{
				set stageA[s] to 0.
				set stageB[s] to 0.
				if s <> Stage:Number
					set stageT[s] to stageTFull[s].
				else
					set stageT[s] to LAS_GetStageBurnTime().
			}

			// Final stage guidance
			set stageA[s] to stageA[s] + stageB[s] * deltaT.

			calcHeadingDerivs(rT, omegaT, accelT, T).

			// Calculate required delta V
			local dh is hT - h.
			local meanRadius is (r + rT) * 0.5.

			if oTarget:IsType("Orbitable")
			{
				// calc delta anom
				local c0 is b0 * T - b1.
				local c1 is c0 * tau - exhaustV * (T*T) * 0.5.
				local c2 is c1 * tau - exhaustV * T^3 / 6.
				local d3 is h * rv / r^3.
				local d4 is (hT * rvT / rT^3 - d3) / T.

				local dA is T * h / (r*r)
					+ (ftheta * c0 + fdtheta * c1 + fddtheta * c2) / meanRadius
					- d3 * T*T - d4 * T^3 / 3.
				set deltaAnom to deltaAnom + dA.

			}

			local deltaV is dh / meanRadius.
			set deltaV to deltaV + exhaustV * T * (fdtheta + fddtheta * tau).
			set deltaV to deltaV + fddtheta * exhaustV * (T*T) * 0.5.
			set deltaV to deltaV / (ftheta + (fdtheta + fddtheta * tau) * tau).

			// Calculate new estimate for T
			if deltaV > 0
			{
				set T to tau * (1 - constant:e ^ (-deltaV / exhaustV)).
				set stageT[s] to (stageT[s] + T) * 0.5.
			}

			// Update A, B with new T estimate
			set b0 to deltaV.
			set b1 to b0 * tau - exhaustV * T.
			local c0 is b0 * T - b1.
			local c1 is c0 * tau - exhaustV * (T*T) * 0.5.

			local Mx is rvT - rv.
			local My is rT - r - rv * T.

			local det is b0 * c1 - b1 * c0.
			if (abs(det) > 1e-7)
			{
				local newA is (c1 * Mx - b1 * My) / det.
				local newB is (b0 * My - c0 * Mx) / det.
				set stageA[s] to (stageA[s] + newA) * 0.5.
				set stageB[s] to (stageB[s] + newB) * 0.5.
			}

			if abs(stageA[s]) > 3
			{
				set stageA[s] to 0.
				set stageB[s] to 0.
				if s <> Stage:Number
					set stageT[s] to stageTFull[s].
				else
					set stageT[s] to LAS_GetStageBurnTime().
			}
			else if startStage > GuidanceLastStage
			{
				// prevent T going too low and cutting off guidance updates
				set stageT[s] to max(stageT[s], 10).
			}
		}

        set debugStages[s]:text to "S" + s + ": A=" + round(stageA[s],3) + " B=" + round(stageB[s],3) + " T=" + round(stageT[s],2).

		set tStart to MissionTime.
    }
	
	//log Stage:Number + "," + Ship:Altitude + "," + omega*r + "," + Ship:Latitude + "," + Ship:Orbit:TrueAnomaly + "," + deltaAnom to "0:/logs/lat.csv".

    set yawK to newYawK.
	set guidanceValid to true.

    if oTarget:IsType("Orbitable")
    {
        UpdateTarget(deltaAnom).
    }
}

//------------------------------------------------------------------------------------------------

global function LAS_GetGuidanceAim
{
	parameter startStage.

    if rT <= 0 or not guidanceValid
        return V(0,0,0).

    local s is startStage.
    local t is MissionTime - tStart.

    local r is LAS_ShipPos():Mag.
    local r2 is LAS_ShipPos():SqrMagnitude.
    local rVec is LAS_ShipPos():Normalized.
    local hVec is vcrs(LAS_ShipPos(), Ship:Velocity:Orbit):Normalized.
    local downtrack is vcrs(hVec, rVec):Normalized.
    local omega is vdot(Ship:Velocity:Orbit, downtrack) / r.

    if hT <= 0
        set s to GuidanceLastStage.

    // Calculate current peformance
    local StageEngines is LAS_GetStageEngines().
    local currentThrust is 0.
    for eng in StageEngines
    {
        if eng:Thrust > 0
        {
            set currentThrust to currentThrust + eng:Thrust.
        }
    }
    local accel is currentThrust / Ship:Mass.

    // Engines off? No guidance.
    if currentThrust > 1e-4
    {
        // Calculate radial heading vector
        local fr is stageA[s] + stageB[s] * t.
        // Add gravity and centifugal force term.
        set fr to fr + (Ship:Body:Mu / r2 - (omega * omega) * r) / accel.

        // Yaw heading vector
        local fh is 0.
        local vtheta is omega * r.
		local hdot is 0.
		local d is 1.
		
		if yawK <> 0
        {
			// Don't yaw steer until downrange speed is high enough
			if vtheta < 4500
			{
				set fh to -sqrt(1 - vdot(vcrs(rVec, Heading(aeroHeading, 0):Vector), hVec)^2).
			}
			else
			{
				if oTarget:IsType("Orbitable")
				{
					set hdot to vdot(hVec, oTarget:Position:Normalized).
					set d to vdot(downtrack, oTarget:Position:Normalized).
				}
				else if oTarget:IsType("Vector")
				{
					set hdot to vdot(hVec, oTarget:Normalized).
					set d to vdot(downtrack, oTarget:Normalized).
				}
				else
				{
					local incDiff is Ship:Orbit:Inclination - incT.
					set hdot to sin(incDiff).
					set d to cos(incDiff).
				}

				set fh to hdot * d / (vtheta * yawK).
			}
			if Ship:Velocity:Orbit:Y < 0
				set fh to -fh.
        }

        set debugFr:text to "fr=" + round(fr,3) + " fh=" + round(fh,4) + " s=" + s + "/" + GuidanceLastStage + " t=" + round(t, 2).

        // Construct aim vector
        if (fr * fr + fh * fh) < 0.999
        {
            return fr * rVec + fh * hVec + sqrt(1 - fr * fr - fh * fh) * downtrack.
        }
    }
	else
	{
		set debugFr:text to "fr=No Thrust" + " s=" + s + "/" + GuidanceLastStage.
	}

    return V(0,0,0).
}

//------------------------------------------------------------------------------------------------
// Call just before starting guidance updates

global function LAS_StartGuidance
{
	parameter startStage.
    parameter inclin is -1.
    parameter targetObt is 0.
	parameter hdg is 90.

    if rT <= 0
        return.

    // Setup initial orbital energy
    set orbitalEnergy to Ship:Velocity:Orbit:sqrMagnitude / 2 - Ship:Body:Mu / LAS_ShipPos():Mag.

    // Auto calculate final guidance stage
    if GuidanceLastStage < 0
    {
        // Update estimate for T for active stage
		set stageT[Stage:Number] to LAS_GetStageBurnTime().

		if hT <= 0
		{
			from {local i is startStage.} until i < 0 step {set i to i - 1.} do
			{
				if stageExhaustV[i] > 0
				{
					set GuidanceLastStage to i.
				}
			}
		}
		else
		{
			local r is LAS_ShipPos():Mag.
			local h is vcrs(LAS_ShipPos(), Ship:Velocity:Orbit):Mag.

			local deltaVReq is 1.4 * (hT - h) / (rT + r).   // This gives a fairly reasonable guess at the required deltaV.
			local deltaV is 0.
			from {local i is startStage.} until i < 0 step {set i to i - 1.} do
			{
				if stageExhaustV[i] > 0
				{
					set deltaV to deltaV - stageExhaustV[i] * ln(1 - stageT[i] * stageAccel[i] / stageExhaustV[i]).
					set GuidanceLastStage to i.
					if deltaV >= deltaVReq
						break.
				}
			}

			print "dV=" + round(deltaV, 1) + "/" + round(deltaVReq, 1).
		}
    }
    print "S=" + startStage + " Last guidance stage: " + GuidanceLastStage.

	if defined LAS_TargetVector
	{
		set oTarget to LAS_TargetVector.
        set incT to inclin.
	}
	else if targetObt:IsType("Orbitable")
    {
        set oTarget to targetObt.
    }
    else
    {
        set incT to inclin.
    }
	set aeroHeading to hdg.
	
	from { local s is startStage. } until s < GuidanceLastStage step { set s to s - 1.} do
	{
		set stageA[s] to 0.
		set stageB[s] to 0.
		set stageT[s] to stageTFull[s].
	}

    // Converge guidance
    local ConvergeStage is startStage.

    local count is 0.
    until ConvergeStage < GuidanceLastStage
    {
        local A is stageA[ConvergeStage].
        set tStart to MissionTime.

		// Update estimate for T for active stage
		set stageT[Stage:Number] to LAS_GetStageBurnTime().

        UpdateGuidance(startStage).
		
		if abs(stageA[ConvergeStage]) > 50 or stageT[ConvergeStage] <= 0
			break.

        if abs(stageA[ConvergeStage] - A) < 0.01 and abs(stageA[ConvergeStage]) < 1
            set ConvergeStage to ConvergeStage - 1.

        set count to count + 1.
        if count > 50
            break.
    }

    if ConvergeStage < GuidanceLastStage
        print "Guidance converged successfully in " + count + " iterations.".
    else
        print "Guidance failed to converge.".

    return ConvergeStage < GuidanceLastStage.
}

//------------------------------------------------------------------------------------------------

global function LAS_GuidanceUpdate
{
	parameter startStage.

    if rT <= 0
        return.

    // Guidance updates once per second
    if MissionTime - tStart < 0.98
        return.

    UpdateGuidance(startStage).
}

//------------------------------------------------------------------------------------------------

global function LAS_GuidanceCutOff
{
    if rT <= 0 or hT <= 0
        return false.

    local prevE is orbitalEnergy.

    set orbitalEnergy to Ship:Velocity:Orbit:sqrMagnitude / 2 - Ship:Body:Mu / LAS_ShipPos():Mag.

    // Have we reached final orbital energy, or likely to reach it within half the next time step?
    return orbitalEnergy + (orbitalEnergy - prevE) * 0.5 >= ET.
}

global function LAS_StageIsGuided
{
	parameter s is Stage:Number.

	if s >= 0 and s < StageGuided:Length
		return stageGuided[s].

	return false.
}

global function LAS_GuidanceBurnTime
{
	parameter s is Stage:Number.

	if s >= 0 and s < StageT:Length
		return StageT[s].

	return 0.
}
