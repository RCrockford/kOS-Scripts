// Lander direct descent system, for safe(!) landings
// Two phase landing system, braking burn attempts to slow the craft to targeted vertical speed in one full thrust burn.
// Descent phase attempts a soft landing on the ground.

@lazyglobal off.

// Wait for unpack
wait until Ship:Unpacked.

parameter landStage is max(Stage:Number - 1, 0).

switch to scriptpath():volume.

// Setup functions
runpath("0:/flight/EngineMgmt", Stage:Number).

local DescentEngines is EM_GetEngines().

local burnThrust is 0.
local massFlow is 0.
for eng in DescentEngines
{
    set burnThrust to burnThrust + eng:PossibleThrust.
    set massflow to massFlow + eng:MaxMassFlow.
}

local shipMass is Ship:Mass.

// Estimates altitude at which the ship will be low the target speed based on starting immediately
local function EstimateBrakingAlt
{
	parameter vTarget is 80.
	parameter tStep is 0.5.

	local vCurrent is Ship:Velocity:Surface.
	local mCurrent is shipMass.
	local pCurrent is LAS_ShipPos().

	until vCurrent:Mag < vTarget or mCurrent < massFlow * 2
	{
		// Assume thrust is constant magntiude and retrograde
		local accel is -vCurrent:Normalized * burnThrust / mCurrent.
		local g is -pCurrent:Normalized * Ship:Body:Mu / pCurrent:SqrMagnitude.

		// Basic symplectic euler integrator
		set vCurrent to vCurrent + (accel + g) * tStep.
		set pCurrent to pCurrent + vCurrent * tStep.

		set mCurrent to mCurrent - massFlow * tStep.
	}

	return pCurrent.
}

