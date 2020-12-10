// Flight autopilot
@lazyglobal off.

// runway length should be approximately 2.46km
local KnownRunways is lexicon(
	"VAFB", lexicon("end1", latlng(34.585765, -120.641), "end2", latlng(34.585765, -120.6141), "alt", 190, "hdg", 90),
	"KSC", lexicon("end1", latlng(28.612852, -80.6179), "end2", latlng(28.612852, -80.5925), "alt", 78.5, "hdg", 90)
).

// Wait for unpack
wait until Ship:Unpacked.

local lock shipHeading to mod(360 - latlng(90,0):bearing, 360).

local function velocityHeading
{
  local east is vcrs(up:vector, north:vector).

  local trig_x is vdot(north:vector, velocity:surface).
  local trig_y is vdot(east, velocity:surface).

  local result is arctan2(trig_y, trig_x).

  return mod(result + 360, 360).
}

local function shipRoll
{
	local raw is vang(Ship:up:vector, -Ship:facing:starvector).
	if vang(Ship:up:vector, Ship:facing:topvector) > 90 {
		if raw > 90 {
			return raw - 270.
		} else {
			return raw + 90.
		}
	} else {
		return 90 - raw.
	}
}
local lock shipPitch to 90 - vang(Ship:up:vector, Ship:facing:forevector).

local function angle_off
{
	parameter a1, a2. // how far off is a2 from a1.

	local ret_val is a2 - a1.
	if ret_val < -180 {
		set ret_val to ret_val + 360.
	} else if ret_val > 180 {
		set ret_val to ret_val - 360.
	}
	return ret_val.
}

local flightTarget is 0.
local flightTargetAlt is 0.

local function getDistanceToTarget
{
	return flightTarget:AltitudePosition(flightTargetAlt):Mag.
}
local function getClimbRateToTarget
{
	return (flightTargetAlt - Ship:Altitude) / (getDistanceToTarget() / Ship:AirSpeed).
}

local function GetMaxTemp
{
	parameter aje.

	if aje:HasField("eng. internal temp")
	{
		local ts is aje:GetField("eng. internal temp").
		set ts to ts:split("/")[1]:replace(",", "").
		set ts to ts:substring(0, ts:find("K")). 
		return ts:ToScalar(0).
	}
	return 0.
}
local function GetEngTemp
{
	parameter aje.

	local ts is aje:GetField("eng. internal temp").
	set ts to ts:replace(",", ""). 
	set ts to ts:substring(0, ts:find("K")). 
	return ts:ToScalar(0).
}

local currentFlapDeflect is 0.
local allFlaps is list().
local hasReheat is false.
local hasJet is false.
local rocketPlane is false.
local RATOEngines is list().
local RamjetEngines is list().
local JetEngines is list().
local initialClimb is true.
local enginesFiring is true.
local abortMode is false.
local allChutes is list().

local leftGear is 0.
local rightGear is 0.
local jetThrust is 0.

for p in Ship:parts
{
	if p:HasModule("FARControllableSurface")
	{
		local farMod is p:GetModule("FARControllableSurface").
		if farMod:HasAction("increase flap deflection") and farMod:HasAction("decrease flap deflection")
		{
			allFlaps:add(farMod).
		}
	}
	else if p:HasModule("RealChuteModule")
	{
		allChutes:add(p).
	}

	if p:HasModule("ModuleEnginesAJEJet")
	{
		local engMod is p:GetModule("ModuleEnginesAJEJet").
		if engMod:HasField("afterburner throttle")
			set hasReheat to true.
        set hasJet to true.
		set jetThrust to jetThrust + p:PossibleThrust.
		local engLex is lexicon("part", p, "aje", engMod, "restartSpeed", 0, "maxtemp", GetMaxTemp(engMod), "reheat", engMod:HasField("afterburner throttle"), "heatpid", PIDloop(1, 0, 0.2, -2, 0.2)).
		set engLex:heatpid:SetPoint to engLex:maxTemp - 10.
		JetEngines:add(engLex).
	}
	else if p:HasModule("ModuleEnginesAJERamjet")
	{
		local engMod is p:GetModule("ModuleEnginesAJERamjet").
        set hasJet to true.
		set jetThrust to jetThrust + p:PossibleThrust.
		local engLex is lexicon("part", p, "aje", engMod, "maxtemp", GetMaxTemp(engMod), "heatpid", PIDloop(1, 0, 0.2, -2, 0.2)).
		set engLex:heatpid:SetPoint to engLex:maxTemp - 10.
		RamjetEngines:add(engLex).
	}
	else if p:HasModule("ModuleEnginesRF")
	{
		local engMod is p:GetModule("ModuleEnginesRF").
		if engMod:HasField("ignitions remaining")
		{
			set rocketPlane to true.
		}
		if p:tag:contains("rato")
			RATOEngines:Add(p).
	}

	if p:HasModule("ModuleWheelBrakes")
	{
		if vdot(p:Position, Ship:RootPart:Facing:RightVector) > 1
		{
			set rightGear to p.
		}
		else if vdot(p:Position, Ship:RootPart:Facing:RightVector) < -1
		{
			set leftGear to p.
		}
		else
		{
			p:GetModule("ModuleWheelBrakes"):SetField("brakes", 0).
		}
	}
}

if hasJet
    set rocketPlane to false.

