// Lander direct descent system, for safe(!) landings
// Two phase landing system, braking burn attempts to slow the craft to targeted vertical speed in one full thrust burn.
// Descent phase attempts a soft landing on the ground.

@lazyglobal off.

// Wait for unpack
wait until Ship:Unpacked.

parameter landStage is max(Stage:Number - 1, 0).
parameter brakingMargin is 1.5.

switch to scriptpath():volume.

// Setup functions
runpath("0:/flight/EngineMgmt", min(Stage:Number, landStage + 1)).
runpath("0:/flight/TuneSteering").
runoncepath("0:/lander/LanderSteering").

local DescentEngines is EM_GetEngines().

local burnThrust is 0.
local massFlow is 0.
for eng in DescentEngines
{
    set burnThrust to burnThrust + eng:PossibleThrust.
    set massflow to massFlow + eng:MaxMassFlow.
}

local shipMass is Ship:Mass.
local downrangeAdjust is 1.
local spinBrake is false.

local function GetBrakingAim
{
	parameter pCurrent is LAS_ShipPos().
	parameter vCurrent is Ship:Velocity:Surface.

	local horizVec is LanderSteering(pCurrent, vCurrent).
	
	local vertComp is -vdot(vCurrent:Normalized, Up:Vector) * downrangeAdjust.
	local thrustVec is (vertComp * Up:Vector + sqrt(1 - vertComp ^ 2) * horizVec):Normalized.
	
	return thrustVec.
}

// Estimates position at which the ship will be below the target speed based on starting immediately
local function EstimateBrakingPosition
{
	parameter vTarget.
	parameter burnDelay.
	parameter tStep is 0.5.

	local vCurrent is Ship:Velocity:Surface.
	local mCurrent is shipMass.
	local pCurrent is LAS_ShipPos().

	until vdot(vCurrent, Up:Vector) > vTarget or mCurrent < massFlow * 2
	{
		// Assume thrust is constant magntiude and retrograde
		local accel is v(0,0,0).
		if burnDelay < tStep
			set accel to ((tStep - burnDelay) / tStep) * GetBrakingAim(pCurrent, vCurrent) * burnThrust / mCurrent.
		set burnDelay to max(0, burnDelay - tStep).
		local g is -pCurrent:Normalized * Body:Mu / pCurrent:SqrMagnitude.

		// Basic symplectic euler integrator
		set vCurrent to vCurrent + (accel + g) * tStep.
		set pCurrent to pCurrent + vCurrent * tStep.

		set mCurrent to mCurrent - massFlow * tStep.
	}

	return pCurrent.
}

local function RollControl
{
    if spinBrake and vdot(SrfRetrograde:Vector, Facing:Vector) > 0.999
    {
        // spin up
        local rollRate is vdot(Facing:Vector, Ship:AngularVel).
        if abs(rollRate) > 1
        {
            set ship:control:roll to -0.1.
        }
        else
        {
            set ship:control:roll to -1.
        }
    }
    
    if EM_IgDelay() > 0
    {
        if Ship:Control:Fore > 0
        {
            if EM_GetEngines()[0]:FuelStability >= 0.99
                set Ship:Control:Fore to 0.
        }
        else
        {
            if EM_GetEngines()[0]:FuelStability < 0.98  
                set Ship:Control:Fore to 1.
        }
    }
}

