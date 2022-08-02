// Orbital guidance system
// Based on: EXPLICIT GUIDANCE EQUATIONS FOR MULTISTAGE BOOST TRAJECTORIES By Fred Teren
// Valid for an unlimited number of stages (tested with 3 stages).

@lazyglobal off.

parameter liftoffStage is choose stage:number - 1 if Ship:Status <> "Flying" else Stage:number.

runoncepath("/mgmt/ReadoutGUI").

//------------------------------------------------------------------------------------------------

local rT is 0.      // Target radial distance
local rvT is 0.     // Target radial velocity
local hT is 0.      // Target angular momentum
local omegaT is 0.  // Target angular speed
local ET is 0.      // Target orbital energy
local eccT is 0.    // Target eccentricty.
local LT is 0.      // Target semilatus rectum

local incT is -1.   // Target inclination
local inertialHeading is 0.
local oTarget is 0. // Target orbitable
local launchLat is Ship:Latitude.

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
local guidancedeltaV is 0.

local tStart is 0.   // Time since last guidance update

local orbitalEnergy is 0.   // Current orbital energy

local readoutGui is ReadoutGUI_Create(-560, -380).
readoutGui:SetColumnCount(60, 4).

local statusReadout is readoutGui:AddReadout("Status").
local thrustReadout is readoutGui:AddReadout("Thrust").
local IspReadout is readoutGui:AddReadout("Isp").
local vθReadout is readoutGui:AddReadout("vθ").

local frReadout is readoutGui:AddReadout("fr").
local fhReadout is readoutGui:AddReadout("fh").
local fdReadout is readoutGui:AddReadout("fd").
local tReadout is readoutGui:AddReadout("t").

local debugReset is 0.
local stageReadouts is lexicon().

ReadoutGUI_SetText(statusReadout, "Inactive", ReadoutGUI_ColourNormal).

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

    if targetPe < 100000 and Ship:Body = Earth
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
				print "Target Orbit: Pe=" + round(targetPe * 0.001, 1) + " km, hyperbolic, A=" + round(LAS_TargetSMA * 0.001, 1) + " km".
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

	// Size lists
	from {local s is liftoffStage.} until s < 0 step {set s to s - 1.} do
	{
		stageA:add(0).
		stageB:add(0).
		stageT:add(0).
		stageTFull:Add(0).
		stageOmegaT:add(0).
		stageExhaustV:add(0).
		stageAccel:add(0).
		stageGuided:add(false).
	}
    
    set debugReset to readoutGui:AddButton("Reset").
    
    local stoppedGuidance is false.
	// Populate lists
	from {local s is liftoffStage.} until s < 0 step {set s to s - 1.} do
	{
		local stagePerf is LAS_GetStagePerformance(s, true).
	
		set stageT[s] to stagePerf:BurnTime.
		set stageTFull[s] to stagePerf:BurnTime.
		set stageExhaustV[s] to stagePerf:eV.
		set stageAccel[s] to stagePerf:Accel.
		set stageGuided[s] to stagePerf:Guided.
		
		// If engine was lit in the previous stage, only use sustainer time
		if stagePerf:litPrevStage
			set stageT[s] to stageT[s] - stageT[s+1].
			
		set stageTFull[s] to stageT[s].
        
        if s > GuidanceLastStage and not stoppedGuidance
        {
            if stagePerf:eV > 0
            {
                set guidanceDeltaV to guidanceDeltaV + stagePerf:eV * ln(stagePerf:WetMass / stagePerf:DryMass).

                stageReadouts:Add(s, lexicon()).
                stageReadouts[s]:Add("A", readoutGui:AddReadout("S" + s + ": A")).
                stageReadouts[s]:Add("B", readoutGui:AddReadout("B")).
                stageReadouts[s]:Add("T", readoutGui:AddReadout("T")).
                stageReadouts[s]:Add("margin", readoutGui:AddReadout("vθ")).
                ReadoutGUI_SetText(stageReadouts[s]:A, round(stageExhaustV[s] / constant:g0, 1) + "s", ReadoutGUI_ColourNormal).
                ReadoutGUI_SetText(stageReadouts[s]:B, round(stageAccel[s], 2) + "m/s", ReadoutGUI_ColourNormal).
                ReadoutGUI_SetText(stageReadouts[s]:T, round(stageT[s], 1) + "s", ReadoutGUI_ColourNormal).
                ReadoutGUI_SetText(stageReadouts[s]:margin, stageGuided[s], ReadoutGUI_ColourNormal).
            }
            else
            {
                set stoppedGuidance to true.
                set GuidanceLastStage to s + 1.
            }
        }
	}

	readoutGui:Show().
}

