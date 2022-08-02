// Lander descent system, for safe(!) landings
// Two phase landing system, approach mode attempts to slow the craft to <20 m/s ground speed and targeted vertical speed in one full thrust burn.
// Descent phase attempts a soft landing on the ground.

@lazyglobal off.

// Wait for unpack
wait until Ship:Unpacked.

switch to scriptpath():volume.
Core:Part:ControlFrom().

parameter angleGate is 0.1.
parameter heightGate is 8000.
parameter distanceFactor is 0.92.
parameter manualTarget is 0.

set angleGate to max(0.001, min(angleGate, 0.5)).
set heightGate to max(heightGate, 1000).

ClearGUIs().

// Setup functions
runoncepath("/fcfuncs").
runoncepath("/flight/tunesteering").
runpath("/flight/enginemgmt", Stage:Number).
runoncepath("/lander/landersteering").

local DescentEngines is EM_GetEngines().
local enginesIgnited is DescentEngines[0]:Ignition.
local abortMode is false.
local hasGimbal is false.

if not DescentEngines[0]:Ullage and DescentEngines[0]:PressureFed
    set enginesIgnited to false.

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

global function GatherFuelStatus
{
    parameter engList.

    local resStats is lexicon().
    set engMassflow to 0.
    set burnThrust to 0.

    for eng in engList
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
        set hasGimbal to hasGimbal or eng:HasGimbal and eng:Gimbal:Range > 0.
    }
    
    GetConnectedTanks(engList[0], resStats, uniqueset()).
    
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