local function setFlaps
{
	parameter deflect.

	until currentFlapDeflect = deflect
	{
		if currentFlapDeflect < deflect
		{
			for f in allFlaps
				f:DoAction("increase flap deflection", true).
			set currentFlapDeflect to currentFlapDeflect + 1.
		}
		else
		{
			for f in allFlaps
				f:DoAction("decrease flap deflection", true).
			set currentFlapDeflect to currentFlapDeflect - 1.
		}
	}
	if not allFlaps:Empty
		print "Flaps " + currentFlapDeflect.
}

local function startEngines
{
	local allEngines is list().
	list engines in allEngines.

	local haveEngines is false.

	until haveEngines
	{
		for eng in allEngines
		{
			if eng:Stage = stage:Number and not eng:HasModule("ModuleEnginesAJERamjet")
			{
				eng:Activate.
				set haveEngines to true.
			}
		}

		if not haveEngines
			stage.
	}

	set Ship:Control:PilotMainThrottle to 1.
}

local function startTaxiEngines
{
    local allEngines is list().
    list engines in allEngines.

    for eng in allEngines
    {
        if eng:Ignitions < 0 and not eng:HasModule("ModuleEnginesAJERamjet")
            eng:Activate.
    }
}

local function stopEngines
{
    local allEngines is list().
    list engines in allEngines.

    for eng in allEngines
    {
        eng:Shutdown.
    }
}

local function runwayNumber
{
	parameter heading.

	local number is round(heading / 10, 0).
	if number < 10
		return "0" + number:ToString.
	return number:ToString.
}

local targetFlightLevel is 50.
local targetSpeed is 0.
local targetHeading is round(shipHeading, 0).
local targetClimbRate is 0.
local rotateSpeed is 100.
local landingSpeed is 0.
local controlSense is 1.

if Core:Part:Tag:Contains("rot=")
{
    local f is Core:Part:Tag:Find("rot=") + 4.
    set rotateSpeed to Core:Part:Tag:Substring(f, Core:Part:Tag:Length - f):Split(" ")[0]:ToNumber(rotateSpeed).
}

set rotateSpeed to round(rotateSpeed * 0.2, 0) * 5.
set landingSpeed to round(rotateSpeed * 0.17, 0) * 5.
set targetSpeed to rotateSpeed * 2.

if rocketPlane and not Core:Part:tag:contains("noclimb")
{
	set targetFlightLevel to 0.
	set targetClimbRate to 30.
}
else
{
	set initialClimb to false.
}

local yawPid is PIDloop(0.5, 0.05, 0.2, -1, 1).
local wheelPid is PIDLoop(0.15, 0, 0.1, -1, 1).
local throtPid is PIDloop(0.1, 0, 0.1, -1, 1).
local throttleSense is 0.05.

local flightGui is Gui(300).
set flightGui:X to 200.
set flightGui:Y to flightGui:Y + 60.

local mainBox is flightGui:AddHBox().
local labelBox is mainBox:AddVBox().
set labelBox:style:width to 150.
local controlBox is mainBox:AddVBox().
set controlBox:style:width to 120.
local toggleBox is mainBox:AddVBox().
set toggleBox:style:width to 50.

local guiElements is list().
local guiButtons is lexicon().

local function createGuiControls
{
    parameter tagStr.
    parameter lblStr.
    parameter value.
    parameter dlg.
    parameter btnStr.

    local ctrl is labelBox:AddLabel(lblStr).
    set ctrl:Style:Height to 25.
    guiElements:add(ctrl).

    set ctrl to controlBox:AddTextField(value:ToString).
    set ctrl:Style:Height to 25.
	if dlg:IsType("UserDelegate")
		set ctrl:OnConfirm to dlg.
	else
		set ctrl:Enabled to false.
    guiElements:add(ctrl).

    if btnStr:Length > 0
        set ctrl to toggleBox:AddButton(BtnStr).
    else
        set ctrl to toggleBox:AddCheckBox(BtnStr, true).
    set ctrl:Style:Height to 25.
    guiButtons:add(tagStr, ctrl).
}

local function createGuiInfo
{
    parameter tagStr.
    parameter lblStr.
    parameter value.

    local ctrl is labelBox:AddLabel(lblStr).
    set ctrl:Style:Height to 25.
    guiElements:add(ctrl).

    set ctrl to controlBox:AddTextField(value:ToString).
    set ctrl:Style:Height to 25.
    set ctrl:Enabled to false.
    guiElements:add(ctrl).

    guiButtons:add(tagStr, ctrl).
}

createGuiControls("hdg", "Heading", targetHeading, { parameter s. set targetHeading to s:ToNumber(targetHeading). }, "").
createGuiControls("spd", "Airspeed", targetSpeed, { parameter s. set targetSpeed to s:ToNumber(targetSpeed). }, "").
createGuiControls("fl", "Flight Level", targetFlightLevel, { parameter s. set targetFlightLevel to s:ToNumber(targetFlightLevel). }, "").
createGuiControls("cr", "Climb Rate", targetClimbRate, { parameter s. set targetClimbRate to s:ToNumber(targetClimbRate). }, "").

//createGuiControls("sns1", "Throttle Sens", throttleSense, { parameter s. set throttleSense to s:ToNumber(throttleSense). }, "").
//createGuiControls("sns2", "Throttle kP", throtPid:KP, { parameter s. set throtPid:KP to s:ToNumber(throtPid:KP). }, "").
//createGuiControls("sns3", "Throttle kI", throtPid:KI, { parameter s. set throtPid:KI to s:ToNumber(throtPid:KI). }, "").
//createGuiControls("sns4", "Throttle kD", throtPid:KD, { parameter s. set throtPid:KD to s:ToNumber(throtPid:KD). }, "").#