local function GetYawSteer
{
	parameter vtheta.
	parameter hVec.
	
	local targetVec is V(0,0,0).
	
	if oTarget:IsType("Orbitable")
	{
		set targetVec to oTarget:Position:Normalized.
	}
	else
	{
		set targetVec to inertialHeading.
	}
	
	local downtrack is vcrs(hVec, LAS_ShipPos():Normalized):Normalized.
	local hdot is vdot(hVec, targetVec).
	local d is vdot(downtrack, targetVec).
	set d to d / abs(d).
	
	return list(hdot, d).
}

//------------------------------------------------------------------------------------------------

local function UpdateGuidance
{
	parameter startStage.
	
    // Clamp s incase we run off the end (just keep running final stage guidance).
    local s is max(startStage, GuidanceLastStage).

    if debugReset:TakePress
    {
		LAS_StartGuidance(Stage:Number, incT, oTarget, mod(360 - latlng(90,0):bearing, 360)).
    }

    // Calc reference frame
    local r is LAS_ShipPos():Mag.
    local r2 is LAS_ShipPos():SqrMagnitude.
    local rv is vdot(Ship:Velocity:Orbit, LAS_ShipPos():Normalized).
    local h is vcrs(LAS_ShipPos(), Ship:Velocity:Orbit):Mag.
    local hVec is vcrs(LAS_ShipPos(), Ship:Velocity:Orbit):Normalized.
    local omega is h / r2.
    local deltaT is MissionTime - tStart.

    // Don't update during final few seconds of stage as divergence will cause issues.
    if stageT[s] < 10
    {
        ReadoutGUI_SetText(statusReadout, "T < 10 s=" + s, ReadoutGUI_ColourNormal).
        ReadoutGUI_SetText(vθReadout, round(omega * r, 0) + " / " + round(omegaT * rT, 0), ReadoutGUI_ColourNormal).
        if kUniverse:TimeWarp:Rate > 1
			kUniverse:TimeWarp:CancelWarp().
		set stageChange to true.
        return.
    }

    // Calculate current performance
    local maxMassFlow is 0.
    local currentThrust is 0.
    local ratedThrust is 0.
    local engCount is 0.

	if startStage <> Stage:Number
	{
		set currentThrust to stageAccel[startStage] * Ship:Mass.
		set ratedThrust to currentThrust.
		set maxMassFlow to ratedThrust / stageExhaustV[startStage].
		set engCount to 1.
	}
	else
	{
		local StageEngines is LAS_GetStageEngines().
        local currentMassFlow is 0.
		for eng in StageEngines
		{
			if eng:Thrust > 0
			{
				set currentMassFlow to currentMassFlow + eng:MassFlow.
				set maxMassFlow to maxMassFlow + eng:MaxMassFlow.
				set currentThrust to currentThrust + eng:Thrust.
				set ratedThrust to ratedThrust + eng:MaxThrust.
				set engCount to engCount + 1.
			}
		}
		
		local thrustReq is 0.4.
		if stageChange
			set thrustReq to 0.8.

		// Engines off? No guidance.
		if engCount < 1 or currentThrust < ratedThrust * thrustReq or currentMassFlow <= 0
		{
            ReadoutGUI_SetText(statusReadout, "No Thrust", ReadoutGUI_ColourFault).
            ReadoutGUI_SetText(thrustReadout, round(100 * currentThrust / max(ratedThrust, 0.001), 1) + "%", ReadoutGUI_ColourFault).
            ReadoutGUI_SetText(ispReadout, round(currentThrust / (max(currentMassFlow, 1e-6) * Constant:g0), 1) + " s", ReadoutGUI_ColourNormal).
            ReadoutGUI_SetText(vθReadout, round(omega * r, 0) + " / " + round(omegaT * rT, 0), ReadoutGUI_ColourNormal).
			set guidanceValid to false.
			return.
		}
		
		if stageChange
		{
			set kUniverse:TimeWarp:Mode to "Physics".
			set kUniverse:TimeWarp:Rate to 2.
		}

		set stageChange to false.
	}

    // Setup current stage
    local exhaustV is ratedThrust / maxMassFlow.
    local accel is ratedThrust / Ship:Mass.
    local tau is exhaustV / accel.

    ReadoutGUI_SetText(statusReadout, "Nominal", ReadoutGUI_ColourGood).
    ReadoutGUI_SetText(thrustReadout, round(100 * currentThrust / max(ratedThrust, 0.001), 1) + "%", ReadoutGUI_ColourNormal).
    ReadoutGUI_SetText(ispReadout, round(exhaustV / Constant:g0, 1) + "s", ReadoutGUI_ColourNormal).
    ReadoutGUI_SetText(vθReadout, round(omega * r, 0) + " / " + round(omegaT * rT, 0), ReadoutGUI_ColourNormal).

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

        if incT >= 0 or oTarget:IsType("Orbitable")
        {			
			local vtheta is omega * r.
			local vthetaT is omegaT * rT.

			local hdot_d is GetYawSteer((vtheta + vthetaT) / 2, hVec).
            local hdot is hdot_d[0].
			local d is hdot_d[1].

            local allT is T.
            from {local i is s - 1.} until i < GuidanceLastStage step {set i to i - 1.} do
            {
                set allT to allT + stageT[i].
            }

            local d1 is d / vtheta.
            local d2 is (d / vthetaT - d1) / allT.

            if yawK = 0
                set yawK to (d1*d1*b0 + 2*d1*d2*b1 + d2*d2*b2).

			set fh to hdot * d1 / yawK.
			set fdh to fh * d2 / d1.
            
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

        if stageReadouts:HasKey(s)
        {
            ReadoutGUI_SetText(stageReadouts[s]:A, round(stageA[s],3), ReadoutGUI_ColourNormal).
            ReadoutGUI_SetText(stageReadouts[s]:B, round(stageB[s],3), ReadoutGUI_ColourNormal).
            ReadoutGUI_SetText(stageReadouts[s]:T, round(stageT[s],1), ReadoutGUI_ColourNormal).
            ReadoutGUI_SetText(stageReadouts[s]:margin, round(omegaS * rS,0), ReadoutGUI_ColourNormal).
        }

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
        
        local TFull is stageTFull[s].
        if s = Stage:Number
            set TFull to LAS_GetStageBurnTime().

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
                set stageT[s] to TFull.
			}

			// Final stage guidance
			set stageA[s] to stageA[s] + stageB[s] * deltaT.

			calcHeadingDerivs(rT, omegaT, accelT, T).

			// Calculate required delta V
			local dh is hT - h.
			local meanRadius is (r + rT) * 0.5.

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
                set stageT[s] to TFull.
			}
			else if startStage > GuidanceLastStage
			{
				// prevent T going too low and cutting off guidance updates
				set stageT[s] to max(stageT[s], 10).
			}
		}
		
        if stageReadouts:HasKey(s)
        {
            ReadoutGUI_SetText(stageReadouts[s]:A, round(stageA[s],3), ReadoutGUI_ColourNormal).
            ReadoutGUI_SetText(stageReadouts[s]:B, round(stageB[s],3), ReadoutGUI_ColourNormal).
            ReadoutGUI_SetText(stageReadouts[s]:T, round(stageT[s],1), ReadoutGUI_ColourNormal).
            local margin is (choose "+" if TFull >= stageT[s] else "") + round(TFull - stageT[s],1).
            ReadoutGUI_SetText(stageReadouts[s]:margin, margin, choose ReadoutGUI_ColourGood if TFull >= stageT[s] else ReadoutGUI_ColourFault).
        }

		set tStart to MissionTime.
    }

    set yawK to newYawK.
	set guidanceValid to true.
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
    local ratedThrust is 0.
    for eng in StageEngines
    {
        if eng:Thrust > 0
        {
            set ratedThrust to ratedThrust + eng:MaxThrust.
        }
    }
    local accel is ratedThrust / Ship:Mass.

    // Engines off? No guidance.
    if ratedThrust > 1e-4
    {
        // Calculate radial heading vector
        local fr is stageA[s] + stageB[s] * t.
        // Add gravity and centifugal force term.
        local gravAccel is (Ship:Body:Mu / r2 - (omega * omega) * r).
        set fr to fr + gravAccel / accel.

        // Yaw heading vector
        local fh is 0.
		
		if yawK <> 0
        {
			local vtheta is omega * r.
			local hdot_d is GetYawSteer(vtheta, hVec).
            local hdot is hdot_d[0].
			local d is hdot_d[1].
			
			set fh to hdot * d / (vtheta * yawK).
            set fh to max(-0.1, min(fh, 0.1)).
        }

        ReadoutGUI_SetText(frReadout, round(fr,4), ReadoutGUI_ColourNormal).
        ReadoutGUI_SetText(fhReadout, round(fh,4), ReadoutGUI_ColourNormal).
        ReadoutGUI_SetText(tReadout, round(t, 2) + "s", ReadoutGUI_ColourNormal).

        // Construct aim vector
        if (fr * fr + fh * fh) < 0.999
        {
            if gravAccel < accel
                set fr to min(fr, 0.6).
			local fd is sqrt(1 - fr * fr - fh * fh).

            ReadoutGUI_SetText(fdReadout, round(fd,4), ReadoutGUI_ColourNormal).
            
            return fr * rVec + fh * hVec + fd * downtrack.
        }
		else
		{
            ReadoutGUI_SetText(fdReadout, "0", ReadoutGUI_ColourNormal).
		}
    }
	else
	{
        ReadoutGUI_SetText(frReadout, "", ReadoutGUI_ColourNormal).
        ReadoutGUI_SetText(fhReadout, "", ReadoutGUI_ColourNormal).
        ReadoutGUI_SetText(fdReadout, "", ReadoutGUI_ColourNormal).
        ReadoutGUI_SetText(tReadout, "", ReadoutGUI_ColourNormal).
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

		from {local i is startStage.} until i < 0 step {set i to i - 1.} do
		{
			if stageExhaustV[i] > 0
				set GuidanceLastStage to i.
			else
				break.
		}
    }

	if targetObt:IsType("Orbitable")
    {
        set oTarget to targetObt.
    }
    else
    {
        set incT to inclin.
		local inertialAz is arcsin(max(-1, min(cos(inclin)/cos(LaunchLat),1))).
		if hdg > 90
			set inertialHeading to Heading(180 - inertialAz, 0):Vector.
		else
			set inertialHeading to Heading(inertialAz, 0):Vector.
    }
	
	from { local s is startStage. } until s < GuidanceLastStage step { set s to s - 1.} do
	{
		set stageA[s] to 0.
		set stageB[s] to 0.
		set stageT[s] to stageTFull[s].
		set stageOmegaT[s] to 0.
	}

    // Converge guidance
    local ConvergeStage is startStage.

    local count is 0.
    local A is 10.
    until ConvergeStage < GuidanceLastStage
    {
        set A to stageA[ConvergeStage].
        set tStart to MissionTime.

		// Update estimate for T for active stage
		set stageT[Stage:Number] to LAS_GetStageBurnTime().

        UpdateGuidance(startStage).
		
		if abs(stageA[ConvergeStage]) > 50 or stageT[ConvergeStage] <= 0
			break.

        if abs(stageA[ConvergeStage] - A) < 0.01 and abs(stageA[ConvergeStage]) < 2.5
            set ConvergeStage to ConvergeStage - 1.

        set count to count + 1.
        if count > 50
            break.
    }

    if ConvergeStage < GuidanceLastStage
        print METString + " Guidance converged successfully in " + count + " iterations.".
    else
        print METString + " Guidance failed to converge, s=" + startStage + "/" + ConvergeStage + " d=" + round(abs(stageA[ConvergeStage] - A), 4).

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

global function LAS_GuidanceTargetVTheta
{
	return OmegaT * rT.
}

global function LAS_GuidanceDeltaV
{
    return guidanceDeltaV.
}

global function LAS_GuidanceLastStage
{
    return GuidanceLastStage.
}
