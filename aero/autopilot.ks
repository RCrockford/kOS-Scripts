// Flight autopilot
@lazyglobal off.

// runway length should be approximately 2.46km
local KnownRunways is lexicon(
	"VAFB", lexicon("end1", latlng(34.585765, -120.641), "end2", latlng(34.585765, -120.6141), "alt", 190, "hdg", 90),
	"KSC", lexicon("end1", latlng(28.612852, -80.6179), "end2", latlng(28.612852, -80.5925), "alt", 78.5, "hdg", 90),
	"Mahia", lexicon("end1", latlng(-39.255965, 177.8504), "end2", latlng(-39.255965, 177.87954), "alt", 165, "hdg", 90),
	"Plesetsk", lexicon("end1", latlng(62.96169, 40.6695), "end2", latlng(62.96169, 40.7185), "alt", 300, "hdg", 90),
	"Churchill", lexicon("end1", latlng(58.738635, -93.8434), "end2", latlng(58.738635, -93.8002), "alt", 86, "hdg", 90)
).

// Wait for unpack
wait until Ship:Unpacked.

if Ship:Status = "Landed"
    gear on.    // Just in case
    
clearscreen.

global lock shipHeading to mod(360 - latlng(90,0):bearing, 360).

global function velocityHeading
{
  local east is vcrs(up:vector, north:vector).

  local trig_x is vdot(north:vector, velocity:surface).
  local trig_y is vdot(east, velocity:surface).

  local result is arctan2(trig_y, trig_x).

  return mod(result + 360, 360).
}

global function shipRoll
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
global lock shipPitch to 90 - vang(Ship:up:vector, Ship:facing:forevector).

global function angle_off
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

global flightTarget is 0.
global flightTargetAlt is 0.

global function getDistanceToTarget
{
	return flightTarget:AltitudePosition(flightTargetAlt):Mag.
}
global function getClimbRateToTarget
{
	return (flightTargetAlt - Ship:Altitude) / (getDistanceToTarget() / Ship:AirSpeed).
}

global function GetEngTemp
{
	parameter aje.

	local ts is aje:GetField("eng. internal temp").
	return ts.
}

local function GetEngineName
{
    parameter aje.

    local shortName is aje:Part:Title.
    if shortName:Length > 7 and shortName:FindAt(" ", 7) >= 0
        set shortName to shortName:SubString(0, shortName:FindAt(" ", 7)).
    return shortName.
}

global currentFlapDeflect is 0.
global allFlaps is list().
global hasReheat is false.
global hasJet is false.
global rocketPlane is false.
global DropTanks is list().
global RamjetEngines is list().
global JetEngines is list().
global enginesFiring is true.
global abortMode is false.
global allChutes is list().

global leftGear is 0.
global rightGear is 0.
global gearList is list().
global jetThrust is 0.

local highAlt is false.

local fuelList is uniqueset().

local jetTempLimits is lexicon("default", 600, "J57-P-8 Turbojet", 705, "J57-P-21 Turbojet", 800, "RD-9B Turbojet", 625, "R-11F2", 900, "J58-P-4", 1200, "Model 304-2 Turbojet", 1000).

