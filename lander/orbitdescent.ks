// Lander descent system, for safe(!) landings
// Two phase landing system, approach mode attempts to slow the craft to <20 m/s ground speed and targeted vertical speed in one full thrust burn.
// Descent phase attempts a soft landing on the ground.

@clobberbuiltins on.
@lazyglobal off.

// Wait for unpack
wait until Ship:Unpacked.

switch to scriptpath():volume.
Core:Part:ControlFrom().

parameter params is lexicon().

local targetAlt is choose params:targetAlt if params:HasKey("TargetAlt") else 0.
local distanceFactor is choose params:distFact if params:HasKey("distFact") else 0.92.
local angleGate is choose params:angleGate if params:HasKey("angleGate") else 0.1.
local heightGate is choose params:heightGate if params:HasKey("heightGate") else 6000.
local manualTarget is choose params:target if params:HasKey("target") else 0.

set angleGate to max(0.001, min(angleGate, 0.5)).
set heightGate to max(heightGate, 1000).

ClearGUIs().

// Setup functions
runoncepath("/fcfuncs").
runoncepath("/flight/tunesteering").
runpath("/flight/enginemgmt", Stage:Number).
runoncepath("/lander/landersteering").
set steeringmanager:maxstoppingtime to 2.

local DescentEngines is EM_GetEngines().
local enginesIgnited is false.
local abortMode is false.
local hasGimbal is false.

local FuelEngines is DescentEngines:Copy.
if DescentEngines:Length > 0
{
    if not DescentEngines[0]:Ullage and DescentEngines[0]:PressureFed
        set enginesIgnited to false.
    else
        set enginesIgnited to DescentEngines[0]:Ignition.
}

