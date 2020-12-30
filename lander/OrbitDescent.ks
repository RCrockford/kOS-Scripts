// Lander descent system, for safe(!) landings
// Two phase landing system, approach mode attempts to slow the craft to <20 m/s ground speed and targeted vertical speed in one full thrust burn.
// Descent phase attempts a soft landing on the ground.

@lazyglobal off.

// Wait for unpack
wait until Ship:Unpacked.

switch to scriptpath():volume.

parameter angleGate is 0.1.
parameter heightGate is 8000.

set angleGate to max(0.001, min(angleGate, 0.5)).
set heightGate to max(heightGate, 1000).

ClearGUIs().

// Setup functions
runoncepath("/FCFuncs").
runoncepath("/flight/TuneSteering").
set steeringmanager:TorqueEpsilonMin to 0.
set steeringmanager:TorqueEpsilonMax to 1e-6.
runpath("/flight/EngineMgmt", Stage:Number).
runoncepath("/lander/LanderSteering").

local DescentEngines is EM_GetEngines().
local enginesIgnited is DescentEngines[0]:Ignition.
local abortMode is false.

local function GetConnectedTanks
{
    parameter p.
    parameter res.
    parameter seen.

    if p:FuelCrossfeed or seen:Length = 1
    {
		for r in p:resources
		{
			if r:Enabled and res:HasKey(r:name)
            {
                set res[r:name]:Amount to res[r:name]:Amount + r:Amount.
                res[r:name]:Tanks:Add(p).
            }
		}
	}	
	
    seen:Add(p).
	
	if p:FuelCrossfeed
	{
        if p:HasParent and not seen:contains(p:parent)
        {
            GetConnectedTanks(p:parent, res, seen).
        }
        for c in p:children
        {
            if not seen:contains(c)
                GetConnectedTanks(c, res, seen).
        }
    }
}

local monitorFuel is 0.
local engMassflow is 0.
local burnThrust is 0.

local function GatherFuelStatus
{
    local resStats is lexicon().
    set engMassflow to 0.
    set burnThrust to 0.

    for eng in DescentEngines
    {
        for k in eng:ConsumedResources:keys
        {
            local res is eng:ConsumedResources[k].
            if res:MaxFuelFlow > 0
            {
                if resStats:HasKey(res:Name)
                    set resStats[res:Name]:maxflow to resStats[res:Name]:maxflow + res:MaxFuelFlow.
                else
                    resStats:Add(res:Name, lexicon("name", res:Name, "maxflow", res:MaxFuelFlow, "amount", 0, "tanks", list())).
            }
        }
        set engMassflow to engMassflow + eng:MaxMassFlow.
        set burnThrust to burnThrust + eng:PossibleThrust.
    }
    
    GetConnectedTanks(DescentEngines[0], resStats, uniqueset()).
    
    local minBurnTime is 1e6.
    for k in resStats:Keys
    {
        local res is resStats[k].
        local burnTime is res:Amount / res:MaxFlow.
        if burnTime < minBurnTime
        {
            set minBurnTime to burnTime.
            set monitorFuel to res.
        }
    }
}

local function CurrentFuelStatus
{
    local fuelAmount is 0.
    local fuelCapacity is 0.
    
    for t in monitorFuel:Tanks
    {
        for r in t:resources
		{
			if r:Enabled and r:name = monitorFuel:Name
            {
                set fuelAmount to fuelAmount + r:Amount.
                set fuelCapacity to fuelCapacity + r:Capacity.
                break.
            }
		}
    }

    local t is fuelAmount / monitorFuel:MaxFlow.
    local ΔV is (burnThrust / engMassflow) * ln(Ship:Mass / (Ship:Mass - engMassflow * t)).
    
    return list(fuelAmount / fuelCapacity, ΔV, t).
}

local function GetCurrentAccel
{
    parameter f.
    // Current ship accel
    local accel is V(0, burnThrust / Ship:Mass, 0).
    set accel:x to accel:y * vdot(f, Up:Vector).
    set accel:z to sqrt(max(accel:y * accel:y - accel:x * accel:x, 1e-4)).

    return accel.
}

