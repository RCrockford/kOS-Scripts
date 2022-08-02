// Lander direct descent system, for safe(!) landings
// Two phase landing system, braking burn attempts to slow the craft to targeted vertical speed in one full thrust burn.
// Descent phase attempts a soft landing on the ground.

@clobberbuiltins on.
@lazyglobal off.

// Wait for unpack
wait until Ship:Unpacked.

parameter landStage is max(Stage:Number - 1, 0).
parameter brakingMargin is 1.5.
parameter forceCC is false.
parameter manualTarget is 0.

switch to scriptpath():volume.

// Setup functions
runpath("/flight/enginemgmt", min(Stage:Number, landStage + 1)).
runpath("/flight/tunesteering").
runoncepath("/lander/landersteering").

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

	local horizVec is LanderSteering(pCurrent, vCurrent, 0.2).
	
	local vertComp is -vdot(vCurrent:Normalized, Up:Vector) * downrangeAdjust.
	local thrustVec is (vertComp * Up:Vector + sqrt(1 - vertComp ^ 2) * horizVec:vec):Normalized.
	
	return thrustVec.
}

// Estimates position at which the ship will be below the target speed based on starting immediately
local function EstimateBrakingPosition
{
	parameter vTarget.
	parameter burnDelay.
	parameter tStep is 0.25.

	local vCurrent is Ship:Velocity:Surface.
	local mCurrent is shipMass.
	local pCurrent is LAS_ShipPos().
    
	until vdot(vCurrent, Up:Vector) > vTarget or mCurrent < massFlow * 2
	{
		// Assume thrust is constant magntiude and retrograde
        local throt is 0.
		if burnDelay < tStep
			set throt to ((tStep - burnDelay) / tStep).
		local accel is throt * GetBrakingAim(pCurrent, vCurrent) * burnThrust / mCurrent.
		set burnDelay to max(0, burnDelay - tStep).
		local g is -pCurrent:Normalized * Body:Mu / pCurrent:SqrMagnitude.

		// Basic symplectic euler integrator
		set vCurrent to vCurrent + (accel + g) * tStep.
		set pCurrent to pCurrent + vCurrent * tStep.

		set mCurrent to mCurrent - massFlow * throt * tStep.
	}

	return pCurrent.
}