if Ship:Status = "Flying" or Ship:Status = "Sub_Orbital" or Ship:Status = "Escaping"
{
    print "Direct descent system online.".

	local debugGui is GUI(400, 80).
    set debugGui:X to 160.
    set debugGui:Y to debugGui:Y + 240.
    local mainBox is debugGui:AddVBox().

    local debugStat is mainBox:AddLabel("Ready").

	debugGui:Show().
	if Stage:Number > landStage or Ship:Velocity:Surface:Mag > 300
	{
        set spinBrake to landStage < Stage:Number - 1.
        if spinBrake
        {
            print "Using unguided braking stage".
            set shipMass to 0.
            for shipPart in Ship:Parts
            {
                local decoupleStage is shipPart:DecoupledIn.

                if shipPart:DecoupledIn < Stage:Number - 1
                {
                    set shipMass to shipMass + shipPart:Mass.
                }
            }
        }

		print "  Engine: " + DescentEngines[0]:Config + ", Ship Mass: " + round(shipMass * 1000, 1) + " kg".

		LanderSelectWP().
        local targetPos is LanderTargetPos().

		local initGrav is (0.7 - shipMass * 0.035) * Body:Mu / (Body:Radius^2).
        
		if Body:Mu / LAS_ShipPos():SqrMagnitude < initGrav and Ship:GeoPosition:TerrainHeight / Body:Radius < 0.01
		{
			if targetPos:IsType("GeoCoordinates") and Body:Mu / LAS_ShipPos():SqrMagnitude < initGrav * 0.25
			{
				local lock nVec to vcrs(Ship:Velocity:Surface:Normalized, -Body:Position:Normalized):Normalized.
				print "d=" + vdot(targetPos:Position:Normalized, nVec).
				if abs(vdot(targetPos:Position:Normalized, nVec)) > 2e-4
				{
					print "Performing course correction.".
					LAS_Avionics("activate").
					rcs on.
					local lock steerVec to (nVec * vdot(targetPos:Position:Normalized, nVec)):Normalized.
					lock steering to LookDirUp(steerVec, Facing:UpVector).
					until vdot(Facing:Vector, steerVec) > 0.999
					{
						set debugStat:Text to "f=" + vdot(Facing:Vector, steerVec).
						wait 0.
					}
					set Ship:Control:Fore to 1.
					until abs(vdot(targetPos:Position:Normalized, nVec)) < 1e-4 or vdot(Facing:Vector, steerVec) < 0.995
					{
						set debugStat:Text to "d=" + vdot(targetPos:Position:Normalized, nVec) + " f=" + vdot(Facing:Vector, steerVec).
						wait 0.
					}
					unlock steering.
					rcs off.
					LAS_Avionics("shutdown").
				}
			}

			print "Waiting for initial gravity to increase to " + round(initGrav, 3) + " m/s".
			set kUniverse:Timewarp:Rate to 10.
			wait until Body:Mu / LAS_ShipPos():SqrMagnitude >= initGrav.
		}
		set kUniverse:Timewarp:Rate to 1.
		
		local targetSpeed is choose -10 if stage:number > landStage else -50.
		local lastPrediction is v(0,0,0).

		local function WaitBurn
		{
			parameter name.
			parameter burnDelay.
            parameter callback.

			local lock targetAlt to round(Ship:Velocity:Surface:Mag * brakingMargin).

			local alt is LAS_ShipPos():Mag.
			until alt < targetAlt
			{
				local tStart is Time:Seconds.
				local pFinal is EstimateBrakingPosition(targetSpeed, burnDelay).
				local geoPos is Body:GeoPositionOf(pFinal + Body:Position).
				set alt to pFinal:Mag - Body:Radius - geoPos:TerrainHeight.

				local debugStr to name + ", Target Alt: " + round(alt * 0.001, 1) + " / " + round(targetAlt * 0.001, 1) + " km".
				if targetPos:IsType("GeoCoordinates")
					set debugStr to debugStr + " Dist=" + round(vxcl(Up:Vector, targetPos:Position - geoPos:Position):Mag * 0.001, 1) + " km".
					
				set debugStat:Text to debugStr.

                callback().

				if alt > targetAlt + Ship:Velocity:Surface:Mag * (brakingMargin * 1.4)
                {
					wait until Time:Seconds >= tStart + 1.
                }
				else
                {
                    set kUniverse:Timewarp:Rate to 1.
					wait until Time:Seconds >= tStart + 0.25.
                }
					
				set lastPrediction to geoPos.
			}
		}
		set kUniverse:Timewarp:Rate to 10.

		// 60 second alignment margin
		WaitBurn("Align", choose 120 if spinBrake else 60, {}).
		set kUniverse:Timewarp:Rate to 1.
		wait until kUniverse:Timewarp:Rate = 1.

		// Full retrograde burn until vertical velocity is under 30 (or fuel exhaustion).
		print "Aligning for burn".

		LAS_Avionics("activate").
		rcs on.

		lock steering to LookDirUp(GetBrakingAim(), Facing:UpVector).

		set navmode to "surface".

		WaitBurn("Ignition", EM_IgDelay(), RollControl@).

        print "Beginning braking burn".
        EM_Ignition(choose 0.1 if spinBrake else 0.5).
        
        if spinBrake
        {
            // Jettison alignment stage.
            wait until Stage:Ready.
            stage.
            set Ship:Control:Neutralize to true.
            unlock steering.
        }
        
        if targetPos:IsType("GeoCoordinates")
        {
            local drPred is vdot(targetPos:Position - lastPrediction:Position, vxcl(Up:Vector, Ship:Velocity:Surface):Normalized).
            set downrangeAdjust to 1 + max(-0.02, min((drPred - 2500) / 20000, 0.02)).
        }

        until Ship:VerticalSpeed >= targetSpeed or not EM_CheckThrust(0.1)
        {
            local debugStr to "Braking".
            local t is Ship:Velocity:Surface:Mag * Ship:Mass / burnThrust.
            if targetPos:IsType("GeoCoordinates")
            {
                local wpBearing is vang(vxcl(up:vector, TargetPos:Position), vxcl(up:vector, Ship:Velocity:Surface)).
                set debugStr to debugStr + ", Dist=" + round(targetPos:Distance * 0.001, 1) + " km" + " Bearing=" + round(wpBearing, 2) + "°".
                if t < 100
                {
                    local hDot is 1 - vdot(Up:Vector, Ship:Velocity:Surface:Normalized)^2.
                    local hAccel is hDot * burnThrust / Ship:Mass.
                    local dist is Ship:GroundSpeed * t - 0.5 * hAccel * t^2.
                    local drEst is targetPos:Distance - (hDot * -targetSpeed * 30 + dist).
                    set debugStr to debugStr + " Est=" + round(drEst, 1) + " t=" + round(t,1).
                    
                    if t <= 60 and abs(wpBearing) < 1
                    {
                        set downrangeAdjust to 1 + max(-0.1, min((drEst - 1500) / 10000, 0.1)).
                    }
                }
            }
            else
            {
                set debugStr to debugStr + ", t=" + round(t,1).
            }

            set debugStat:Text to debugStr.
            
            if spinBrake and vdot(Facing:Vector, SrfRetrograde:Vector) < 0.4
                break.
            
            wait 0.
        }
        
		if not EM_CheckThrust(0.1)
			print "Fuel exhaustion in braking stage".

        if stage:number > landStage
        {
            // Jettison braking stage
            set Ship:Control:PilotMainThrottle to 0.
            stage.
        }
	}
	else
	{
		LanderSelectWP().

		LAS_Avionics("activate").
		rcs on.
    }
    
    if spinBrake and vdot(Facing:Vector, Ship:AngularVel) > 0.25
    {
        set ship:control:roll to 1.
        wait vdot(Facing:Vector, Ship:AngularVel) < 0.25.
        set ship:control:roll to 0.
    }

	wait until stage:ready.

	set navmode to "surface".

    // Switch on all tanks
    for p in Ship:Parts
    {
        for r in p:resources
        {
            set r:enabled to true.
        }
    }

	if landStage > 0
	{
		set DescentEngines to LAS_GetStageEngines(landStage).
	}
	else
	{
		// Calculate new thrust
		list engines in DescentEngines.
	}
    
    set Ship:Control:PilotMainThrottle to 0.
	for eng in DescentEngines
		eng:Shutdown.

    runpath("/lander/FinalDescent", DescentEngines, debugStat, LanderTargetPos()).
}
