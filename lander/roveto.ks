@clobberbuiltins on.
@lazyglobal off.

parameter maxSpeed is 5.
parameter minDist is 20.
parameter targetPoint is 0.
parameter stabilityFactor is 1.

Core:Part:ControlFrom().
clearGuis().

if abs(vdot(facing:vector, up:vector)) > 0.5
{
	print "Unable to drive using this control point".
}
else
{
switch to scriptpath():volume.

runoncepath("/fcfuncs").

if targetPoint:IsType("Scalar")
{
	local minDist is Body:Radius.

	for wp in AllWayPoints()
	{
		if wp:Body = Body
		{
			if wp:IsSelected
			{
				set targetPoint to wp.
				break.
			}
			if wp:geoPosition:Distance < minDist
			{
				set targetPoint to wp.
				set minDist to wp:geoPosition:Distance.
			}
		}
	}
}

if targetPoint:IsType("Scalar") and HasTarget
{
    set targetPoint to target.
}

local fullCharge is 1.
for r in ship:resources
{
    if r:Name = "ElectricCharge"
    {
        set fullCharge to r:Capacity.
        break.
    }
}

local targetGeoPos is targetPoint.

if targetPoint:IsType("WayPoint") or targetPoint:IsType("Vessel")
{
	print "Roving to " + targetPoint:Name.
    set targetGeoPos to targetPoint:GeoPosition.
}

local turnPid is PIDLoop(0.04, 0.0001, 0.05, -0.5, 0.5).
local steerPid is PIDLoop(3, 0.1, 0.5, -1, 1).
local throttlePid is PIDLoop(0.002, 0, 0.0025, -1, 1).

local takeoffTime is 0.
local isLanded is true.

local statusGui is Gui(400).
set statusGui:X to 160.
set statusGui:Y to statusGui:Y + 120.

local mainBox is statusGui:AddHBox().
local labelBox is mainBox:AddVBox().
set labelBox:style:width to 100.
local statusBox is mainBox:AddVBox().
set statusBox:style:width to 100.

local guiStatus is lexicon().

local function createGuiInfo
{
    parameter tagStr.
    parameter lblStr.

    local ctrl is labelBox:AddLabel(lblStr).
    set ctrl:Style:Height to 25.

    set ctrl to statusBox:AddTextField("").
    set ctrl:Style:Height to 25.
    set ctrl:Enabled to false.

    guiStatus:add(tagStr, ctrl).
}

createGuiInfo("hdg", "Heading").
createGuiInfo("spd", "Drive Speed").
createGuiInfo("dst", "Distance").
createGuiInfo("eta", "ETA").
createGuiInfo("turn", "Turn Rate").

// Second column
set labelBox to mainBox:AddVBox().
set labelBox:style:width to 100.
set statusBox to mainBox:AddVBox().
set statusBox:style:width to 100.

createGuiInfo("sv", "Last Save").
createGuiInfo("ra", "Roll Angle").
createGuiInfo("pwr", "Charge").
createGuiInfo("thr", "Throttle").
createGuiInfo("steer", "Steering").

statusGui:Show().

LAS_Avionics("activate").
set Ship:Type to "Rover".

brakes off.

local wheelList is list().
for w in Ship:ModulesNamed("KSPWheelBase")
{
	if vdot(w:part:position, facing:vector) > 0 and vdot(w:part:position, facing:starvector) > 0
	{
		wheelList:add(w:part).
		break.
	}
}
for w in Ship:ModulesNamed("KSPWheelBase")
{
	if vdot(w:part:position, facing:vector) < 0 and vdot(w:part:position, facing:starvector) > 0
	{
		wheelList:add(w:part).
		break.
	}
}
for w in Ship:ModulesNamed("KSPWheelBase")
{
	if vdot(w:part:position, facing:starvector) < 0
	{
		wheelList:add(w:part).
		break.
	}
}

set steeringmanager:maxstoppingtime to 5.

local lastSaveTime is Time:Seconds - 299.95.

local curThrottle is 0.

until targetGeoPos:Distance < minDist
{
	// Calc slope
	local slopeVec is vcrs(Body:GeoPositionOf(wheelList[0]:position):Position - Body:GeoPositionOf(wheelList[2]:position):Position, Body:GeoPositionOf(wheelList[1]:position):Position - Body:GeoPositionOf(wheelList[2]:position):Position):Normalized.

	if Ship:Status <> "Landed"
	{
		if isLanded
		{
			set takeoffTime to Time:Seconds.
			set isLanded to false.
		}
		else if Time:Seconds - takeoffTime >= 1
		{
			set Ship:Control:WheelSteer to 0.
			set Ship:Control:WheelThrottle to 0.
			
			rcs on.
			local lock rightVec to vcrs(Up:Vector, Ship:Velocity:Surface:Normalized).
			lock steering to lookdirup(vcrs(rightVec, Up:Vector), slopeVec).
			
			wait until Ship:Status = "Landed" and vdot(Facing:UpVector, slopeVec) > 0.999.
			
			unlock steering.
			rcs off.
			
			set isLanded to true.
		}
	}
    
    local turnRate is turnPid:update(time:seconds, targetGeoPos:Bearing).
	
    set steerPid:SetPoint to turnRate.
	set Ship:Control:WheelSteer to steerPid:update(time:seconds, -vdot(Ship:AngularVel, Up:Vector)).
    
    local reqSpeed is 0.
    
	if Time:Seconds - lastSaveTime > 300 and vdot(Facing:UpVector, slopeVec) > 0.9985
	{
		set Ship:Control:WheelThrottle to 0.
		brakes on.
        
		if Ship:GroundSpeed < 0.1
        {
            kUniverse:QuickSaveTo("RoveTo").
            set lastSaveTime to Time:Seconds.
        }
	}
    else
    {
        set throttlePid:kP to 0.002 * kUniverse:TimeWarp:Rate.
        set throttlePid:kD to 0.0025 * kUniverse:TimeWarp:Rate.
        
        local turnFactor is abs(targetGeoPos:Bearing * 0.1) + abs(Ship:Control:WheelSteer * 0.8).
        set turnFactor to max(0, 1.2 - min(turnFactor, 0.8)).

        set reqSpeed to maxSpeed * min(1, max(max(1-vang(slopeVec, Up:Vector)/30, 0.5)^1.5 * stabilityFactor * turnFactor, 0.1)).
        set throttlePid:SetPoint to reqSpeed.
        local throttleDelta is throttlePid:Update(time:seconds, Ship:GroundSpeed).

        set curThrottle to min(max(-1, curThrottle + throttleDelta), 1).

        if curThrottle < -0.2
            brakes on.
        else
            brakes off.
        
        // If low on power, freewheel
        if Ship:ElectricCharge < fullCharge * 0.02
            set Ship:Control:WheelThrottle to 0.
        else if abs(targetGeoPos:Bearing) > 20
            set Ship:Control:WheelThrottle to min(max(-0.25, curThrottle), 0.25).
        else
            set Ship:Control:WheelThrottle to curThrottle.
    }

	if Ship:Control:WheelThrottle > 0.95 and vdot(slopeVec, Up:Vector) < 0.965
	{
		rcs on.
		set Ship:Control:Top to 1.
	}
	else
	{
		rcs off.
		set Ship:Control:Top to 0.
	}
	
	set guiStatus:hdg:text to round(targetGeoPos:Heading, 1) + "° (" + round(targetGeoPos:Bearing, 1) + "°)".
	if targetGeoPos:Distance > 5000
		set guiStatus:dst:text to round(targetGeoPos:Distance / 1000, 1) + " km".
	else if targetGeoPos:Distance > 1200
		set guiStatus:dst:text to round(targetGeoPos:Distance / 1000, 2) + " km".
	else
		set guiStatus:dst:text to round(targetGeoPos:Distance, 1) + " m".
	
	local etaSeconds is max(targetGeoPos:Distance - minDist, 0) / max(Ship:GroundSpeed, 0.001).
	if etaSeconds > 90
		set guiStatus:eta:text to floor(etaSeconds / 60) + "m " + floor(mod(etaSeconds, 60)) + "s".
	else
		set guiStatus:eta:text to round(etaSeconds, 1) + "s".

	set guiStatus:sv:Text to round(Time:Seconds - lastSaveTime, 0) + " / 300 s".
	set guiStatus:ra:Text to round(vang(Facing:UpVector, slopeVec), 1) + " / 3.14°".
	set guiStatus:spd:Text to round(reqSpeed, 2) + " m/s".
    set guiStatus:pwr:Text to round(100 * Ship:ElectricCharge / fullCharge, 2) + "%".
	
	set guiStatus:thr:Text to round(curThrottle, 3) + " (" + round(Ship:Control:WheelThrottle, 3) + ")".
    
	set guiStatus:turn:Text to round(turnRate, 3) + " (" + round(-vdot(Ship:AngularVel, Up:Vector), 3) + ")".
	set guiStatus:steer:Text to round(Ship:Control:WheelSteer, 3):ToString.

	wait 0.
}

set ship:control:neutralize to true.
brakes on.

LAS_Avionics("shutdown").
}

clearGuis().