for eng in Ship:RCS
{
    if eng:ForeByThrottle
        FuelEngines:Add(eng).
}

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
local onTarget is false.

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
            local maxFuelFlow is 0.
            if res:HasSuffix("MaxFuelFlow")
                set maxFuelFlow to res:MaxFuelFlow.
            else
                set maxFuelFlow to eng:MaxFuelFlow * res:Ratio.
            if MaxFuelFlow > 0
            {
                if resStats:HasKey(res:Name)
                    set resStats[res:Name]:maxflow to resStats[res:Name]:maxflow + MaxFuelFlow.
                else
                    resStats:Add(res:Name, lexicon("name", res:Name, "maxflow", MaxFuelFlow, "amount", 0, "tanks", list())).
            }
        }
        set engMassflow to engMassflow + eng:MaxMassFlow.
        if eng:HasSuffix("PossibleThrust")
            set burnThrust to burnThrust + eng:PossibleThrust.
        else
            set burnThrust to burnThrust + eng:AvailableThrust.
        if eng:HasSuffix("HasGimbal")
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
    
    local residuals is 0.
    if engList[0]:HasSuffix("Residuals")
        set residuals to engList[0]:Residuals * fuelCapacity.
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
    
    GatherFuelStatus(FuelEngines).

    print "Distance gate: " + round((burnThrust / Ship:Mass) / distanceFactor, 3).

    if HasTarget and manualTarget:IsType("Scalar")
        set manualTarget to Target.

    LanderSelectWP(manualTarget).
    local targetPos is LanderTargetPos().
    
    // Target height and vertical velocity at approach terminus
    local rT0 is 80.
    local vT is choose -4 if targetPos:IsType("GeoCoordinates") else -8.
    
    {
        local fuelStatus is CurrentFuelStatus(FuelEngines).
        print "Monitor Fuel: " + monitorFuel:Name + " Δv=" + round(fuelStatus[1], 1) + " fuel=" + round(fuelStatus[0] * 100, 1) + "% t=" + round(fuelStatus[2], 2).
    }

    local f is Ship:Facing:ForeVector.
    local prevH is 0.
    local prevAlt is 0.

    local steeringControl is -2.
    
    local bingoFuel is false.
    local ΔVmargin is 2 * sqrt(2 * rT0 / (Body:Mu / Body:Position:SqrMagnitude)) * (Body:Mu / Body:Position:SqrMagnitude).
    
    runpath("/lander/landerthrottle", DescentEngines).
    
    if enginesIgnited
        LanderEnginesOn().

    runoncepath("/mgmt/readoutgui").
    local readoutGui is RGUI_Create().
    readoutGui:SetColumnCount(80, 3).

    local Readouts is lexicon().

    Readouts:Add("height", readoutGui:AddReadout("Height")).
    Readouts:Add("acgx", readoutGui:AddReadout("Acgx")).
    Readouts:Add("eta", readoutGui:AddReadout("ETA")).

    Readouts:Add("acgz", readoutGui:AddReadout("Acgz")).
    Readouts:Add("accz", readoutGui:AddReadout("Accz")).
    Readouts:Add("fr", readoutGui:AddReadout("Fr")).

    Readouts:Add("throt", readoutGui:AddReadout("Throttle")).
    Readouts:Add("thrust", readoutGui:AddReadout("Thrust")).
    Readouts:Add("status", readoutGui:AddReadout("Engines")).

    Readouts:Add("Δv", readoutGui:AddReadout("Δv")).
    Readouts:Add("margin", readoutGui:AddReadout("Margin")).
    Readouts:Add("fuel", readoutGui:AddReadout("Fuel")).

    if targetPos:IsType("GeoCoordinates")
    {
        Readouts:Add("dist", readoutGui:AddReadout("Distance")).
        Readouts:Add("bearing", readoutGui:AddReadout("Bearing")).
        Readouts:Add("steermul", readoutGui:AddReadout("Steer")).
    }

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
        local fuelStatus is CurrentFuelStatus(FuelEngines).

        // Commanded acceleration.
        local acgz is accel:z.
        local unclampedacgz is acgz.

        // Predicted terminal time
        local t is max(-Ship:GroundSpeed / acgz, -fuelStatus[2]).
        local h is Ship:Altitude - Ship:GeoPosition:TerrainHeight.
        local rT is rT0 + Velocity:Surface:Mag * 2.
        
        if targetPos:IsType("GeoCoordinates")
        {
            set wpBearing to vang(vxcl(up:vector, TargetPos:Position), vxcl(up:vector, Ship:Velocity:Surface)).
            set targetDist to max(targetPos:AltitudePosition(Ship:Altitude):Mag + vT, 1).
            set unclampedacgz to Ship:GroundSpeed^2 / (2 * targetDist).
            if not (maintainH:Pressed or maintainAlt:Pressed or ignoreTarget:Pressed or bingoFuel)
            {
                if h > 1000
                    set h to Ship:Altitude - TargetPos:TerrainHeight.
                else
                    set h to min(h, Ship:Altitude - TargetPos:TerrainHeight).
                if abs(wpBearing) < 3 and enginesIgnited
                {
                    set acgz to min(unclampedacgz, accel:z).
                    set rT to rT0 + max(0, min(targetDist, 100000)) ^ 0.65.
                }
            }
        }
        set h to min(h, Ship:Altitude - targetAlt).

        local acgxH is 0.
        local acgxV is 0.

        if maintainAlt:Pressed and not bingoFuel
        {
            local responseT is -16.
            set acgxH to 12 * (prevAlt - Ship:Altitude) / (responseT*responseT).
            set acgxV to 6 * Ship:VerticalSpeed / responseT.
        }
        else if maintainH:Pressed and not bingoFuel
        {
            local responseT is -8.
            set acgxH to 12 * (prevH - h) / (responseT*responseT).
            set acgxV to 6 * Ship:VerticalSpeed / responseT.
        }
        else
        {
            set acgxH to 12 * (rT - h) / (t*t).
            set acgxV to 6 * (Ship:VerticalSpeed - vT) / t.
        }

        local acgx is acgxH + acgxV.
        
        if not bingoFuel and Ship:Velocity:Surface:Mag > 50
        {
            local clearHeight is Ship:GeoPosition:TerrainHeight.
            from {local x is 0.25. } until x > 2.5 step { set x to x + 0.25. } do
            {
                set clearHeight to max(clearHeight, Body:GeopositionOf(Velocity:Surface * x):TerrainHeight).
            }
            local minHeight is (clearHeight - Ship:GeoPosition:TerrainHeight) + Ship:Velocity:Surface:Mag * 0.2 - min(Ship:VerticalSpeed, 0).
            // Maintain clearance from terrain
            local responseT is -12.
            set acgxH to 12 * (minHeight - h) / (responseT^2) + 6 * Ship:VerticalSpeed / responseT.
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
        
        if abs(wpBearing) < 0.01 and targetDist < 10000
            set onTarget to true.
        
        local steerMul is max(0.05, min(25 / sqrt(targetDist), 0.6)).
        if bingoFuel or abs(wpBearing) > 20 or targetDist < 500
            set steerMul to 0.
        else if onTarget
            set steerMul to steerMul / 8.
        local steerData is LanderSteering(-Body:Position, Ship:Velocity:Surface, steerMul).
        local steerVec is steerData:vec.

        // Calcuate new facing
        local omega is vcrs(-Body:Position, Ship:Velocity:Orbit):Mag / Body:Position:SqrMagnitude.
        local localGrav is Ship:Body:Mu / Body:Position:SqrMagnitude - (omega * omega) * Body:Position:Mag.
        local acg is accel:y.
        if acgz < accel:z
            set acg to min(sqrt((max(max(acgx, acgxH) + localGrav, 0))^2 + acgz^2), accel:y).
        local fr is (max(acgx, acgxH) + localGrav) / acg.
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
        
        RGUI_SetText(Readouts:height, round(h, 1) + " m", choose RGUI_ColourGood if acgxH < acgx else RGUI_ColourFault).
        RGUI_SetText(Readouts:acgx, round(acgx, 4), RGUI_ColourNormal).
        RGUI_SetText(Readouts:eta, round(-t, 1) + "s", RGUI_ColourNormal).

        
        RGUI_SetText(Readouts:acgz, round(unclampedacgz, 3), RGUI_ColourNormal).
        RGUI_SetText(Readouts:accz, round(accel:z, 3), RGUI_ColourNormal).
        RGUI_SetText(Readouts:fr, round(fr, 3), RGUI_ColourNormal).

        RGUI_SetText(Readouts:Δv, round(fuelStatus[1], 1) + " m/s", RGUI_ColourNormal).
        RGUI_SetText(Readouts:margin, round(fuelStatus[1]  - (Ship:Velocity:Surface:Mag + ΔVmargin), 1) + " m/s", RGUI_ColourNormal).

        if not bingoFuel and fuelStatus[1] < Ship:Velocity:Surface:Mag + ΔVmargin
        {
            set bingoFuel to true.
            print "Bingo Fuel".
            set maintainAlt:enabled to false. set maintainAlt:pressed to false.
            set maintainH:enabled to false. set maintainH:pressed to false.
            set ignoreTarget:enabled to false. set ignoreTarget:pressed to true.
        }
        
        RGUI_SetText(Readouts:fuel, round(fuelStatus[0] * 100, 1) + "% " + round(fuelStatus[2], 1) + "s", choose RGUI_ColourFault if bingoFuel else RGUI_ColourGood).

        RGUI_SetText(Readouts:throt, round(100 * acg / accel:y, 1) + "%", RGUI_ColourNormal).
        
        local thrustData is LanderCalcThrust(FuelEngines).        
        RGUI_SetText(Readouts:thrust, round(100 * min(thrustData:current / max(LanderMaxThrust(), 0.001), 2), 2) + "%", 
            choose RGUI_ColourGood if thrustData:current > thrustData:nominal * 0.75 else
            (choose RGUI_ColourNormal if thrustData:current > thrustData:nominal * 0.25 else RGUI_ColourFault)).
        
        if enginesIgnited and thrustData:current < thrustData:nominal * 0.25
        {
            if Time:Seconds - engFailTime > 1
            {
                RGUI_SetText(Readouts:status, "Failed", RGUI_ColourFault).
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
            RGUI_SetText(Readouts:status, "Nominal", RGUI_ColourGood).
            set engFailTime to Time:Seconds.
        }
        else
        {
            RGUI_SetText(Readouts:status, "Inactive", RGUI_ColourNormal).
        }

        if targetPos:IsType("GeoCoordinates")
        {
            set targetDist to targetPos:AltitudePosition(Ship:Altitude):Mag.
            RGUI_SetText(Readouts:dist, round(targetDist * 0.001, 2) + " km", RGUI_ColourNormal).
            RGUI_SetText(Readouts:bearing, round(wpBearing, 3) + "°", choose RGUI_ColourNormal if wpBearing < 2.5 else RGUI_ColourFault).
            RGUI_SetText(Readouts:steermul, round(steerData:f, 4), RGUI_ColourNormal).
        }
        
        local distanceGate is false.
        local periapsisGate is false.

        if not enginesIgnited
        {
            if targetPos:IsType("GeoCoordinates")
            {
                if steeringControl > 0
                    set distanceGate to unclampedacgz > accel:z / distanceFactor.
                else
                    set distanceGate to unclampedacgz > accel:z / (distanceFactor * 1.2).
            }
            else
            {
                if steeringControl > 0
                    set periapsisGate to eta:Periapsis < -t * 0.5.
                else
                    set periapsisGate to eta:Periapsis < -t * 0.65.
            }
        }
        
        // When the commanded attitude is sufficiently vertical, engage attitude control.
        // Allowing a free float before this reduces thruster propellant consumption.
        if steeringControl <= 0
        {
            if fr > max(angleGate - 0.05, 0) or h <= heightGate * 1.25 or distanceGate or periapsisGate
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
            if (not enginesIgnited) and vdot(f, Ship:Facing:ForeVector) > 0.998 and (fr > angleGate or h < heightGate or distanceGate or periapsisGate)
            {
                if fr > angleGate
                    print "Reached angle gate".
                if h < heightGate
                    print "Reached height gate".
                if distanceGate
                    print "Reached distance gate".
                if periapsisGate
                    print "Reached periapsis gate".
                EM_Ignition().
                LanderEnginesOn().
                set enginesIgnited to true.
            }
        }

        wait 0.
    }
    
    print "Ground Speed: " + round(ship:GroundSpeed, 3).
    print "Vertical Speed: " + round(ship:VerticalSpeed, 3).
    
    if DescentEngines:Length > 0 and DescentEngines[0]:Ignitions > 10 or DescentEngines[0]:Ignitions < 0
    {
        LanderEnginesOff().
    }
    else
    {
        LanderSetThrottle(0).
    }
    
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
        runpath("/lander/finaldescent", DescentEngines, Readouts, targetPos, stage:number > 0, ignoreTarget).

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