if rocketPlane
{
	set guiButtons["fl"]:Pressed to false.
	set guiButtons["spd"]:Pressed to false.
}
else
{
	set guiButtons["cr"]:Pressed to false.
}

// climbRate / altitude control are exclusive
set guiButtons["fl"]:OnToggle to { parameter val. if val { set guiButtons["cr"]:Pressed to false. } }.
set guiButtons["cr"]:OnToggle to { parameter val. if val set guiButtons["fl"]:Pressed to false. }.

createGuiControls("to", "Rotate Speed", rotateSpeed, { parameter s. set rotateSpeed to s:ToNumber(rotateSpeed). }, "TO").
createGuiControls("lnd", "Landing Speed", landingSpeed, { parameter s. set landingSpeed to s:ToNumber(landingSpeed). }, "Land").

local fuelConsText is 0.
if hasReheat
{
	createGuiControls("rht", "Fuel Cons (Reheat)", 0, 0, "").
	set guiButtons["rht"]:Pressed to true.
}
else
{
	createGuiInfo("rht", "Fuel Consumption", "0").
}
set fuelConsText to guiElements[guiElements:Length-1].

local runwayEnd1 is latlng(0, 0).
local runwayEnd2 is latlng(0, 0).
local runwayAlt is 0.
local runwayHeading is -1.
local runwayName is "".

{
	local closestDist is 1e8.
	set runwayName to "".
	for rw in knownRunways:keys
	{
		local d is knownRunways[rw]:end1:distance.
		if d < closestDist
		{
			set closestDist to d.
			set runwayName to rw.
		}
	}

	set runwayEnd1 to knownRunways[runwayName]:end1.
	set runwayEnd2 to knownRunways[runwayName]:end2.
	set runwayAlt to knownRunways[runwayName]:alt.

	set runwayHeading to knownRunways[runwayName]:hdg.
}

createGuiInfo("rwy", runwayName + " Runway", "0.0° 0.0 km").
createGuiInfo("dbg", "Debug", "").
local debugName is guiElements[guiElements:Length-2].

local groundHeading is round(shipHeading, 1).
local onGround is true.
local lastUpdate is Time:Seconds.

local fs_Landed is 0.
local fs_Takeoff is 1.
local fs_Taxi is 2.
local fs_TaxiTurn is 3.
local fs_Flight is 10.
local fs_LandInitApproach is 20.
local fs_LandTurn is 21.
local fs_LandInterApproach is 22.
local fs_LandFinalApproach is 23.
local fs_LandBrake is 24.
local fs_LandManual is 25.
local fs_LandDitch is 26.
local fs_LandBrakeHeading is 27.

local flightState is fs_Flight.
set debugName:Text to "Flight".

local landingTarget is 0.
local approachDirLat is 0.
local approachDirLng is 0.

local buttonBox is flightGui:AddHBox().

local taxiButton1 is buttonBox:AddButton("Taxi " + runwayNumber(runwayHeading)).
local taxiButton2 is buttonBox:AddButton("Taxi " + runwayNumber(mod(runwayHeading + 180, 360))).
local taxiHeading is -1.

local TOPitchScale is 0.2.

if Ship:status = "PreLaunch" or Ship:status = "Landed"
{
    Core:Part:GetModule("kOSProcessor"):DoEvent("Open Terminal").

	set flightState to fs_Landed.
	set debugName:Text to "Landed".
	set guiButtons["to"]:Enabled to true.
	set guiButtons["lnd"]:Enabled to false.
	set Ship:Type to "Plane".
	brakes on.

	set TOPitchScale to 1.2 / (8 - shipPitch).
}
else
{
	set guiButtons["to"]:Enabled to false.
}

if rocketPlane
	set TOPitchScale to TOPitchScale * 2.

local exitButton is buttonBox:AddButton("Exit").

local lastFuelAmount is 0.
local lastFuelTime is Time:Seconds.

// Configure AA
set addons:aa:fbw to true.
set addons:aa:pseudoflc to false.
set addons:aa:maxg to 9.
set addons:aa:maxsideg to 8.
set addons:aa:moderateaoa to true.
set addons:aa:moderatesideslip to true.
set addons:aa:moderateg to true.
set addons:aa:moderatesideg to true.
set addons:aa:rollratelimit to 1.
set addons:aa:wingleveler to true.
set addons:aa:directorstrength to 0.6.
set addons:aa:maxclimbangle to choose 45 if jetThrust / (ship:mass * 9.81) >= 0.8 else 30.
print "TWR=" + round(jetThrust / (ship:mass * 9.81), 2) + " maxclimb=" + addons:aa:maxclimbangle.

FlightGui:Show().

