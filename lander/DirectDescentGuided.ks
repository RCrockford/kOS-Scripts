// Lander direct descent system, for safe(!) landings
// Two phase landing system, braking burn attempts to slow the craft to targeted vertical speed in one full thrust burn.
// Descent phase attempts a soft landing on the ground.

@lazyglobal off.

// Wait for unpack
wait until Ship:Unpacked.

parameter burnAlt is -1.

switch to 0.

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
		
		local function WaitBurn
		{
			parameter name.
			parameter margin.

			until Alt:Radar < d + Ship:Velocity:Surface:Mag * margin
			{
				set debugStat:Text to name + " at " + round((d + Ship:Velocity:Surface:Mag * margin) * 0.001, 1) + "km".
				local t is time:seconds + 10.
				wait until Alt:Radar < d + Ship:Velocity:Surface:Mag * margin or Time:Seconds >= t.
			}
		}

		// 60 second alignment margin
		WaitBurn("Align", 60).
		set kUniverse:Timewarp:Rate to 1.

		// Full retrograde burn until vertical velocity is under 150 (or fuel exhaustion).
		print "Aligning for burn".

		LAS_Avionics("activate").
		rcs on.
		lock steering to LookDirUp(SrfRetrograde:Vector, Facing:UpVector).

		WaitBurn("Ignition", EM_IgDelay()).

		print "Beginning braking burn".
		EM_Ignition().
		
		if DescentEngines[0]:Ignitions < 0 or DescentEngines[0]:Ignitions >= 2
		{
			// Do a second burn at 5km alt then jettison and do final descent on thrusters
			wait until Ship:Velocity:Surface:Mag < 100 or not EM_CheckThrust(0.1).
			set Ship:Control:PilotMainThrottle to 0.
			
			wait until Alt:Radar < 5000.
			
			if Ship:Velocity:Surface:Mag > 150
			{
				EM_Ignition().
				wait until Ship:Velocity:Surface:Mag < 30 or not EM_CheckThrust(0.1).
                if not EM_CheckThrust(0.1)
                    print "Fuel exhaustion in braking stage".
			}
		}
		else
		{
			wait until Ship:Velocity:Surface:Mag < 30 or not EM_CheckThrust(0.1).
		}

		// Jettison braking stage
		set Ship:Control:PilotMainThrottle to 0.
		stage.
	}
	
	set Ship:Type to "Lander".	
	lock steering to LookDirUp(SrfRetrograde:Vector, Facing:UpVector).

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

    when Alt:Radar < 250 then { legs on. }

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
    
    print "Touchdown speed: " + round(-Ship:VerticalSpeed, 2) + " m/s".

    lock steering to LookDirUp(Up:Vector, Facing:UpVector).

    set Ship:Control:PilotMainThrottle to 0.
    list engines in DescentEngines.
    for eng in DescentEngines
		eng:Shutdown.

    // Maximum angular velocity before attempting to brake rotation
    local maxAngVel is 1.

    // Maintain attitude control until ship settles to prevent roll overs.
    wait until Ship:Velocity:Surface:SqrMagnitude < 0.01 and Ship:AngularVel:Mag < 0.01.
	
    unlock steering.
    set Ship:Control:Neutralize to true.
    rcs off.

    LAS_Avionics("shutdown").
	ClearGUIs().

    print "Landing completed".
}
