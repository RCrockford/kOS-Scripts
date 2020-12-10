// Lander direct descent system, for safe(!) landings
// Two phase landing system, braking burn attempts to slow the craft to targeted vertical speed in one full thrust burn.
// Descent phase attempts a soft landing on the ground.

@lazyglobal off.

// Wait for unpack
wait until Ship:Unpacked.

parameter maxRollRate is 2.
parameter burnAlt is -1.

switch to 0.

// Setup functions
runpath("0:/flight/EngineMgmt", Stage:Number - 1).

local DescentEngines is EM_GetEngines().

local burnThrust is 0.
local massFlow is 0.
for eng in DescentEngines
{
    set burnThrust to burnThrust + eng:PossibleThrust.
    set massflow to massFlow + eng:MaxMassFlow.
}

local shipMass is 0.
for shipPart in Ship:Parts
{
    local decoupleStage is shipPart:DecoupledIn.

    if shipPart:DecoupledIn < Stage:Number - 1
    {
        set shipMass to shipMass + shipPart:WetMass.
    }
}

// Estimates burn altitude to brake to a stop at sea level
local function EstimateBrakingBurnAlt
{
    parameter vInitial.

    // Initial conditions,
    local accel is -burnThrust / shipMass.
    local t is -vInitial / accel.
    local prevT is 0.
    // Surface gravity
    local g1 is Ship:Body:Mu / Ship:Body:Radius^2.
    // burn start altitude
    local d is vInitial * t + accel * t^2 / 2.

    until abs(t - prevT) < 0.01
    {
        // burn start gravity
        local g0 is Ship:Body:Mu / (d + Ship:Body:Radius)^2.

        // final mass
        local mf is shipMass - massFlow * t.

        // accel at start and end of burn
        local a0 is (burnThrust / shipMass - g0)^2.
        local a1 is (burnThrust / mf - g1)^2.

        // Root of harmonic mean of squares
        set accel to -sqrt(2 * a0 * a1 / (a0 + a1)).

        // New time estimate
        set prevT to t.
        set t to -vInitial / accel.

        // New distance estimate
        set d to vInitial * t + accel * t^2 / 2.
    }

    return d.
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
	if Stage:Number > 0
	{
		print "  Engine: " + DescentEngines[0]:Config + " Mass: " + round(shipMass * 1000, 1) + " kg".
		
		if Ship:Body:Mu / LAS_ShipPos():SqrMagnitude < 1
		{
			print "Waiting for initial gravity to increase".
			wait until Ship:Body:Mu / LAS_ShipPos():SqrMagnitude >= 1.
		}
		set kUniverse:Timewarp:Rate to 1.
		
		// Calculate when to start braking burn
		local vInitial is Ship:Velocity:Surface:Mag.
		local dInitial is LAS_ShipPos():Mag - Ship:Body:Radius.

		local prevD is 0.
		local d is EstimateBrakingBurnAlt(vInitial).
		
		if burnAlt > 0
		{
			set d to burnAlt * 1000.
		}
		else
		{
			until abs(d - prevD) < 50
			{
				// coast gravity
				local g is 0.5 * (Ship:Body:Mu / LAS_ShipPos():SqrMagnitude + Ship:Body:Mu / (d + Ship:Body:Radius)^2).

				// Root of the equation of ship motion under average gravity
				local t is (-vInitial + sqrt(vInitial^2 - 2 * g * (d - dInitial))) / g.

				set prevD to d.
				set d to EstimateBrakingBurnAlt(vInitial + t * g).
			}
		}

		print "Braking alt: " + round(d * 0.001, 1) + "km".

		set debugStat:Text to "Align at " + round((d + Ship:Velocity:Surface:Mag * 120) * 0.001, 1) + "km".

		// 120 second alignment margin
		wait until Alt:Radar < d + Ship:Velocity:Surface:Mag * 120.
		set kUniverse:Timewarp:Rate to 1.

		// Full retrograde burn until vertical velocity is under 50 (or fuel exhaustion).
		print "Beginning braking burn".

		LAS_Avionics("activate").
		rcs on.
		lock steering to LookDirUp(SrfRetrograde:Vector, Facing:UpVector).
		
		set debugStat:Text to "Roll at " + round((d + Ship:Velocity:Surface:Mag * 15 * maxRollRate) * 0.001, 1) + "km".
		
		wait until Alt:Radar < d + Ship:Velocity:Surface:Mag * 15 * maxRollRate and vdot(SrfRetrograde:Vector, Facing:Vector) > 0.99.

		// spin up
		set Ship:Control:Roll to -1.
		until Alt:Radar <= d + Ship:Velocity:Surface:Mag * EM_IgDelay()
		{
			local rollRate is vdot(Facing:Vector, Ship:AngularVel).
			if abs(rollRate) > maxRollRate
			{
				set Ship:Control:Roll to -0.1.
			}

			set debugStat:Text to "Roll rate: " + round(vdot(Facing:Vector, Ship:AngularVel), 2) + " / " + maxRollRate.
			
			wait 0.
		}

		set Ship:Control:Roll to -0.1.
		
		list engines in DescentEngines.
		for eng in DescentEngines
		{
			if not eng:Ullage and eng:Ignitions < 0
				eng:Activate.
		}

		EM_Ignition().

		for eng in DescentEngines
		{
			if not eng:Ullage and eng:Ignitions < 0
				eng:Shutdown.
		}

		// Jettison alignment stage.
		wait until Stage:Ready.
		stage.
		
		set Ship:Control:Neutralize to true.
		
		print "Ship Mass: " + round(Ship:Mass * 1000, 1) + " / " + round(shipMass * 1000, 1) + " kg".

		wait until Ship:Velocity:Surface:Mag < 50 or vdot(Facing:Vector, SrfRetrograde:Vector) < 0.5 or not EM_CheckThrust(0.1).	// stop burn if too far from retrograde

		// Jettison braking stage
		set Ship:Control:PilotMainThrottle to 0.
		stage.
	}
	
	set Ship:Type to "Lander".

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

    lock steering to SrfRetrograde:Vector.

    // Calculate new thrust
    list engines in DescentEngines.

    set burnThrust to 0.
    for eng in DescentEngines
    {
        set burnThrust to burnThrust + eng:PossibleThrust.
        eng:Activate.
    }

    print "Descent mode active".

    // Touchdown speed
    local vT is 0.5.

    when Alt:Radar < 100 then { legs on. }

    // For throttling engines
    //local hFactor is MIN(1+(4-sqrt(minThrottle))/h^0.33,1.4)

    // For non-throttling engines
    local twr is max(burnThrust / (Ship:Mass * Ship:Body:Mu / LAS_ShipPos():SqrMagnitude), 1).
    local hFactor is 1 + 3.2 / shipBounds:BottomAltRadar^(0.75 / sqrt(twr)).

    print "TWR=" + round(twr, 2) + " hF=" + round(hFactor, 3).

    until shipBounds:BottomAltRadar < 0.1
    {
        local accel is burnThrust / Ship:Mass.
        local localGrav is Ship:Body:Mu / LAS_ShipPos():SqrMagnitude.
        local targetAccel is -localGrav.
        local h is shipBounds:BottomAltRadar.

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
		
		if h < 2
            lock steering to LookDirUp(Up:Vector, Facing:UpVector).
    }

    lock steering to LookDirUp(Up:Vector, Facing:UpVector).

    set Ship:Control:PilotMainThrottle to 0.

    // Maximum angular velocity before attempting to brake rotation
    local maxAngVel is 1.

    // Maintain attitude control until ship settles to prevent roll overs.
    wait until Ship:Velocity:Surface:SqrMagnitude < 0.01 and Ship:AngularVel:Mag < 0.01.

    list engines in DescentEngines.
    for eng in DescentEngines
		eng:Shutdown.
	
    unlock steering.
    set Ship:Control:Neutralize to true.
    rcs off.

    LAS_Avionics("shutdown").

    print "Landing completed".
}