until exitButton:TakePress
{
	// Engine heating control
	if not jetEngines:Empty
	{
		local maxThrottle is 100.
		if hasReheat and not guiButtons["rht"]:Pressed and flightState >= fs_Flight
			set maxThrottle to 200/3.

		for jet in jetEngines
		{
			if jet:maxTemp > 0 and flightState >= fs_Flight
			{
				if jet:part:Ignition
				{
					local throttleDelta is jet:heatpid:Update(time:seconds, GetEngTemp(jet:aje)).
					set jet:part:ThrustLimit to min(max(4, jet:part:ThrustLimit + throttleDelta), choose maxthrottle if jet:reheat else 100).
					if jet:part:ThrustLimit >= 50
					{
						set jet:restartSpeed to floor(Ship:AirSpeed).
					}
					else if (jet:part:ThrustLimit <= 20 or jet:part:Thrust <= 0) and Ship:AirSpeed > jet:restartSpeed + 1
					{
						jet:part:shutdown.
						print "Shutting down " + jet:part:title + " restart at " + jet:restartSpeed + " m/s.".
					}
				}
				else
				{
					if Ship:AirSpeed <= jet:restartSpeed
						jet:part:activate.
				}
			}
			else
			{
				set jet:part:ThrustLimit to choose maxthrottle if jet:reheat else 100.
			}
		}
	}
			
	if not RamjetEngines:Empty
	{
		for jet in RamjetEngines
		{
			if Ship:AirSpeed >= 600 and not jet:part:Ignition
			{
				jet:part:Activate.
			}
			else if Ship:AirSpeed < 580 and jet:part:Ignition
			{
				jet:part:Shutdown.
			}
			
			if jet:maxTemp > 0 and jet:part:Ignition
			{
				local throttleDelta is jet:heatpid:Update(time:seconds, GetEngTemp(jet:aje)).
				set jet:part:ThrustLimit to min(max(1, jet:part:ThrustLimit + throttleDelta), 100).
			}
		}
	}

	if flightState <> fs_Landed
	{
		local reqClimbRate is -1e8.
        local reqPitch is shipPitch.
		local reqHeading is -1.
		local reqControl is true.
		local reqSpeed is 0.

		if flightState = fs_Takeoff
		{
			if Ship:GroundSpeed >= rotateSpeed or Ship:Status = "Flying"
			{
				// 8 degree rotation
				set reqPitch to 8.
				if rocketPlane or abortMode
					set reqPitch to 20.
			}
			else
			{
				set groundHeading to landingTarget:Heading.
				if Ship:longitude < landingTarget:lng
					set groundHeading to groundHeading + (Ship:Latitude - landingTarget:Lat) * 12000.
				else				
					set groundHeading to groundHeading - (Ship:Latitude - landingTarget:Lat) * 12000.
			}

			if reqPitch > 0 and Ship:Status = "Flying" and onGround
			{
				set onGround to false.
                set Ship:Control:WheelSteer to 0.
                set Ship:Control:Yaw to 0.
			}
            else if Ship:Status = "Landed"
            {
                set onGround to true.
            }

			set reqHeading to groundHeading.
			set Ship:Control:PilotMainThrottle to 1.

			local minAlt is 200 * (30 / addons:aa:maxclimbangle) ^ 2.25.
			if initialClimb
				set minAlt to 10.
			else if abortMode
				set minAlt to 400.

			if Alt:Radar > minAlt and Ship:VerticalSpeed > 0 and shipPitch > 5
			{
                setFlaps(0).
				set flightState to fs_Flight.
				set debugName:Text to "Flight".
				set guiButtons["lnd"]:Enabled to true.
			}
		}
		else if flightState = fs_Flight
		{
			if guiButtons["fl"]:Pressed or guiButtons["cr"]:Pressed or guiButtons["hdg"]:Pressed
			{
				// Altitude control
				if initialClimb
				{
					set reqPitch to targetClimbRate.
					if Ship:VerticalSpeed < 0
					{
						set initialClimb to false.
						stopEngines().
						if Ship:Altitude > 100000
							brakes on.
					}
				}
				else if guiButtons["cr"]:Pressed
				{
					set reqClimbRate to targetClimbRate.
				}

				if guiButtons["hdg"]:pressed
				{
					set reqHeading to targetHeading.
				}
			}
			else
			{
				set reqControl to false.
			}

			if guiButtons["spd"]:Pressed
			{
				set reqSpeed to targetSpeed.
			}

			if guiButtons["lnd"]:TakePress
			{
				if runwayHeading >= 0
				{
					if runwayEnd1:Distance < runwayEnd2:Distance
					{
						set landingTarget to runwayEnd1.
						set groundHeading to runwayHeading.
						set approachDirLat to runwayEnd1:Lat - runwayEnd2:Lat.
						set approachDirLng to runwayEnd1:Lng - runwayEnd2:Lng.
					}
					else
					{
						set landingTarget to runwayEnd2.
						set groundHeading to mod(runwayHeading + 180, 360).
						set approachDirLat to runwayEnd2:Lat - runwayEnd1:Lat.
						set approachDirLng to runwayEnd2:Lng - runwayEnd1:Lng.
					}
					// approach lat/lng are approximately 2.46km

					print "Landing at runway " + runwayNumber(groundHeading).

					// initial approach marker at 12 km out, 500m alt.
					set flightTarget to LatLng(landingTarget:lat + approachDirLat * (12/2.46), landingTarget:lng + approachDirLng * (12/2.46)).
					set flightTargetAlt to runwayAlt + 500.
					if rocketPlane
					{
						set flightTarget to LatLng(flightTarget:lat + approachDirLat, flightTarget:lng + approachDirLng).
						set flightTargetAlt to flightTargetAlt + 1250.
					}
					set flightState to fs_LandInitApproach.
					set debugName:Text to "Initial Approach".
					set guiButtons["lnd"]:Enabled to false.

					set reqClimbRate to getClimbRateToTarget().
				}
				else
				{
					set flightState to fs_LandManual.
					set debugName:Text to "Manual Landing".
					print "Manual landing assistance active".
					when alt:radar < 200 then { gear on. lights on. }
				}

				for chute in allChutes
				{
					local modRealChute is chute:GetModule("RealChuteModule").
					if modRealChute:HasEvent("arm parachute")
					{
						modRealChute:DoEvent("arm parachute").
					}
				}
			}
		}
		else if flightState = fs_LandInitApproach
		{
			set reqClimbRate to getClimbRateToTarget().
			set reqHeading to flightTarget:Heading.
			set reqSpeed to (1.5 + getDistanceToTarget() / 25000) * landingSpeed.
			local minSpeed is 1.5 * landingSpeed.
			set reqSpeed to max(minSpeed, min(Ship:Airspeed, reqSpeed)).
			local minDistance is 200.
			if rocketPlane or abs(angle_off(groundHeading, shipHeading)) <= 60
				set minDistance to minDistance + abs(angle_off(groundHeading, shipHeading)) * Ship:Airspeed * 0.25.

			set guiButtons["dbg"]:Text to round(reqHeading, 1) + "° " + round(getDistanceToTarget() * 0.001, 1) + "/" + round(minDistance * 0.001, 1).

			if getDistanceToTarget() < minDistance
			{
				if rocketPlane or (abs(angle_off(groundHeading, shipHeading)) <= 60 and Ship:AirSpeed < reqSpeed * 1.2)
				{
					set flightState to fs_LandInterApproach.
					set debugName:Text to "Approach".
					set flightTarget to LatLng(landingTarget:lat + approachDirLat * (4/2.46), landingTarget:lng + approachDirLng * (4/2.46)).
					set flightTargetAlt to runwayAlt + 220.
					if rocketPlane
						set flightTargetAlt to flightTargetAlt + 280.
					else
						setFlaps(2).
					print "On approach".
				}
				else
				{
					set flightState to fs_LandTurn.
					set debugName:Text to "Turn 1".
					if Ship:AirSpeed >= reqSpeed * 1.2
						print "Turning to reduce speed".
					else
						print "Turning to correct heading".
				}
			}
			else if rocketPlane and Alt:Radar < 1000
			{
				set flightState to fs_LandDitch.
				set debugName:Text to "Ditching".
				set groundHeading to shipHeading.
				print "Insufficient momentum for landing, ditching aircraft".
			}
		}
		else if flightState = fs_LandTurn
		{
			set reqClimbRate to (flightTargetAlt - Ship:Altitude) * 0.05.
			set reqSpeed to 1.5 * landingSpeed.
			local minDistance is 2500 * landingSpeed * landingSpeed / 6400.

            if getDistanceToTarget() < minDistance
            {
                set reqHeading to mod(groundHeading + 135, 360).
                local heading2 is mod(groundHeading + 225, 360).
                if abs(angle_off(heading2, shipHeading)) < abs(angle_off(reqHeading, shipHeading))
                    set reqHeading to heading2.
				set guiButtons["dbg"]:Text to round(reqHeading, 1) + "° " + round(getDistanceToTarget() * 0.001, 2) + " / " + round(minDistance * 0.001, 2).
            }
			else
            {
                set reqHeading to mod(groundHeading + 180, 360).

				set debugName:Text to "Turn 2".
				set guiButtons["dbg"]:Text to round(reqHeading, 1) + "° " + round(getDistanceToTarget() * 0.001, 2) + " / " + round(minDistance * 0.002, 2).

                if getDistanceToTarget() > minDistance * 2
                {
                    set flightState to fs_LandInitApproach.
					set debugName:Text to "Initial Approach".
                }
            }
        }
		else if flightState = fs_LandInterApproach
		{
			if getDistanceToTarget() < 800
			{
				kUniverse:Timewarp:CancelWarp().
				// Use blended heading
				set reqHeading to (flightTarget:Heading + landingTarget:Heading) / 2.
			}
			else
			{
				set reqHeading to flightTarget:Heading.
			}
			set reqClimbRate to getClimbRateToTarget().
			set reqSpeed to min((1 + getDistanceToTarget() / 16000), 1.5) * landingSpeed.

			set guiButtons["dbg"]:Text to round(reqHeading, 1) + "° " + round(getDistanceToTarget() * 0.001, 1) + "/0.1".

			if landingTarget:Distance < 4200
			{
				set flightState to fs_LandFinalApproach.
				set debugName:Text to "Final".
				set flightTarget to landingTarget.
				if runwayEnd1:Distance < runwayEnd2:Distance
					set landingTarget to runwayEnd2.
				else					
					set landingTarget to runwayEnd1.
				set flightTargetAlt	to runwayAlt + 5.
				setFlaps(3).
				gear on.
				brakes off.
				when alt:radar < 100 then { lights off. lights on. }
				print "Final approach".
			}
		}
		else if flightState = fs_LandFinalApproach
		{
			set reqHeading to flightTarget:Heading.
			set reqSpeed to landingSpeed.

			set guiButtons["dbg"]:Text to round(reqHeading, 1) + "° " + round(getDistanceToTarget() * 0.001, 2).

			local landingAltitude is max(1, min(Alt:Radar, Ship:Altitude - runwayAlt)).
			if rocketPlane and landingAltitude < 100
			{
				set reqClimbRate to -(landingAltitude/20)^1.7.
				set reqHeading to landingTarget:heading.
			}
			else if landingAltitude < 30
			{
				set reqClimbRate to -(landingAltitude/10)^1.2.
				set reqHeading to landingTarget:heading.
			}
			else
			{
				set reqClimbRate to getClimbRateToTarget().
			}
			
			if Ship:VerticalSpeed < reqClimbRate
				set reqClimbRate to reqClimbRate + (reqClimbRate - Ship:VerticalSpeed) * 0.6.
			
			if landingAltitude < 20
				set reqClimbRate to min(reqClimbRate, -0.5).
				
			// Crosswind compensation
			if Ship:longitude < landingTarget:lng
				set reqHeading to reqHeading + (Ship:Latitude - landingTarget:Lat) * 8000.
			else				
				set reqHeading to reqHeading - (Ship:Latitude - landingTarget:Lat) * 8000.

			if Ship:Status = "Landed"
			{
				brakes on.
				print "Braking".
				set flightState to fs_LandBrakeHeading.
				set debugName:Text to "Brake".
				set flightTarget to landingTarget.
                stopEngines().
			}
		}
		else if flightState = fs_LandBrake or flightState = fs_LandBrakeHeading
		{
			set Ship:Control:PilotMainThrottle to 0.
			if flightState = fs_LandBrakeHeading
				set groundHeading to flightTarget:Heading.

			set reqHeading to groundHeading.
			set reqPitch to 0.

			if Ship:GroundSpeed < 1
			{
                setFlaps(0).
				set flightState to fs_Landed.
				set debugName:Text to "Landed".
			}
            // anti-lock brakes
            else
			{
				local a is angle_off(shipHeading, reqHeading).
				if Ship:GroundSpeed < 8
					set a to 0.
				local maxBrake is max(100 - Ship:GroundSpeed, 0) * min(max(3 - abs(a), 0), 1).

				if leftGear:IsType("part") and rightGear:IsType("part")
				{
					leftGear:GetModule("ModuleWheelBrakes"):SetField("brakes", maxBrake * min(max(1.5 - a, 0.1), 1.25)).
					rightGear:GetModule("ModuleWheelBrakes"):SetField("brakes", maxBrake * min(max(1.5 + a, 0.1), 1.25)).
				}
			}
		}
		else if flightState = fs_LandManual
		{
			set reqControl to false.

			if Ship:Status = "Landed"
			{
				brakes on.
				set groundHeading to shipHeading.
				print "Braking".
				set flightState to fs_LandBrake.
				set debugName:Text to "Brake".
			}
			else if guiButtons["lnd"]:TakePress
			{
				print "Landing assistance cancelled".
				set flightState to fs_Flight.
				set debugName:Text to "Flight".
			}
		}
		else if flightState = fs_LandDitch
		{
			set reqHeading to groundHeading.
			if Alt:Radar > 1
				set reqClimbRate to -((Alt:Radar / 10) ^ 0.8).

			if Ship:Status = "Landed"
			{
				brakes on.
				print "Braking".
				set flightState to fs_LandBrake.
				set debugName:Text to "Brake".
			}
		}
        else if flightState = fs_Taxi
        {
            if getDistanceToTarget() < 5
            {
                set flightState to fs_TaxiTurn.
            }

            set groundHeading to flightTarget:Heading.

            if Ship:GroundSpeed > 16
                brakes on.
            else if Ship:GroundSpeed < 15
                brakes off.
        }
        else if flightState = fs_TaxiTurn
        {
            local a is angle_off(shipHeading, taxiHeading).
            if abs(a) < 0.5
            {
                brakes on.
                stopEngines().

                set flightState to fs_Landed.
                set debugName:Text to "Landed".
                set guiButtons["to"]:Enabled to true.
                set taxiButton1:Enabled to true.
                set taxiButton2:Enabled to true.
            }
            else
            {
                if abs(a) > 100
                {
                    set groundHeading to mod(taxiHeading + 90, 360).
                }
                else
                {
                    set groundHeading to taxiHeading.
                }

                if Ship:GroundSpeed > 3
                    brakes on.
                else if Ship:GroundSpeed < 2.5
                    brakes off.
            }
        }

		// Ground collision avoidance
		if not rocketPlane and flightState >= fs_Flight and flightState <= fs_LandFinalApproach
		{
			set abortMode to false.
			if flightState = fs_LandFinalApproach
				set abortMode to (Ship:Altitude <= runwayAlt) or (Ship:VerticalSpeed < -8 and Ship:VerticalSpeed * -5 > Alt:Radar).
			else
				set abortMode to Ship:VerticalSpeed * -10 > Alt:Radar.

			if abortMode
			{
				print "Aborting landing: vs=" + round(Ship:VerticalSpeed,1) + " h=" + round(Alt:Radar, 1).
				// do a go around, full throttle, 20 degree pitch up, neutral steering.
				set Ship:Control:PilotMainThrottle to 1.	// Always use reheat for go around.
				set reqSpeed to 0.
				set reqClimbRate to -1e8.
				set reqPitch to 20.
				set reqHeading to -1.
				set groundHeading to shipHeading.
				set flightState to fs_Takeoff.
				set guiButtons["hdg"]:Pressed to false.
				set debugName:Text to "Abort".
				setFlaps(2).
				when alt:radar >= 20 and Ship:VerticalSpeed > 0 then { gear off. if currentFlapDeflect > 1 setFlaps(1). }
			}
		}
		
		local highAlt is false.
		
		if rocketPlane and flightState = fs_Flight
		{
			if initialClimb
			{
				set addons:aa:maxaoa to 30.
				
				local allEngines is list().
				list engines in allEngines.

				local engineThrust is 0.
				for eng in allEngines
				{
					set engineThrust to engineThrust + eng:Thrust.
				}
				if engineThrust < 0.1
				{
					// Follow prograde
					set reqPitch to max(90 - vang(Ship:up:vector, Ship:Velocity:Surface), 20).
					if enginesFiring
					{
						set enginesFiring to false.
						steeringmanager:resettodefault().
					}
				}
			}
			else
			{
				set addons:aa:maxaoa to min(max(5 + Ship:altitude / 1000, 15), 75).
				if Ship:Altitude > 25000 or Ship:VerticalSpeed < -200
				{
					set reqPitch to 20.
					set reqClimbRate to -1e8.
				}
			}
			
			if (Ship:Altitude > 30000 and Ship:VerticalSpeed > 0) or Ship:Altitude > 40000
				set highAlt to true.
		}

        if not RATOEngines:Empty and Stage:Number > 0 and Stage:Ready
        {
            local flamedOut is true.
            for e in RATOEngines
            {
                if not e:Flameout
                    set flamedOut to false.
            }
            if flamedOut
            {
                set RATOEngines to list().
                stage.
            }
        }

		if highAlt or (initialClimb and Ship:Altitude > 15000)
		{
			set addons:aa:fbw to false.
			set addons:aa:cruise to false.
			set addons:aa:director to false.
			set reqHeading to velocityHeading().
			set SteeringManager:RollControlAngleRange to 180.
			lock steering to heading(reqHeading, reqPitch):Vector.
			print "HighAlt " + round(reqHeading, 1) + "° p=" + round(reqPitch, 1) + "/" + round(shipPitch, 1) + "°            " at (0,0).

			if navmode <> "surface"
				set navmode to "surface".
		}
		else 
		{
			unlock steering.
			if reqControl
			{
				if reqClimbRate > -1e6
				{
					set addons:aa:vertspeed to reqClimbRate.
					set addons:aa:heading to reqHeading.
					set addons:aa:cruise to true.
					print "Cruise " + round(reqHeading, 1) + "° vs=" + round(reqClimbRate, 1) + "/" + round(Ship:VerticalSpeed, 1) + "           " at (0,0).
				}
				else if not initialClimb and flightState = fs_Flight and guiButtons["fl"]:Pressed
				{
					set addons:aa:altitude to targetflightLevel * 100.
					set addons:aa:heading to reqHeading.
					set addons:aa:cruise to true.
					print "Cruise " + round(reqHeading, 1) + "° alt=" + round(targetflightLevel, 0) + "              " at (0,0).
				}
				else
				{
					set addons:aa:direction to heading(choose reqHeading if reqHeading >= 0 else shipHeading, reqPitch):Vector.
					set addons:aa:director to true.
					print "Dir " + round(reqHeading, 1) + "° p=" + round(reqPitch, 1) + "/" + round(shipPitch, 1) + "°   MaxAoA=" + round(addons:aa:maxaoa, 1) + "°     " at (0,0).
				}

				if onGround and reqPitch > shipPitch
				{
					set ship:control:pitch to min((reqPitch - shipPitch) * TOPitchScale, 1).
				}
				else
				{
					set Ship:Control:Neutralize to true.
				}
			}
			else
			{
				set Ship:Control:Neutralize to true.
				set addons:aa:cruise to false.
				set addons:aa:director to false.
				set addons:aa:fbw to true.
				print "FBW                       " at (0,0).
			}
		}

		if reqSpeed > 0
		{
			// Throttle control
			set throtPid:SetPoint to reqSpeed.
			local throttleDelta is throtPid:Update(time:seconds, Ship:AirSpeed) * throttleSense.
			local minThrottle is choose 0.1 if initialClimb else 0.
			if brakes
				set Ship:Control:PilotMainThrottle to minThrottle * 10.
			else
				set Ship:Control:PilotMainThrottle to min(max(minThrottle, Ship:Control:PilotMainThrottle + throttleDelta), 1).

			print "Speed " + round(reqSpeed, 1) + "/" + round(Ship:AirSpeed, 1) + "     " at (0,1).

			if flightState >= fs_LandInitApproach and flightState <= fs_LandFinalApproach
			{
				// Use airbrakes if overspeed
				if Ship:AirSpeed > reqSpeed + 10
					brakes on.
				else if Ship:AirSpeed <= reqSpeed + 2
					brakes off.
			}
        }
        else
        {
			throtPid:Reset().
			print "No speed control                 " at (0,1).
        }
        set Ship:control:MainThrottle to Ship:Control:PilotMainThrottle.

		if Ship:Status = "Landed"
		{
			local wheelError is angle_off(groundHeading, shipHeading).

			set wheelPid:kP to 0.04 / max(0.5, Ship:GroundSpeed / 18).
			set wheelPid:kD to wheelPid:kP * 2 / 3.
			
			if flightState = fs_Takeoff
				set wheelPid:kP to wheelPid:kP * 2.

			set Ship:Control:WheelSteer to wheelPid:update(time:seconds, -wheelError).
            set Ship:Control:Yaw to yawPid:Update(time:seconds, wheelError).

            if flightState = fs_Taxi
                set guiButtons["dbg"]:Text to round(groundHeading, 1) + "° " + round(getDistanceToTarget(), 1) + "m".
            else
                set guiButtons["dbg"]:Text to round(groundHeading, 1) + "° ".
		}
        else
        {
            wheelPid:Reset().
        }
		
		if rocketPlane
		{
			if Ship:Altitude > 15000 or flightState = fs_LandFinalApproach or flightState = fs_LandDitch or initialClimb
				rcs on.
			else if Ship:Altitude < 14500
				rcs off.
		}

        if reqControl and (abs(Ship:Control:PilotYaw) > 0.8 or abs(Ship:Control:PilotPitch) > 0.8 or abs(Ship:Control:PilotRoll) > 0.8)
        {
            set guiButtons["fl"]:Pressed to false.
            set guiButtons["cr"]:Pressed to false.
            set guiButtons["hdg"]:Pressed to false.
            set guiButtons["spd"]:Pressed to false.
            set flightState to fs_Flight.
			set debugName:Text to "Flight".
            set Ship:Control:PilotMainThrottle to 1.

            print "Autopilot disengaged.".

            set guiButtons["lnd"]:Enabled to true.
        }
	}
	else if taxiButton1:IsType("Button") and (taxiButton1:Pressed or taxiButton2:Pressed)
	{
		local rw1vec is (runwayEnd1:altitudePosition(runwayAlt) - Ship:Body:Position).
		local rw2vec is (runwayEnd2:altitudePosition(runwayAlt) - Ship:Body:Position).
        if taxiButton1:TakePress
        {
            set flightTarget to runwayEnd1.
            set taxiHeading to runwayHeading.
        }
        else if taxiButton2:TakePress
        {
            set flightTarget to runwayEnd2.
            set taxiHeading to mod(runwayHeading + 180, 360).
        }

        set flightState to fs_Taxi.
		set debugName:Text to "Taxi to " + runwayNumber(taxiHeading).
		set guiButtons["to"]:Enabled to false.
        set taxiButton1:Enabled to false.
        set taxiButton2:Enabled to false.

		startTaxiEngines().

        // Idle power only while on the ground
		set Ship:Control:PilotMainThrottle to 0.

        if leftGear:IsType("part") and rightGear:IsType("part")
        {
            leftGear:GetModule("ModuleWheelBrakes"):SetField("brakes", 25).
            rightGear:GetModule("ModuleWheelBrakes"):SetField("brakes", 25).
        }

		brakes on.
		brakes off.

		print debugName:Text.
    }
	else if guiButtons["to"]:TakePress
	{
		set flightState to fs_Takeoff.
		set debugName:Text to "Takeoff".
		set guiButtons["to"]:Enabled to false.
        if taxiButton1:IsType("Button")
        {
            set taxiButton1:Enabled to false.
            set taxiButton2:Enabled to false.
        }

        // set landing target for abort
        if runwayEnd1:Distance < runwayEnd2:Distance
            set landingTarget to runwayEnd2.
        else
            set landingTarget to runwayEnd1.

		set groundHeading to landingTarget:Heading.

      	print "Takeoff from runway " + runwayNumber(groundHeading).
        print "Engine start.".

		startEngines().
		for rj in ramjetEngines
			rj:Part:Shutdown.

		setFlaps(2).

		if brakes and not jetEngines:empty
		{
			print "Waiting for engines to spool.".

			local engineMaxThrust is 0.
			for eng in jetEngines
			{
				set engineMaxThrust to engineMaxThrust + eng:part:PossibleThrust().
			}

			local engineThrust is 0.
			until engineThrust > engineMaxThrust * 0.5
			{
				set engineThrust to 0.
				for eng in jetEngines
				{
					set engineThrust to engineThrust + eng:part:Thrust().
				}
				wait 0.
			}
		}
		brakes on.
		brakes off.

		print "Beginning takeoff roll.".

		when alt:radar >= 30 then { gear off. if currentFlapDeflect > 1 setFlaps(1). }
	}
	else if flightState = fs_Landed and Ship:Status = "Flying" and Ship:Altitude > 5000
	{
		print "Airlaunch detected".
		set guiButtons["to"]:Enabled to false.
		set debugName:Text to "Airlaunch".

		if abs(angle_off(shipHeading, targetHeading)) > 10
			set guiButtons["hdg"]:Pressed to false.
		set groundHeading to shipHeading.

		startEngines().
		gear off.
		brakes off.

		set flightState to fs_Takeoff.
	}

	if runwayEnd1:Distance < runwayEnd2:Distance
	{
		set guiButtons["rwy"]:Text to round(runwayEnd1:Heading, 1) + "° " + round(runwayEnd1:Distance * 0.001, 1) + " km".
	}
	else
	{
		set guiButtons["rwy"]:Text to round(runwayEnd2:heading, 1) + "° " + round(runwayEnd2:Distance * 0.001, 1) + " km".
	}
	
	if Time:Seconds - lastFuelTime >= 1
	{
		local fuelAmount is 0.
		for r in Ship:Resources
		{
			if r:Density > 0
				set fuelAmount to fuelAmount + r:Amount.
		}
		
		local fuelCons is (lastFuelAmount - fuelAmount) / (Time:Seconds - lastFuelTime).
		set fuelConsText:Text to round(1000 * fuelCons / Ship:GroundSpeed, 2) + " / km".
		set lastFuelAmount to fuelAmount.
		set lastFuelTime to Time:Seconds.
	}

    // throttle update rate
    wait 0.
}

ClearGuis().

set Ship:Control:Neutralize to true.