for p in Ship:parts
{
	if p:HasModule("FARControllableSurface")
	{
		local farMod is p:GetModule("FARControllableSurface").
        if farMod:HasField("flap setting") and farMod:HasAction("increase flap deflection") and farMod:HasAction("decrease flap deflection")
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
        local templimit is jetTempLimits:Default.
        if jetTempLimits:HasKey(p:Title)
            set tempLimit to jetTempLimits[p:Title].
		local engLex is lexicon("part", p, "aje", engMod, "restartSpeed", 0, "maxtemp", tempLimit, "reheat", engMod:HasField("afterburner throttle"), "heatpid", PIDloop(58, 3750, 1, 4, 100)).
		set engLex:heatpid:SetPoint to (engLex:maxTemp - round(max((engLex:maxTemp - 800) / 50, 2.38)^1.6)) / engLex:maxTemp.
		JetEngines:add(engLex).
	}
	else if p:HasModule("ModuleEnginesAJERamjet")
	{
		local engMod is p:GetModule("ModuleEnginesAJERamjet").
        set hasJet to true.
		set jetThrust to jetThrust + p:PossibleThrust.
		local engLex is lexicon("part", p, "aje", engMod, "maxtemp", 3950, "heatpid", PIDloop(58, 3750, 1, 4, 100)).
		set engLex:heatpid:SetPoint to (engLex:maxTemp - 10) / engLex:maxTemp.
		RamjetEngines:add(engLex).
	}
	else if p:IsType("Engine")
	{
        if p:Ignitions >= 0
			set rocketPlane to true.
	}
    else if p:DecoupledIn >= 0 and p:HasModule("ModuleFuelTanks") and p:Resources:Length > 0
    {
        DropTanks:Add(p).
    }
    
    if p:IsType("Engine")
    {
        for k in p:ConsumedResources:keys
        {
            local res is p:ConsumedResources[k].
            if res:Density > 0
            {
                if k = "LH2"
                    fuelList:Add("LqdHydrogen").
                else
                    fuelList:Add(k).
            }
        }
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
    
    if p:HasModule("ModuleWheelBrakes") or p:HasModule("KSPWheelBrakes")
	{
        gearList:Add(p).
	}
}

global groundPitch is shipPitch.
global function CalcGroundPitch
{
    local frontPos is V(0,0,0).
    local rearPos is V(0,0,0).
    local frontCount is 0.
    local rearCount is 0.
    for g in gearList
    {
		if vdot(g:Position, Ship:RootPart:Facing:ForeVector) > 0.2
        {
            set frontPos to frontPos + g:Bounds:abscenter.
            set frontCount to frontCount + 1.
        }
        else
        {
            set rearPos to rearPos + g:Bounds:abscenter.
            set rearCount to rearCount + 1.
        }
    }
    set frontPos to frontPos / max(frontCount, 1).
    set rearPos to rearPos / max(rearCount, 1).

    set groundPitch to max(-4, min(90 - vang(Facing:UpVector, rearPos - frontPos), 4)).
}

if hasJet
    set rocketPlane to false.

global function setFlaps
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

global function startEngines
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
    
    if rocketPlane
        set guiButtons["rht"]:Pressed to true.

	set Ship:Control:PilotMainThrottle to 1.
}

global function startTaxiEngines
{
    local allEngines is list().
    list engines in allEngines.

    for eng in allEngines
    {
        if eng:Ignitions < 0 and not eng:HasModule("ModuleEnginesAJERamjet")
            eng:Activate.
    }
}

global function stopEngines
{
    local allEngines is list().
    list engines in allEngines.

    for eng in allEngines
    {
        eng:Shutdown.
    }
}

global function runwayNumber
{
	parameter heading.

	local number is round(heading / 10, 0).
	if number < 10
		return "0" + number:ToString.
	return number:ToString.
}

global targetFlightLevel is 120.
global targetSpeed is 0.
global targetHeading is round(shipHeading, 0).
global targetClimbRate is 0.
global targetFixedPitch is 0.
global rotateSpeed is 100.
global landingSpeed is 0.
global controlSense is 1.

if Core:Part:Tag:Contains("rot=")
{
    local f is Core:Part:Tag:Find("rot=") + 4.
    set rotateSpeed to Core:Part:Tag:Substring(f, Core:Part:Tag:Length - f):Split(" ")[0]:ToNumber(rotateSpeed).
}

set rotateSpeed to round(rotateSpeed * 0.2, 0) * 5.
set landingSpeed to round(rotateSpeed * 0.18, 0) * 5.
set targetSpeed to rotateSpeed * 2.

if Ship:Status = "Flying"
{
    set targetFlightLevel to round(Ship:Altitude / 100).
    set targetSpeed to round(Ship:Airspeed).
}