if Ship:Status = "Flying" or Ship:Status = "Sub_Orbital" or Ship:Status = "Escaping"
{
    print "Direct descent system online.".

	local debugGui is GUI(400, 80).
    set debugGui:X to -80.
    set debugGui:Y to debugGui:Y - 480.
    local mainBox is debugGui:AddVBox().

    local debugStat is mainBox:AddLabel("h=").

	debugGui:Show().
	if Stage:Number > landStage
	{
		print "  Engine: " + DescentEngines[0]:Config + " Mass: " + round(shipMass * 1000, 1) + " kg".

		local initGrav is 1.1 - shipMass * 0.05.
		if Ship:Body:Mu / LAS_ShipPos():SqrMagnitude < initGrav
		{
			print "Waiting for initial gravity to increase to " + round(initGrav, 3) + " m/s".
			wait until Ship:Body:Mu / LAS_ShipPos():SqrMagnitude >= initGrav.
		}
		set kUniverse:Timewarp:Rate to 1.

		local function WaitBurn
		{
			parameter name.
			parameter margin.

			local lock targetAlt to 3000 + Ship:Velocity:Surface:Mag * margin.

			local alt is LAS_ShipPos():Mag.
			until alt < targetAlt
			{
				local tStart is Time:Seconds.
				local pFinal is EstimateBrakingAlt().
				local geoPos is Ship:Body:GeoPositionOf(pFinal).
				set alt to pFinal:Mag - Ship:Body:Radius - geoPos:TerrainHeight.

				set debugStat:Text to name + ", Target Alt: " + round(alt * 0.001, 1) + " / " + round(targetAlt * 0.001, 1) + " km".

				if alt > targetAlt + Ship:Velocity:Surface:Mag * 2
					wait until Time:Seconds >= tStart + 1.
				else
					wait until Time:Seconds >= tStart + 0.25.
			}
		}

		// 60 second alignment margin
		WaitBurn("Align", 60).
		set kUniverse:Timewarp:Rate to 1.
		wait until kUniverse:Timewarp:Rate = 1.

		// Full retrograde burn until vertical velocity is under 150 (or fuel exhaustion).
		print "Aligning for burn".

		LAS_Avionics("activate").
		rcs on.
		lock steering to LookDirUp(SrfRetrograde:Vector, Facing:UpVector).

		// Use SAS for braking alignment
		set navmode to "surface".
		sas on.
		wait 0.1.
		set sasmode to "retrograde".

		WaitBurn("Ignition", EM_IgDelay()).

		print "Beginning braking burn".
		EM_Ignition().

		sas off.

		wait until Ship:Velocity:Surface:Mag < 30 or not EM_CheckThrust(0.1).

		if not EM_CheckThrust(0.1)
			print "Fuel exhaustion in braking stage".

		// Jettison braking stage
		set Ship:Control:PilotMainThrottle to 0.
		stage.
	}

	wait until stage:ready.

	set Ship:Type to "Lander".
	lock steering to LookDirUp(SrfRetrograde:Vector, Facing:UpVector).

	set navmode to "surface".

    // Cache ship bounds
    local shipBounds is Ship:Bounds.

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

	set burnThrust to 0.
	for eng in DescentEngines
	{
		set burnThrust to burnThrust + eng:PossibleThrust.
		eng:Activate.
	}

    print "Descent mode active".

    // Touchdown speed
    local vT is 0.5.

    when Alt:Radar < 200 then { legs on. gear on. }

    // For throttling engines
    //local hFactor is MIN(1+(4-sqrt(minThrottle))/h^0.33,1.4)

    // For non-throttling engines
    local twr is max(burnThrust / (Ship:Mass * Ship:Body:Mu / LAS_ShipPos():SqrMagnitude), 1).

    local hFactor is 1 + 3.2 / shipBounds:BottomAltRadar^(0.75 / sqrt(twr)).

    print "TWR=" + round(twr, 2) + " hF=" + round(hFactor, 3).

    until shipBounds:BottomAltRadar < 2
    {
        local accel is burnThrust / Ship:Mass.
        local localGrav is Ship:Body:Mu / LAS_ShipPos():SqrMagnitude.
        local targetAccel is -localGrav.
        local h is shipBounds:BottomAltRadar - 2.

        // Predicted landing time (this is a root of the vertical motion quadratic, with acceleration set to gravity).
        local t is (-Ship:VerticalSpeed - sqrt(Ship:VerticalSpeed^2 - 2 * h * targetAccel)) / targetAccel.

        // Commanded vertical acceleration.
        local acgx is (-((h^hFactor) * 0.01 + vT) - Ship:VerticalSpeed) / t.

        // Thrust if commanded accel is high enough
        local fr is (acgx + localGrav) / accel.
        // A little hysteresis, keep speed below 220 m/s
        if fr > (0.9 - Ship:Control:PilotMainThrottle * 0.05) or (Ship:VerticalSpeed < -220 + Ship:Control:PilotMainThrottle * 40)
            set Ship:Control:PilotMainThrottle to 1.
        else
            set Ship:Control:PilotMainThrottle to 0.

        set debugStat:Text to "h=" + round(h, 1) + " t=" + round(t, 2) + " acgx=" + round(acgx, 3) + " fr=" + round(fr, 3).
        wait 0.
    }

	lock steering to LookDirUp(Up:Vector, Facing:UpVector).
	sas off.

	until Ship:Status = "landed"
    {
		set Ship:Control:PilotMainThrottle to Ship:VerticalSpeed < -(1 - Ship:Control:PilotMainThrottle * 0.5).
		wait 0.
	}

    print "Touchdown speed: " + round(-Ship:VerticalSpeed, 2) + " m/s".

    set Ship:Control:PilotMainThrottle to 0.
    list engines in DescentEngines.
    for eng in DescentEngines
		eng:Shutdown.
		
	wait 1.

    // Maintain attitude control until ship settles to prevent roll overs.
    wait until Ship:Velocity:Surface:SqrMagnitude < 0.01 and Ship:AngularVel:Mag < 0.001.

    unlock steering.
    set Ship:Control:Neutralize to true.
    rcs off.

    LAS_Avionics("shutdown").
	ClearGUIs().

    print "Landing completed".
}