global function CurrentFuelStatus
{
    parameter engList.

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
    
    local residuals is engList[0]:Residuals * fuelCapacity.
    local t is (fuelAmount - residuals) / monitorFuel:MaxFlow.
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
    
    GatherFuelStatus(DescentEngines).

    print "Distance gate: " + round((burnThrust / Ship:Mass) / distanceFactor, 3).

    // Target height and vertical velocity at approach terminus
    local rT is 50.
    // Target vel is speed at 45° angle for full throttle descent, safety margin provided by increasing TWR.
    local vT is -sqrt(max(rT * sqrt(2) * (GetCurrentAccel(Up:Vector):y - Body:Mu / Body:Position:SqrMagnitude), 4)).
    if core:tag:contains("skycrane")
        set rT to 100.
    print "Target velocity: " + round(-vT, 2).
    
    {
        local fuelStatus is CurrentFuelStatus(DescentEngines).
        print "Monitor Fuel: " + monitorFuel:Name + " Δv=" + round(fuelStatus[1], 1) + " fuel=" + round(fuelStatus[0] * 100, 1) + "% t=" + round(fuelStatus[2], 2).
    }

    local f is Ship:Facing:ForeVector.
    local prevH is 0.
    local prevAlt is 0.

    local steeringControl is -2.
    
    local bingoFuel is false.
    local ΔVmargin is 2 * sqrt(2 * rT / (Body:Mu / Body:Position:SqrMagnitude)) * (Body:Mu / Body:Position:SqrMagnitude).
    
    runpath("/lander/landerthrottle", DescentEngines).

    if HasTarget and manualTarget:IsType("Scalar")
        set manualTarget to Target.

    LanderSelectWP(manualTarget).
    local targetPos is LanderTargetPos().
    
    runoncepath("/mgmt/readoutgui").
    local readoutGui is ReadoutGUI_Create().
    readoutGui:SetColumnCount(80, 3).

    local Readouts is lexicon().

    Readouts:Add("height", readoutGui:AddReadout("Height")).
    Readouts:Add("acgx", readoutGui:AddReadout("Acgx")).
    Readouts:Add("fr", readoutGui:AddReadout("Fr")).

    Readouts:Add("acgz", readoutGui:AddReadout("Acgz")).
    Readouts:Add("accz", readoutGui:AddReadout("Accz")).
    Readouts:Add("eta", readoutGui:AddReadout("ETA")).

    Readouts:Add("throt", readoutGui:AddReadout("Throttle")).
    Readouts:Add("thrust", readoutGui:AddReadout("Thrust")).
    Readouts:Add("status", readoutGui:AddReadout("Engines")).

    Readouts:Add("Δv", readoutGui:AddReadout("Δv")).
    Readouts:Add("margin", readoutGui:AddReadout("Margin")).
    Readouts:Add("fuel", readoutGui:AddReadout("Fuel")).

    Readouts:Add("dist", readoutGui:AddReadout("Distance")).
    Readouts:Add("bearing", readoutGui:AddReadout("Bearing")).
    Readouts:Add("steermul", readoutGui:AddReadout("Steer")).

    local maintainAlt is readoutGui:AddToggle("Maintain Altitude").
    local maintainH is readoutGui:AddToggle("Maintain Height").
    local ignoreTarget is readoutGui:AddToggle("Ignore target").
    
	readoutGui:Show().
    
    local engFailTime is 0.
    local targetDist is 1.
    local wpBearing is 180.

    until Ship:GroundSpeed < -vT * (2 - vdot(Facing:Vector, Up:Vector))
    {
        local accel is GetCurrentAccel(f).

        // Commanded acceleration.
        local acgx is 0.
        local acgz is accel:z.
        local unclampedacgz is acgz.

        // Predicted terminal time
        local t is -Ship:GroundSpeed / acgz.
        local h is Ship:Altitude - Ship:GeoPosition:TerrainHeight.
        
        if targetPos:IsType("GeoCoordinates")
        {
            set wpBearing to vang(vxcl(up:vector, TargetPos:Position), vxcl(up:vector, Ship:Velocity:Surface)).
            if not (maintainH:Pressed or maintainAlt:Pressed or ignoreTarget:Pressed or bingoFuel)
            {
                set targetDist to max(targetPos:AltitudePosition(Ship:Altitude):Mag + vT, 1).
                set unclampedacgz to Ship:GroundSpeed^2 / (2 * targetDist).
                if abs(wpBearing) < 2 and enginesIgnited
                    set acgz to min(unclampedacgz, accel:z).
                set h to Ship:Altitude - max(Ship:GeoPosition:TerrainHeight, TargetPos:TerrainHeight).
            }
        }

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
            set acgx to 12 * (rT - h) / (t*t) + 6 * (-vT + Ship:VerticalSpeed) / t.
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
        
        local steerMul is max(0.05, min(25 / sqrt(targetDist), 0.6)).
        if bingoFuel or abs(wpBearing) > 20 or targetDist < 500
            set steerMul to 0.
        local steerData is LanderSteering(-Body:Position, Ship:Velocity:Surface, steerMul).
        local steerVec is steerData:vec.

        // Calcuate new facing
        local omega is vcrs(-Body:Position, Ship:Velocity:Orbit):Mag / Body:Position:SqrMagnitude.
        local localGrav is Ship:Body:Mu / Body:Position:SqrMagnitude - (omega * omega) * Body:Position:Mag.
        local acg is accel:y.
        if acgz < accel:z
            set acg to min(sqrt((acgx + localGrav)^2 + acgz^2), accel:y).
        local fr is (acgx + localGrav) / acg.
        set fr to min(max(fr, 0), 0.9).

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
        
        ReadoutGUI_SetText(Readouts:height, round(h, 1) + " m", ReadoutGUI_ColourNormal).
        ReadoutGUI_SetText(Readouts:acgx, round(acgx, 3), ReadoutGUI_ColourNormal).
        ReadoutGUI_SetText(Readouts:fr, round(fr, 3), ReadoutGUI_ColourNormal).

        ReadoutGUI_SetText(Readouts:acgz, round(unclampedacgz, 3), ReadoutGUI_ColourNormal).
        ReadoutGUI_SetText(Readouts:accz, round(accel:z, 3), ReadoutGUI_ColourNormal).
        ReadoutGUI_SetText(Readouts:eta, round(-t, 1) + " s", ReadoutGUI_ColourNormal).

        local fuelStatus is CurrentFuelStatus(DescentEngines).

        ReadoutGUI_SetText(Readouts:Δv, round(fuelStatus[1], 1) + " m/s", ReadoutGUI_ColourNormal).
        ReadoutGUI_SetText(Readouts:margin, round(fuelStatus[1]  - (Ship:Velocity:Surface:Mag + ΔVmargin), 1) + " m/s", ReadoutGUI_ColourNormal).

        if not bingoFuel and fuelStatus[1] < Ship:Velocity:Surface:Mag + ΔVmargin
        {
            set bingoFuel to true.
            print "Bingo Fuel".
            set maintainAlt:enabled to false. set maintainAlt:pressed to false.
            set maintainH:enabled to false. set maintainH:pressed to false.
            set ignoreTarget:enabled to false. set ignoreTarget:pressed to true.
        }
        
        if bingoFuel
            ReadoutGUI_SetText(Readouts:fuel, round(fuelStatus[0] * 100, 1) + "% Bingo", ReadoutGUI_ColourFault).
        else
            ReadoutGUI_SetText(Readouts:fuel, round(fuelStatus[0] * 100, 1) + "%", ReadoutGUI_ColourGood).

        ReadoutGUI_SetText(Readouts:throt, round(100 * acg / accel:y, 1) + "%", ReadoutGUI_ColourNormal).
        
        local nomThrust is Ship:AvailableThrust * (LanderMinThrottle() + Ship:Control:PilotMainThrottle * (1 - LanderMinThrottle())).
        ReadoutGUI_SetText(Readouts:thrust, round(100 * min(Ship:Thrust / max(Ship:AvailableThrust, 0.001), 2), 2) + "%", 
            choose ReadoutGUI_ColourGood if Ship:Thrust > nomThrust * 0.75 else (choose ReadoutGUI_ColourNormal if Ship:Thrust > nomThrust * 0.25 else ReadoutGUI_ColourFault)).
        
        if enginesIgnited and Ship:Thrust < nomThrust * 0.25
        {
            if Time:Seconds - engFailTime > 1
            {
                ReadoutGUI_SetText(Readouts:status, "Failed", ReadoutGUI_ColourFault).
                if stage:number > 0
                {
                    set abortMode to true.
                    print "Detected engine failure, aborting!".
                    break.
                }
            }
        }
        else if enginesIgnited
        {
            ReadoutGUI_SetText(Readouts:status, "Nominal", ReadoutGUI_ColourGood).
            set engFailTime to Time:Seconds.
        }
        else
        {
            ReadoutGUI_SetText(Readouts:status, "Inactive", ReadoutGUI_ColourNormal).
        }

        if targetPos:IsType("GeoCoordinates")
        {
            set targetDist to targetPos:AltitudePosition(Ship:Altitude):Mag.
            ReadoutGUI_SetText(Readouts:dist, round(targetDist * 0.001, 2) + " km", ReadoutGUI_ColourNormal).
            ReadoutGUI_SetText(Readouts:bearing, round(wpBearing, 3) + "°", choose ReadoutGUI_ColourNormal if wpBearing < 2 else ReadoutGUI_ColourFault).
            ReadoutGUI_SetText(Readouts:steermul, round(steerData:f, 4), ReadoutGUI_ColourNormal).
        }
        
        local distanceGate is false.
        if not enginesIgnited and targetPos:IsType("GeoCoordinates")
        {
            if steeringControl > 0
                set distanceGate to unclampedacgz > accel:z / distanceFactor.
            else
                set distanceGate to unclampedacgz > accel:z / (distanceFactor * 1.05).
        }
        
        // When the commanded attitude is sufficiently vertical, engage attitude control.
        // Allowing a free float before this reduces thruster propellant consumption.
        if steeringControl <= 0
        {
            if fr > max(angleGate - 0.04, 0) or h <= heightGate * 1.25 or distanceGate
            {
                set kUniverse:Timewarp:Rate to 1.
                set steeringControl to steeringControl + 1.
                if steeringControl > 0
                {
                    print "Approach mode active".
                    LAS_Avionics("activate").
                    rcs on.
                    lock steering to f.
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
                LanderEnginesOn().
                set enginesIgnited to true.
            }
        }

        wait 0.
    }
    
    print "Ground Speed: " + round(ship:GroundSpeed, 3).
    print "Vertical Speed: " + round(ship:VerticalSpeed, 3).
    
    if core:tag:contains("skycrane")
    {
        set maintainAlt:enabled to false.
        set maintainH:enabled to false.
        set ignoreTarget:enabled to false.
        runpath("/lander/skycrane", DescentEngines, targetPos).
        set abortMode to false.
    }
    else
    {
        runpath("/lander/finaldescent", DescentEngines, Readouts, targetPos, stage:number > 0).

        if Ship:VerticalSpeed < -5
            set abortMode to true.
        else
            ladders on.
    }
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

    runpath("/launch/orbitalguidance", stage:number).

    // Trigger flight control
    if Ship:Body:Atm:Exists
    {
        set pitchOverSpeed to LAS_GetPartParam(Ship:RootPart, "spd=", 50).
        set pitchOverAngle to LAS_GetPartParam(Ship:RootPart, "ang=", 3).

        runpath("/launch/flightcontrolpitchover", pitchOverSpeed, pitchOverAngle, mod(360 - latlng(90,0):bearing, 360)).
    }
    else
    {
        runpath("/launch/flightcontrolnoatm", mod(360 - latlng(90,0):bearing, 360)).
    }
}