if Ship:Status = "Flying" or Ship:Status = "Sub_Orbital" or Ship:Status = "Orbiting"
{
    print "Lander descent system online.".
    print "Angle gate: " + round(angleGate, 2).
    print "Height gate: " + round(heightGate, 0).

    GatherFuelStatus().

    // Target height and vertical velocity at approach terminus
    local rT is 50.
    // Target vel is speed at 45° angle for full throttle descent, safety margin provided by increasing TWR.
    local vT is -sqrt(rT * sqrt(2) * (GetCurrentAccel(Up:Vector):y - Body:Mu / Body:Position:SqrMagnitude)).
    print "Target velocity: " + round(vT, 2).
    if DescentEngines[0]:MinThrottle > 0.9
        set rT to rT * 2.
    
    {
        local fuelStatus is CurrentFuelStatus().
        print "Monitor Fuel: " + monitorFuel:Name + " Δv=" + round(fuelStatus[1], 1) + " fuel=" + round(fuelStatus[0] * 100, 1) + "% t=" + round(fuelStatus[2], 2).
    }

    local f is Ship:Facing:ForeVector.
    local prevH is 0.
    local prevAlt is 0.

    local steeringControl is -2.
    
    local bingoFuel is false.
    local ΔVmargin is 2 * sqrt(2 * rT / (Body:Mu / Body:Position:SqrMagnitude)) * (Body:Mu / Body:Position:SqrMagnitude).
    
    runoncepath("/lander/LanderThrottle", DescentEngines).

    LanderSelectWP().
    local targetPos is LanderTargetPos().

    local debugGui is GUI(400, 80).
    set debugGui:X to 160.
    set debugGui:Y to debugGui:Y + 240.
    local mainBox is debugGui:AddVBox().
    local debugStat is mainBox:AddLabel("Init").
    local debugStat2 is mainBox:AddLabel("").
    local debugStat3 is choose mainBox:AddLabel("") if targetPos:IsType("GeoCoordinates") else 0.
    local maintainAlt is mainBox:AddCheckBox("Maintain Altitude", false).
    local maintainH is mainBox:AddCheckBox("Maintain Height", false).
    local ignoreTarget is mainBox:AddCheckBox("Ignore target", false).
	debugGui:Show().

    until Ship:GroundSpeed < -vT
    {
        local accel is GetCurrentAccel(f).

        // Commanded acceleration.
        local acgx is 0.
        local acgz is accel:z.
        local unclampedacgz is acgz.
        local targetDist is 1.

        if targetPos:IsType("GeoCoordinates") and not (maintainH:Pressed or maintainAlt:Pressed or ignoreTarget:Pressed or bingoFuel)
        {
            local wpBearing is vang(vxcl(up:vector, TargetPos:Position), vxcl(up:vector, Ship:Velocity:Surface)).
            set targetDist to max(targetPos:AltitudePosition(Ship:Altitude):Mag + vT, 1).
            set unclampedacgz to Ship:GroundSpeed^2 / (2 * targetDist).
            if abs(wpBearing) < 1 and enginesIgnited
                set acgz to min(unclampedacgz, accel:z).
        }

        // Predicted terminal time
        local t is -Ship:GroundSpeed / acgz.
        local h is Ship:Altitude - Ship:GeoPosition:TerrainHeight.

        if maintainAlt:Pressed and not bingoFuel
        {
            local responseT is -16.
            set acgx to 12 * (prevAlt - Ship:Altitude) / (responseT*responseT) + 6 * Ship:VerticalSpeed / responseT.
        }
        else if maintainH:Pressed and not bingoFuel
        {
            local responseT is -8.
            set acgx to 12 * (prevH - h) / (responseT*responseT) + 6 * Ship:VerticalSpeed / responseT.
        }
        else
        {
            set acgx to 12 * (rT - h) / (t*t) + 6 * (vT + Ship:VerticalSpeed) / t.
        }
        
        if not maintainH:Pressed and not bingoFuel
        {
            // Maintain clearance from terrain
            local responseT is -12.
            local acgxH is 12 * (2 * Ship:Velocity:Surface:Mag - h) / (responseT^2) + 6 * Ship:VerticalSpeed / responseT.
            set acgx to max(acgx, acgxH).
        }

        if not maintainH:Pressed
        {
            set prevH to max(h, rT).
            set maintainH:Text to "Maintain Height: " + round(prevH, 0).
        }
        if not maintainAlt:Pressed
        {
            set prevAlt to Ship:Altitude.
            set maintainAlt:Text to "Maintain Altitude: " + round(prevAlt, 0).
        }
        
        local steerVec is LanderSteering(-Body:Position, Ship:Velocity:Surface, min(25 / sqrt(targetDist), 1)).

        // Calcuate new facing
        local omega is vcrs(-Body:Position, Ship:Velocity:Orbit):Mag / Body:Position:SqrMagnitude.
        local localGrav is Ship:Body:Mu / Body:Position:SqrMagnitude - (omega * omega) * Body:Position:Mag.
        local acg is accel:y.
        if acgz < accel:z
            set acg to min(sqrt((acgx + localGrav)^2 + acgz^2), accel:y).
        local fr is (acgx + localGrav) / acg.
        set fr to min(max(fr, 0), 0.999).

        // No horizontal throttling while in glide modes.
        if (maintainH:Pressed or maintainAlt:Pressed) and enginesIgnited
        {
            set f to Up:Vector.
            LanderSetThrottle(fr).
        }
        else
        {
            set f to fr * Up:Vector + sqrt(1 - fr * fr) * steerVec.
            if enginesIgnited
                LanderSetThrottle(acg / accel:y).
        }

        set debugStat:Text to "h=" + round(h, 1) + " t=" + round(-t, 2) + " acgx=" + round(acgx, 3) + " fr=" + round(fr, 3) + " f=" + round(vdot(f, Ship:Facing:ForeVector), 4).
        
        local fuelStatus is CurrentFuelStatus().
        local debugStr is "acgz=" + round(unclampedacgz, 3) + " / " + round(accel:z, 3) + " thr=" + round(acg / accel:y, 3) + " Δv=" + round(fuelStatus[1], 1) + " fuel=" + round(fuelStatus[0] * 100, 1) + "%".
        
        if not bingoFuel and fuelStatus[1] < Ship:Velocity:Surface:Mag + ΔVmargin
        {
            set bingoFuel to true.
            print "Bingo Fuel".
            set maintainAlt:enabled to false. set maintainAlt:pressed to false.
            set maintainH:enabled to false. set maintainH:pressed to false.
            set ignoreTarget:enabled to false. set ignoreTarget:pressed to true.
        }
        
        if enginesIgnited and Ship:Control:PilotMainThrottle > 0 and not EM_CheckThrust(0.25 * Ship:Control:PilotMainThrottle)
        {
            if stage:number > 0
            {
                set abortMode to true.
                print "Detected engine failure, aborting!".
                break.
            }
            else
            {
                set debugStr to debugStr + " <color=#ff8000>Engine Failure!</color>".
            }
        }

        set debugStat2:Text to debugStr.

        if targetPos:IsType("GeoCoordinates")
        {
            local wpBearing is vang(vxcl(up:vector, TargetPos:Position), vxcl(up:vector, Ship:Velocity:Surface)).
            local dist is targetPos:AltitudePosition(Ship:Altitude):Mag.
            set debugStat3:Text to "Dist=" + round(dist * 0.001, 2) + " km" + " Bearing=" + round(wpBearing, 2) + "° (" + round(sin(wpBearing) * dist, 1)  + " m)".
        }
        
        local distanceGate is false.
        if not enginesIgnited and targetPos:IsType("GeoCoordinates")
        {
            set distanceGate to unclampedacgz > accel:z * 1.1.
        }
        
        // When the commanded attitude is sufficiently vertical, engage attitude control.
        // Allowing a free float before this reduces thruster propellant consumption.
        if steeringControl <= 0
        {
            if fr >= angleGate or h <= heightGate or distanceGate
            {
                set kUniverse:Timewarp:Rate to 1.
                set steeringControl to steeringControl + 1.
                if steeringControl > 0
                {
                    print "Approach mode active".
                    LAS_Avionics("activate").
                    rcs on.
                    lock steering to LookDirUp(f, Facing:UpVector).
                }
            }
            else
            {
                set steeringControl to -2.
            }
        }
        else
        {
            // If engines aren't lit and we're facing (more or less) in the correct direction, light them.
            if (not enginesIgnited) and vdot(f, Ship:Facing:ForeVector) > 0.998 and (fr > angleGate or h < heightGate or distanceGate)
            {
                if fr > angleGate
                    print "Reached angle gate".
                if h < heightGate
                    print "Reached height gate".
                if distanceGate
                    print "Reached distance gate".
                EM_Ignition().
                set enginesIgnited to true.
            }
        }

        wait 0.
    }
    
    runpath("/lander/FinalDescent", DescentEngines, debugStat, targetPos, stage:number > 0).
    
    if Ship:VerticalSpeed < -5
        set abortMode to true.
    else
        ladders on.
}
else
{
    print "Ship status: " + Ship:Status.
}

if abortMode
{
    for eng in DescentEngines
        eng:ShutDown.

    lock Steering to LookDirUp(Up:Vector, Facing:UpVector).
    set Ship:Control:PilotMainThrottle to 0.
    
    stage.
    
    EM_Ignition().
	
    legs off. gear off.

    global LAS_TargetPe is 50.
    global LAS_TargetAp is max(Ship:Orbit:Apoapsis / 1000, 50).

    runpath("/launch/OrbitalGuidance", stage:number).

    // Trigger flight control
    if Ship:Body:Atm:Exists
    {
        set pitchOverSpeed to LAS_GetPartParam(Ship:RootPart, "spd=", 50).
        set pitchOverAngle to LAS_GetPartParam(Ship:RootPart, "ang=", 3).

        runpath("/launch/FlightControlPitchOver", pitchOverSpeed, pitchOverAngle, mod(360 - latlng(90,0):bearing, 360)).
    }
    else
    {
        runpath("/launch/FlightControlNoAtm", mod(360 - latlng(90,0):bearing, 360)).
    }
}