if rocketPlane and not Core:Part:tag:contains("noclimb")
{
	set targetFlightLevel to 0.
	set targetFixedPitch to 25.
}

global runwayEnd1 is latlng(0, 0).
global runwayEnd2 is latlng(0, 0).
global runwayAlt is 0.
global runwayHeading is -1.
global runwayName is "".

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
    
    if closestDist > 4000 and (Ship:Status = "Landed" or Ship:Status = "PreLaunch")
    {
        knownRunways:Add("Unknown", lexicon("end1", Ship:GeoPosition, "end2", Body:GeoPositionOf(Heading(targetHeading, 0):Vector * 2200), "alt", Ship:Altitude, "hdg", targetHeading)).
		set runwayName to "Unknown".
    }

	set runwayEnd1 to knownRunways[runwayName]:end1.
	set runwayEnd2 to knownRunways[runwayName]:end2.
	set runwayAlt to knownRunways[runwayName]:alt.

	set runwayHeading to knownRunways[runwayName]:hdg.
    
    if (Ship:Status = "Landed" or Ship:Status = "PreLaunch")
        set targetHeading to runwayHeading.
}

global flightGui is Gui(300).
set flightGui:X to 200.
set flightGui:Y to flightGui:Y + 60.

local mainBox is flightGui:AddHBox().
local labelBox is mainBox:AddVBox().
set labelBox:style:width to 150.
local controlBox is mainBox:AddVBox().
set controlBox:style:width to 120.
local toggleBox is mainBox:AddVBox().
set toggleBox:style:width to 50.

global guiElements is list().
global guiButtons is lexicon().

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
createGuiControls("pt", "Fixed Pitch", targetFixedPitch, { parameter s. set targetFixedPitch to s:ToNumber(targetFixedPitch). }, "").

global PIDSettings is lexicon(
    "PitchKp", 0.023,
    "PitchKi", 0.088,
    "PitchKd", 0.004,
    "RollKp", 0.022,
    "RollKi", 0.004,
    "RollKd", 0.008,
    "tuneSpeed", 160
).

print " ".
print " ".
print " ".
print " ".
print " ".
print " ".
print " ".

if exists("0:/aero/settings/" + Ship:Name + ".json")
{
    set PIDSettings to readjson("0:/aero/settings/" + Ship:Name + ".json").
    print "Using craft PID settings".
}
else
{
    print "Using default PID settings".
}

global AoAkPTweak is 0.2.

createGuiControls("akp", "AoA kP/kD (Hard Turn)", AoAkPTweak, { parameter s. set AoAkPTweak to s:ToNumber(AoAkPTweak). }, "").
createGuiControls("pkp", "Pitch kP (Tune)",  round(PIDSettings:PitchKp, 6), { parameter s. set PIDSettings:PitchKp to s:ToNumber(PIDSettings:PitchKp). }, "").
createGuiControls("pki", "Pitch kI",  round(PIDSettings:PitchKi, 6), { parameter s. set PIDSettings:PitchKi to s:ToNumber(PIDSettings:PitchKi). }, "").
createGuiControls("pkd", "Pitch kD (Save)",  round(PIDSettings:PitchKd, 6), { parameter s. set PIDSettings:PitchKd to s:ToNumber(PIDSettings:PitchKd). }, "").
createGuiControls("rkp", "Roll kP (Tune)",  round(PIDSettings:RollKp, 6), { parameter s. set PIDSettings:RollKp to s:ToNumber(PIDSettings:RollKp). }, "").
createGuiControls("rki", "Roll kI",  round(PIDSettings:RollKi, 6), { parameter s. set PIDSettings:RollKi to s:ToNumber(PIDSettings:RollKi). }, "").
createGuiControls("rkd", "Roll kD (HighAlt)",  round(PIDSettings:RollKd, 6), { parameter s. set PIDSettings:RollKd to s:ToNumber(PIDSettings:RollKd). }, "").