local function RC
{
    parameter close.

    if spinBrake and abs(SteeringManager:AngleError) < 1
    {
        // spin up
        local rollRate is vdot(Facing:Vector, Ship:AngularVel).
        if abs(rollRate) > 1.2
        {
            set ship:control:roll to -0.01.
        }
        else
        {
            set ship:control:roll to -1.
        }
    }
    
    if close and EM_IgDelay() > 0
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

    if HasTarget and manualTarget:IsType("Scalar")
        set manualTarget to Target.

    runoncepath("/mgmt/readoutgui").
    local readoutGui is ReadoutGUI_Create().
    readoutGui:SetColumnCount(80, 3).

    local Readouts is lexicon().

    Readouts:Add("height", readoutGui:AddReadout("Height")).
    Readouts:Add("acgx", readoutGui:AddReadout("Acgx")).
    Readouts:Add("fr", readoutGui:AddReadout("fr")).

    Readouts:Add("throt", readoutGui:AddReadout("Throttle")).
    Readouts:Add("thrust", readoutGui:AddReadout("Thrust")).
    Readouts:Add("status", readoutGui:AddReadout("Status")).

    Readouts:Add("dist", readoutGui:AddReadout("Distance")).
    Readouts:Add("bearing", readoutGui:AddReadout("Bearing")).
    Readouts:Add("eta", readoutGui:AddReadout("ETA")).
    
	readoutGui:Show().

    ReadoutGUI_SetText(Readouts:status, "Ready", ReadoutGUI_ColourNormal).

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

		LanderSelectWP(manualTarget).
        local targetPos is LanderTargetPos().

		local initGrav is (0.7 - shipMass * 0.035) * Body:Mu / (Body:Radius^2).
        
		if Body:Mu / LAS_ShipPos():SqrMagnitude < initGrav and Ship:GeoPosition:TerrainHeight / Body:Radius < 0.01
		{
			if targetPos:IsType("GeoCoordinates") and Body:Mu / LAS_ShipPos():SqrMagnitude < initGrav * (choose 0.8 if forceCC else 0.25)
			{
                print "Waiting for gravity to increase to " + round(initGrav * 0.2, 3) + " m/s for CCM".
                set kUniverse:Timewarp:Rate to 10.
                wait until Body:Mu / LAS_ShipPos():SqrMagnitude >= initGrav * 0.2.
                set kUniverse:Timewarp:Rate to 1.
            
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
                        ReadoutGUI_SetText(Readouts:fr, round( vdot(Facing:Vector, steerVec), 3), ReadoutGUI_ColourNormal).
						wait 0.
					}
					set Ship:Control:Fore to 1.
					until abs(vdot(targetPos:Position:Normalized, nVec)) < 1e-4 or vdot(Facing:Vector, steerVec) < 0.995
					{
                        ReadoutGUI_SetText(Readouts:dist, round(vdot(targetPos:Position:Normalized, nVec), 6), ReadoutGUI_ColourNormal).
                        ReadoutGUI_SetText(Readouts:fr, round( vdot(Facing:Vector, steerVec), 3), ReadoutGUI_ColourNormal).
						wait 0.
					}
					unlock steering.
					rcs off.
					LAS_Avionics("shutdown").
				}
			}

			print "Waiting for gravity to increase to " + round(initGrav, 3) + " m/s for braking".
			set kUniverse:Timewarp:Rate to 10.
			wait until Body:Mu / LAS_ShipPos():SqrMagnitude >= initGrav.
		}
		set kUniverse:Timewarp:Rate to 1.
		
		local targetSpeed is choose -10 if stage:number > landStage else -50.
		local lastPrediction is v(0,0,0).

		local function WaitBurn
		{
			parameter burnDelay.
            parameter callback.

			local lock targetAlt to round(Ship:Velocity:Surface:Mag * brakingMargin).

			local alt is Ship:Altitude.
			until alt < targetAlt - Ship:VerticalSpeed * 0.5
			{
				local tStart is Time:Seconds.
				local pFinal is EstimateBrakingPosition(targetSpeed, burnDelay).
				local geoPos is Body:GeoPositionOf(pFinal + Body:Position).
                set alt to pFinal:Mag - Body:Radius - geoPos:TerrainHeight.
                
                ReadoutGUI_SetText(Readouts:height, round(alt * 0.001, 1) + " km", ReadoutGUI_ColourNormal).
                ReadoutGUI_SetText(Readouts:acgx, round(targetAlt * 0.001, 1) + " km", ReadoutGUI_ColourNormal).
                if targetPos:IsType("GeoCoordinates")
                {
                    local wpBearing is vang(vxcl(up:vector, TargetPos:Position), vxcl(up:vector, Ship:Velocity:Surface)).
                    ReadoutGUI_SetText(Readouts:dist, round(targetPos:Distance * 0.001, 1) + " km", ReadoutGUI_ColourNormal).
                    ReadoutGUI_SetText(Readouts:bearing, round(wpBearing, 3) + "°", ReadoutGUI_ColourNormal).
                }

                local close is alt < targetAlt - Ship:VerticalSpeed * 8.
				if close
                {
                    if kUniverse:Timewarp:Rate <> 1
                        set kUniverse:Timewarp:Rate to 1.
					wait until Time:Seconds >= tStart + 0.2.
                }
				else
                {
                    if not rcs and kUniverse:Timewarp:Rate <> 10
                        set kUniverse:Timewarp:Rate to 10.
					wait until Time:Seconds >= tStart + 1.
                }

                callback(close).

				set lastPrediction to geoPos.
			}
		}
        
		// 60 second alignment margin
        ReadoutGUI_SetText(Readouts:status, "Wait Align", ReadoutGUI_ColourNormal).
		WaitBurn(choose 90 if spinBrake else 60, {parameter c.}).
		set kUniverse:Timewarp:Rate to 1.
		wait until kUniverse:Timewarp:Rate = 1.

		// Full retrograde burn until vertical velocity is under 30 (or fuel exhaustion).
		print "Aligning for burn".
        ReadoutGUI_SetText(Readouts:status, "Aligning", ReadoutGUI_ColourNormal).

		LAS_Avionics("activate").
		rcs on.

        if spinBrake
        {            
            local massRatio is constant:e ^ (Velocity:Surface:Mag * massflow / burnThrust).
            local finalMass is shipMass / massRatio.
            local duration is (shipMass - finalMass) / massflow.
            set downrangeAdjust to Ship:VerticalSpeed / (Ship:VerticalSpeed + duration * 0.8 * (Body:Mu / LAS_ShipPos():SqrMagnitude)).
        }

		lock steering to LookDirUp(GetBrakingAim(), Facing:UpVector).

		set navmode to "surface".

        ReadoutGUI_SetText(Readouts:status, "Wait Ignition", ReadoutGUI_ColourNormal).
        WaitBurn(EM_IgDelay(), RC@).

        print "Beginning braking burn".
        ReadoutGUI_SetText(Readouts:status, "Braking", ReadoutGUI_ColourNormal).
        ReadoutGUI_SetText(Readouts:throt, "100%", ReadoutGUI_ColourNormal).
        
        until DescentEngines[0]:Ignitions = 0 or EM_CheckThrust(0.1)
            EM_Ignition(0.1).
        
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

        until (Ship:VerticalSpeed >= targetSpeed and Ship:Velocity:Surface:Mag < -targetSpeed) or not EM_CheckThrust(0.1)
        {
            local t is Ship:Velocity:Surface:Mag * Ship:Mass / burnThrust.
            if targetPos:IsType("GeoCoordinates")
            {
                local wpBearing is vang(vxcl(up:vector, TargetPos:Position), vxcl(up:vector, Ship:Velocity:Surface)).
                ReadoutGUI_SetText(Readouts:dist, round(targetPos:Distance * 0.001, 1) + " km", ReadoutGUI_ColourNormal).
                ReadoutGUI_SetText(Readouts:bearing, round(wpBearing, 3) + "°", ReadoutGUI_ColourNormal).
                if t < 100
                {
                    local hDot is 1 - vdot(Up:Vector, Ship:Velocity:Surface:Normalized)^2.
                    local hAccel is hDot * burnThrust / Ship:Mass.
                    local dist is Ship:GroundSpeed * t - 0.5 * hAccel * t^2.
                    local drEst is targetPos:Distance - (hDot * -targetSpeed * 30 + dist).
                    
                    if t <= 60 and abs(wpBearing) < 2
                    {
                        set downrangeAdjust to 1 + max(-0.1, min((drEst - 1500) / 10000, 0.1)).
                    }
                }
            }
            
            local h is Ship:Altitude - Ship:GeoPosition:TerrainHeight.
            local acgx is -(targetSpeed^2 - Ship:VerticalSpeed^2) / (2 * h).
            local fr is (acgx + Body:Mu / Body:Position:SqrMagnitude) * Ship:Mass / burnThrust.
            
            ReadoutGUI_SetText(Readouts:height, round(h) + " m", ReadoutGUI_ColourNormal).
            ReadoutGUI_SetText(Readouts:acgx, round(acgx, 3), ReadoutGUI_ColourNormal).
            ReadoutGUI_SetText(Readouts:fr, round(fr, 3), ReadoutGUI_ColourNormal).

            local nomThrust is Ship:AvailableThrust.
            ReadoutGUI_SetText(Readouts:thrust, round(100 * min(Ship:Thrust / max(Ship:AvailableThrust, 0.001), 2), 2) + "%", 
                choose ReadoutGUI_ColourGood if Ship:Thrust > nomThrust * 0.75 else (choose ReadoutGUI_ColourNormal if Ship:Thrust > nomThrust * 0.25 else ReadoutGUI_ColourFault)).

            ReadoutGUI_SetText(Readouts:eta, round(t, 2) + " s", ReadoutGUI_ColourNormal).
            
            if spinBrake and vdot(Facing:Vector, SrfRetrograde:Vector) < 0.3
                break.
                
            if stage:number = landStage and fr < 0.8 and Ship:VerticalSpeed >= targetSpeed * 2
                break.
            
            wait 0.
        }
        
        if not EM_CheckThrust(0.1).
			print "Fuel exhaustion in braking stage".

        if stage:number > landStage
        {
            set Ship:Control:PilotMainThrottle to 0.

            // Use braking stage RCS to reorient
            wait until (Ship:VerticalSpeed <= targetSpeed * 2).

            // Jettison braking stage
            stage.
        }
	}
	else
	{
		LanderSelectWP(manualTarget).

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

    runpath("/lander/finaldescent", DescentEngines, Readouts, LanderTargetPos()).
}