set guiButtons["akp"]:Pressed to false.
set guiButtons["pkp"]:Pressed to false.
set guiButtons["pki"]:Pressed to false.
set guiButtons["pkd"]:Pressed to false.
set guiButtons["rkp"]:Pressed to false.
set guiButtons["rki"]:Pressed to false.
set guiButtons["rkd"]:Pressed to false.

if rocketPlane
{
	set guiButtons["fl"]:Pressed to false.
	set guiButtons["cr"]:Pressed to false.
	set guiButtons["spd"]:Pressed to false.
}
else
{
	set guiButtons["cr"]:Pressed to false.
	set guiButtons["pt"]:Pressed to false.
}

// climbRate / altitude control are exclusive
set guiButtons["fl"]:OnToggle to { parameter val. if val { set guiButtons["cr"]:Pressed to false. set guiButtons["pt"]:Pressed to false. } }.
set guiButtons["cr"]:OnToggle to { parameter val. if val set guiButtons["fl"]:Pressed to false. set guiButtons["pt"]:Pressed to false. }.
set guiButtons["pt"]:OnToggle to { parameter val. if val set guiButtons["fl"]:Pressed to false. set guiButtons["cr"]:Pressed to false. }.

createGuiControls("to", "Rotate Speed", rotateSpeed, { parameter s. set rotateSpeed to s:ToNumber(rotateSpeed). }, "TO").
createGuiControls("lnd", "Landing Speed", landingSpeed, { parameter s. set landingSpeed to s:ToNumber(landingSpeed). }, "Land").

local fuelConsText is 0.
if hasReheat
{
	createGuiControls("rht", "Fuel / Range  (Reheat)", 0, 0, "").
	set guiButtons["rht"]:Pressed to true.
}
else if rocketPlane
{
	createGuiControls("rht", "Fuel / Range (Engines)", 0, 0, "").
	set guiButtons["rht"]:Pressed to false.
    stopEngines().
}
else
{
	createGuiInfo("rht", "Fuel / Range", "0").
}
set fuelConsText to guiElements[guiElements:Length-1].

createGuiControls("gav", "Ground Avoidance", 0, 0, "").
set guiButtons["gav"]:Pressed to true.
set guiElements[guiElements:Length-1]:Text to "".

createGuiInfo("rwy", runwayName + " Runway", "0.0° 0.0 km").
createGuiInfo("dbg", "Debug", "").
global debugName is guiElements[guiElements:Length-2].

global groundHeading is round(shipHeading, 1).
global onGround is true.

global fs_Landed is 0.
global fs_Takeoff is 1.
global fs_TakeoffSpool is 2.
global fs_Taxi is 4.
global fs_TaxiTurn is 5.
global fs_Airlaunch is 8.
global fs_Flight is 10.
global fs_LandInitApproach is 20.
global fs_LandTurn is 21.
global fs_LandInterApproach is 22.
global fs_LandFinalApproach is 23.
global fs_LandTouchdown is 24.
global fs_LandBrakeHeading is 25.
global fs_LandBrake is 26.
global fs_LandManual is 27.
global fs_LandDitch is 28.

global flightState is fs_Flight.
set debugName:Text to "Flight".

global landingTarget is 0.
global approachDirLat is 0.
global approachDirLng is 0.

local buttonBox is flightGui:AddHBox().

global taxiButton1 is buttonBox:AddButton("Taxi " + runwayNumber(runwayHeading)).
global taxiButton2 is buttonBox:AddButton("Taxi " + runwayNumber(mod(runwayHeading + 180, 360))).
global taxiHeading is -1.

global TOPitchScale is 0.2.
local SteeringLocked is 0.

Core:Part:GetModule("kOSProcessor"):DoEvent("Open Terminal").

if Ship:status = "PreLaunch" or Ship:status = "Landed"
{
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

local rebootButton is buttonBox:AddButton("Reboot").
local exitButton is buttonBox:AddButton("Exit").

global lastFuelAmount is 0.
local lastFuelTime is Time:Seconds.

global maxClimbAngle is choose 45 if jetThrust / (ship:mass * 9.81) >= 0.8 else 30.
if rocketPlane
    set maxClimbAngle to 60.

runoncepath("0:/aero/shipcontrol").
runoncepath("0:/aero/flightcontrol").
runoncepath("0:/aero/takeoffcontrol").
runoncepath("0:/aero/landingcontrol").

// Configure AA
//set addons:aa:fbw to true.
//set addons:aa:pseudoflc to false.
//set addons:aa:maxg to 9.
//set addons:aa:maxsideg to 8.
//set addons:aa:moderateaoa to true.
//set addons:aa:moderatesideslip to true.
//set addons:aa:moderateg to true.
//set addons:aa:moderatesideg to true.
//set addons:aa:rollratelimit to 1.
//set addons:aa:wingleveler to true.
//set addons:aa:directorstrength to 0.6.
//set addons:aa:maxclimbangle to maxClimbAngle.
print "TWR=" + round(jetThrust / (ship:mass * 9.81), 2) + " maxclimb=" + maxClimbAngle.

FlightGui:Show().

//local TempTune is lexicon(
//    "Crossings", 0,
//    "StartTime", 0,
//    "SetPoint", 0.95,
//    "PrevValue", 0,
//    "MinValue", 0,
//    "MaxValue", 0,
//    "OutHigh", 100,
//    "OutLow", 50,
//    "Kp", 0,
//    "Ki", 0,
//    "Kd", 0
//).
//
//// Temp tuning
//brakes on.
//StartEngines().
//
//set TempTune:StartTime to Time:Seconds.
//set TempTune:PrevValue to GetEngTemp(jetEngines[0]:aje) / jetEngines[0]:maxtemp.
//set TempTune:MinValue to TempTune:PrevValue.
//set TempTune:MaxValue to TempTune:PrevValue.
//
//until TempTune:Crossings >= 500
//{
//    local thrustLim is PIDTuning(GetEngTemp(jetEngines[0]:aje) / jetEngines[0]:maxtemp, TempTune).
//
//    local line is 39 - jetEngines:Length - RamjetEngines:Length.
//    for jet in jetEngines
//    {
//        set jet:part:ThrustLimit to thrustLim.
//        print jet:part:Title + ": " + round(GetEngTemp(jet:aje), 1) + "/" + round(jet:maxtemp) at (30,line).
//        set line to line + 1.
//    }
//    wait 0.
//}
//
//StopEngines().

until exitButton:TakePress
{
    if rebootButton:TakePress
        reboot.

	// Engine heating control
    local line is 39 - jetEngines:Length - RamjetEngines:Length.
	if not jetEngines:Empty
	{
		for jet in jetEngines
		{
			if jet:maxTemp > 0
			{
				if jet:part:Ignition
				{
                    local et is GetEngTemp(jet:aje).
					set jet:part:ThrustLimit to jet:heatpid:Update(time:seconds, et / jet:maxtemp).
                    print GetEngineName(jet) + ": " + round(et, 1) + "/" + round(jet:maxtemp) + "K " + round(jet:part:ThrustLimit, 1) + "%   " at (28,line).
                    set line to line + 1.

					if jet:part:ThrustLimit >= 50
					{
						set jet:restartSpeed to floor(Ship:AirSpeed).
					}
					else if (jet:part:ThrustLimit <= 20 or jet:part:Thrust <= 0) and jet:restartSpeed > 200 and Ship:AirSpeed > jet:restartSpeed + 1
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
				set jet:part:ThrustLimit to 100.
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
                local et is GetEngTemp(jet:aje).
				set jet:part:ThrustLimit to jet:heatpid:Update(time:seconds, et / jet:maxtemp).
                print GetEngineName(jet) + ": " + round(et, 1) + "/" + round(jet:maxtemp) + "K " + round(jet:part:ThrustLimit, 1) + "%   " at (28,line).
                set line to line + 1.
			}
		}
	}
    
    if rocketPlane
    {
        local allEngines is list().
        list engines in allEngines.

        for eng in allEngines
        {
            if eng:Ignition <> guiButtons["rht"]:Pressed
            {
                if guiButtons["rht"]:Pressed and eng:Ignitions <> 0
                    eng:Activate.
                else if not guiButtons["rht"]:Pressed
                    eng:Shutdown.
            }
        }
    }
    
    if not DropTanks:Empty
    {
        local printLine is 1.
        local dropCount is 0.
    
        for t in DropTanks
        {
            local fuelAmount is 0.
            local fuelCapacity is 0.
            for r in t:Resources
            {
                set fuelAmount to fuelAmount + r:Amount * r:Density.
                set fuelCapacity to fuelCapacity + r:Capacity * r:Density.
            }
        
            print "Drop Tank " + printLine + ": " + round(100 * fuelAmount / fuelCapacity, 1) + "%    " at (0, printLine + 30).
            set printLine to printLine + 1.
            
            if fuelAmount / fuelCapacity < 0.0005
                set dropCount to dropCount + 1.
        }
        
        if dropCount = DropTanks:Length
        {
            print "Dropping tanks.".
            stage.
            dropTanks:Clear.
        }
    }

	if flightState <> fs_Landed
	{
        local ctrlState is lexicon(
            "enabled", true,
            "climbRate", -1e8,
            "pitch", shipPitch,
            "heading", -1,
            "speed", 0,
            "goAround", false
        ).

		if flightState = fs_Takeoff or flightState = fs_Airlaunch
		{
			set ctrlState to TakeoffControl(ctrlState).
		}
        else if flightState = fs_TakeoffSpool
        {
            TakeoffSpoolControl().
        }
		else if flightState = fs_Flight
		{
			set ctrlState to FlightControl(ctrlState).
		}
		else if flightState >= fs_LandInitApproach
        {
			set ctrlState to LandingControl(ctrlState).
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
		if not rocketPlane and flightState >= fs_Flight and flightState <= fs_LandTouchdown
		{
			set abortMode to false.
            if guiButtons["gav"]:Pressed
            {
                if flightState >= fs_LandFinalApproach
                    set abortMode to Ship:VerticalSpeed < -8 and Ship:VerticalSpeed * -5 > Alt:Radar.
                else
                    set abortMode to Ship:VerticalSpeed * -10 > Alt:Radar.
            }

			if abortMode or ctrlState:goAround
			{
				print "Aborting landing: vs=" + round(Ship:VerticalSpeed,1) + " h=" + round(Alt:Radar, 1).
				// do a go around, full throttle, 20 degree pitch up, neutral steering.
				set Ship:Control:PilotMainThrottle to 1.	// Always use reheat for go around.
				set ctrlState:Speed to 0.
				set ctrlState:ClimbRate to -1e8.
				set ctrlState:Pitch to 20.
				set ctrlState:Heading to -1.
				set groundHeading to shipHeading.
				set flightState to fs_Takeoff.
				set guiButtons["hdg"]:Pressed to false.
                if abortMode
                    set debugName:Text to "Abort".
                else
                    set debugName:Text to "Go Around".
                if currentFlapDeflect < 2
                    setFlaps(2).
                brakes off.
				when alt:radar >= 20 and Ship:VerticalSpeed > 0 then { gear off. if currentFlapDeflect > 1 setFlaps(1). }
			}
		}
		
		if rocketPlane and flightState = fs_Flight
		{
            if Ship:Altitude > 32000
            {
                set highAlt to true.
            }
            
            if Ship:VerticalSpeed < 0
            {
                if highAlt and Ship:Altitude < 24000 and Ship:VerticalSpeed > -150 and Ship:AirSpeed < 1100
                    set highAlt to false.

                if highAlt
                {
                    set ctrlState:Pitch to 90 - vang(Ship:up:vector, Ship:Velocity:Surface).
                    set ctrlState:ClimbRate to -1e8.
                    if Ship:VerticalSpeed < -100
                        set ctrlState:Pitch to ctrlState:Pitch + min((-100 - Ship:VerticalSpeed) / 40, min(72 / (Ship:AirSpeed / 1000)^2, 25)).
                }
            }

            if Ship:Altitude > 24000
                rcs on.
            else if Ship:Altitude < 20000 and Ship:VerticalSpeed > -150
                rcs off.
        }
        
        if navmode <> "surface"
            set navmode to "surface".

		if highAlt or guiButtons:rkd:pressed
		{
            set ctrlState:Heading to velocityHeading().

            if SteeringLocked = 0
            {
                set Ship:Control:Neutralize to true.
                set SteeringManager:RollControlAngleRange to 180.
                set SteeringLocked to heading(ctrlState:Heading, ctrlState:Pitch):Vector.
                lock steering to SteeringLocked.
            }

            set SteeringLocked to heading(ctrlState:Heading, ctrlState:Pitch):Vector.
            print "HighAlt " + round(ctrlState:Heading, 1) + "° p=" + round(ctrlState:Pitch, 1) + "/" + round(shipPitch, 1) + "°            " at (0,0).
		}
		else 
		{
            if SteeringLocked <> 0
            {
                unlock steering.
                set SteeringLocked to 0.
                SteeringReset().
            }
			if ctrlState:Enabled
			{
				SteeringControl(ctrlState).
			}
			else
			{
				set Ship:Control:Neutralize to true.
				print "Manual                                         " at (0,0).
			}
		}

        ThrottleControl(ctrlState).
		GroundControl(ctrlState).

        if ctrlState:Enabled and (abs(Ship:Control:PilotYaw) > 0.8 or abs(Ship:Control:PilotPitch) > 0.8 or abs(Ship:Control:PilotRoll) > 0.8)
        {
            set guiButtons["fl"]:Pressed to false.
            set guiButtons["cr"]:Pressed to false.
            set guiButtons["pt"]:Pressed to false.
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
		BeginTakeoff().
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

		set flightState to fs_Airlaunch.
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
		local fuelCapacity is 0.
        local line is 38 - fuelList:Length.
		for r in Ship:Resources
		{
			if fuelList:Contains(r:Name)
            {
				set fuelAmount to fuelAmount + r:Amount.
                set fuelCapacity to fuelCapacity + r:Capacity.
                print r:Name + ": " + round(r:Amount, 2) + " [" + round(100 * r:Amount / r:Capacity, 1) + "%]   " at (0,line).
                set line to line + 1.
            }
		}
        if fuelCapacity > 0
            print "Total: " + round(fuelAmount, 2) + " [" + round(100 * fuelAmount / fuelCapacity, 1) + "%]   " at (0,line).
        
		local fuelCons is (lastFuelAmount - fuelAmount) / (Time:Seconds - lastFuelTime).
        local fuelTime is fuelAmount / max(fuelCons, 1e-6).
        if fuelTime > 3600
        {
            set fuelTime to round(fuelTime / 3600, 2) + " h".
        }
        else if fuelTime > 90
        {
            set fuelTime to round(fuelTime / 60, 2) + " m".
        }
        else
        {
            set fuelTime to round(fuelTime, 1) + " s".
        }
		
		set fuelConsText:Text to fuelTime + " / " + round(Ship:GroundSpeed * fuelAmount / max(fuelCons * 1000, 1e-3)) + " km".
		set lastFuelAmount to fuelAmount.
		set lastFuelTime to Time:Seconds.
        
        if fuelAmount < 1 or fuelAmount / fuelCapacity < 0.01
            set rocketPlane to true.
	}

    // throttle update rate
    wait 0.
}

ClearGuis().

set Ship:Control:Neutralize to true.
