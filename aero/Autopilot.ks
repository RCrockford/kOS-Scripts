// Flight autopilot
@lazyglobal off.

// Wait for unpack
wait until Ship:Unpacked.

local lock shipHeading to mod(360 - latlng(90,0):bearing, 360).
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
local function getHeadingToTarget
{
	parameter target is flightTarget.

    local dir is vxcl(Ship:Up:Vector, target + Ship:Body:Position).
    local ang is vang(dir, Ship:North:Vector).
    if vdot(dir, vcrs(Ship:North:Vector, Ship:Up:Vector)) > 0
        set ang to 360 - ang.
	return ang.
}
local function getDistanceToTarget
{
	parameter target is flightTarget.
	
	return (target + Ship:Body:Position):Mag.
}
local function getClimbRateToTarget
{
	return vdot(flightTarget + Ship:Body:Position, Ship:Up:Vector) / (getDistanceToTarget() / Ship:AirSpeed).
}

local currentFlapDeflect is 0.
local allFlaps is list().
local hasReheat is false.
local rocketPlane is false.
local initialClimb is true.
local abortMode is false.
local allChutes is list().

local leftGear is 0.
local rightGear is 0.

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
		{
			set hasReheat to true.
		}
	}
	else if p:HasModule("ModuleEnginesRF")
	{
		local engMod is p:GetModule("ModuleEnginesRF").
		if engMod:HasField("ignitions remaining")
		{
			set rocketPlane to true.
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
}

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

local targetFlightLevel is 50.
local targetSpeed is 250.
local targetHeading is round(shipHeading, 0).
local targetClimbRate is 0.
local rotateSpeed is 120.
local landingSpeed is 90.
local controlSense is 1.
local climbKP is 1.
local climbKI is 0.1.
local climbKD is 0.25.
local maxThrottle is 1.

if rocketPlane and not ship:rootpart:tag:contains("noclimb")
{
	set targetFlightLevel to 0.
	set targetClimbRate to 50.
}
else
{
	set initialClimb to false.
}

local pitchPid is PIDloop(0.02, 0.001, 0.02, -1, 1).
local rollPid is PIDloop(0.005, 0.00005, 0.001, -1, 1).
local throtPid is PIDloop(0.1, 0.002, 0.05, 0, 1).
local bankPid is PIDloop(3, 0.0, 5, -45, 45).
local climbRatePid is pidloop(0.5, 0.01, 0.1, -40, 45).
local climbSpeedPid is pidloop(0.25, 0.01, 0.2).
local wheelPid is PIDLoop(0.15, 0, 0.1, -1, 1).

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
//createGuiControls("sns1", "Ctrl Sensitivity", controlSense, { parameter s. set controlSense to s:ToNumber(controlSense). }, "").
//createGuiControls("sns2", "Climb kP", climbKP, { parameter s. set climbKP to s:ToNumber(climbKP). }, "").
//createGuiControls("sns3", "Climb kI", climbKI, { parameter s. set climbKI to s:ToNumber(climbKI). }, "").
//createGuiControls("sns4", "Climb kD", climbKD, { parameter s. set climbKD to s:ToNumber(climbKD). }, "").

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
set guiButtons["fl"]:OnToggle to { parameter val. if val { climbSpeedPID:Reset(). set guiButtons["cr"]:Pressed to false. } }.
set guiButtons["cr"]:OnToggle to { parameter val. if val set guiButtons["fl"]:Pressed to false. }.

createGuiControls("to", "Rotate Speed", rotateSpeed, { parameter s. set rotateSpeed to s:ToNumber(rotateSpeed). }, "TO").
createGuiControls("lnd", "Landing Speed", landingSpeed, { parameter s. set landingSpeed to s:ToNumber(landingSpeed). }, "Land").

if hasReheat
{
	createGuiControls("rht", "Reheat", 0, 0, "").
	set guiButtons["rht"]:Pressed to false.
}

createGuiInfo("rwh", "Runway Heading", "0.0°").
createGuiInfo("rwd", "Runway Distance", "0.0 km").
createGuiInfo("dbg", "Debug", "").
local debugName is guiElements[guiElements:Length-2].

local exitButton is flightGui:AddButton("Exit").

local groundHeading is round(shipHeading, 1).
local stallSpeed is 0.
local throttleDamp is 0.
local throttlePrev is 0.
local prevReqClimb is 0.
local lastUpdate is Time:Seconds.

local fs_Landed is 0.
local fs_Takeoff is 1.
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

local runwayEnd1 is V(0,0,0).
local runwayEnd2 is V(0,0,0).
local runwayCentre is V(0,0,0).
local runwayHeading is -1.

local landingTarget is V(0,0,0).

local function runwayNumber
{
	parameter heading.
	
	local number is round(heading / 10, 0).
	if number < 10
		return "0" + number:ToString.
	return number:ToString.
}

if Ship:status = "PreLaunch" or Ship:status = "Landed"
{
    Core:Part:GetModule("kOSProcessor"):DoEvent("Open Terminal").

	set flightState to fs_Landed.
	set debugName:Text to "Landed".
	set guiButtons["to"]:Enabled to true.
	set guiButtons["lnd"]:Enabled to false.

	set runwayHeading to round(shipHeading, 1).
	set runwayEnd1 to -Ship:Body:Position.
	set runwayEnd2 to runwayEnd1 + Heading(shipHeading, 0):Vector * 2400.
	set Ship:Type to "Plane".
	
	set runwayCentre to (runwayEnd1 + runwayEnd2) * 0.5.

	print "Takeoff from runway " + runwayNumber(runwayHeading).
}

FlightGui:Show().

until exitButton:TakePress
{
	if hasReheat
	{
		if guiButtons["rht"]:Pressed
			set maxThrottle to 1.
		else
			set maxThrottle to 2/3.
	}

	if flightState <> fs_Landed
	{
		local reqClimbRate is -1e8.
        local reqPitch is shipPitch.
		local reqHeading is shipHeading.
		local reqControl is true.
		local reqSpeed is 0.

		if flightState = fs_Takeoff
		{
			if Ship:GroundSpeed >= rotateSpeed or Ship:Status = "Flying"
			{
				// 10 degree rotation
				set reqPitch to 10.
				if rocketPlane or abortMode
					set reqPitch to 20.
			}

			if reqPitch > 0 and Ship:Status = "Flying" and stallSpeed = 0
			{
				set stallSpeed to Ship:AirSpeed.
				print "Stall speed set to " + round(stallSpeed, 1).
                set Ship:Control:WheelSteer to 0.
			}
            else if Ship:Status = "Landed"
            {
                set stallSpeed to 0.
            }

			set reqHeading to groundHeading.
			set Ship:Control:PilotMainThrottle to 1.
				
			local minAlt is 250.
			if initialClimb
				set minAlt to 10.
			else if abortMode
				set minAlt to 500.

			if Alt:Radar > minAlt and Ship:VerticalSpeed > 0
			{
                setFlaps(0).
				set flightState to fs_Flight.
				set debugName:Text to "Flight".
				set guiButtons["lnd"]:Enabled to true.
			}
            
            if reqPitch < 10 and abs(angle_off(groundHeading, shipHeading)) > 5
            {
                print "Veering off course too far, check wheel steering. Takeoff aborted.".
            
                brakes on.
                set Ship:Control:PilotMainThrottle to 0.
            
				set flightState to fs_LandBrakeHeading.
				set debugName:Text to "Brake".
				set guiButtons["to"]:Enabled to true.      

				set flightTarget to runwayEnd2.
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
					}
				}
				else if guiButtons["fl"]:Pressed
				{
					local altError is targetflightLevel * 100 - Ship:Altitude.
					set reqClimbRate to max(-Ship:Airspeed * 0.25, min(Ship:Airspeed * 0.25, 15 * altError / Ship:Airspeed)).

					// Cap maximum climb rate to avoid reducing speed too much
					if reqClimbRate > Ship:Airspeed * 0.2
					{
						set climbSpeedPid:MinOutput to -reqClimbRate.
						set climbSpeedPid:MaxOutput to reqClimbRate.

						local minSpeed is stallSpeed * 1.5.
						if guiButtons["spd"]:Pressed
							set minSpeed to targetSpeed.

						set reqClimbRate to reqClimbRate + climbSpeedPID:Update(Time:Seconds, minSpeed - Ship:AirSpeed).
					}
				}
				else if guiButtons["cr"]:Pressed
				{
					set reqClimbRate to targetClimbRate.
				}

				if initialClimb
				{
					set reqHeading to shipHeading.
				}
				else if guiButtons["hdg"]:pressed
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
				// If climbing always use 100% throttle and adjust pitch
				if not guiButtons["fl"]:Pressed or targetflightLevel * 100 < Ship:Altitude + max(Ship:VerticalSpeed * 5, 50)
				{
					set reqSpeed to targetSpeed.
				}
                else
                {
                    set Ship:Control:PilotMainThrottle to maxThrottle.
                }
			}

			if guiButtons["lnd"]:TakePress
			{
				if runwayHeading >= 0
				{
					if (-Ship:Body:Position - runwayEnd1):SqrMagnitude < (-Ship:Body:Position - runwayEnd2):SqrMagnitude
					{
						set landingTarget to runwayEnd1.
						set groundHeading to runwayHeading.
					}
					else
					{
						set landingTarget to runwayEnd2.
						set groundHeading to mod(runwayHeading + 180, 360).
					}

					print "Landing at runway " + runwayNumber(groundHeading).

					// initial approach marker at 12 km out, 1km alt.
					set flightTarget to landingTarget - heading(groundHeading, 0):Vector * 12000 + Ship:Up:Vector * 1000.
					if rocketPlane
						set flightTarget to flightTarget + Ship:Up:Vector * 600.
					set flightState to fs_LandInitApproach.
					set debugName:Text to "Initial Approach".
					set guiButtons["lnd"]:Enabled to false.
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
			set reqHeading to getHeadingToTarget().
			set reqSpeed to (1.5 + getDistanceToTarget() / 10000) * landingSpeed.
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
					set flightTarget to landingTarget - heading(groundHeading, 0):Vector * 4000 + Ship:Up:Vector * 250.
					if rocketPlane
						set flightTarget to flightTarget + Ship:Up:Vector * 100.
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
			set reqClimbRate to (1000 - Ship:Altitude) * 0.025.
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
			set reqClimbRate to getClimbRateToTarget().
			set reqHeading to getHeadingToTarget().
			set reqSpeed to min((1 + getDistanceToTarget() / 16000), 1.5) * landingSpeed.
			
			set guiButtons["dbg"]:Text to round(reqHeading, 1) + "° " + round(getDistanceToTarget() * 0.001, 2) + "/0.05".

			if getDistanceToTarget() < 50
			{
				kUniverse:Timewarp:CancelWarp().
				set flightState to fs_LandFinalApproach.
				set debugName:Text to "Final".
				set flightTarget to landingTarget + Ship:Up:Vector * 10.
				setFlaps(3).
				gear on.
				when alt:radar < 200 then { lights off. lights on. }
				print "Final approach".
			}
		}
		else if flightState = fs_LandFinalApproach
		{
			set reqHeading to getHeadingToTarget().
			set reqSpeed to landingSpeed.
			
			set guiButtons["dbg"]:Text to round(reqHeading, 1) + "° ".

			if Alt:radar < 30 or (Alt:Radar < 40 and rocketPlane)
			{
				set reqClimbRate to -2.
				set reqHeading to groundHeading.
			}
			else
			{
				set reqClimbRate to getClimbRateToTarget().
				if not rocketPlane
					set reqClimbRate to max(reqClimbRate, -6).
			}
            
			if Alt:Radar < 10
			{
				// Flare
				set reqClimbRate to -0.5.
			}

			if Ship:Status = "Landed"
			{
				brakes on.
				print "Braking".
				set flightState to fs_LandBrakeHeading.
				set debugName:Text to "Brake".
				if (landingTarget - runwayEnd1):SqrMagnitude < (landingTarget - runwayEnd2):SqrMagnitude
					set flightTarget to runwayEnd2.
				else
					set landingTarget to runwayEnd1.
			}
		}
		else if flightState = fs_LandBrake or flightState = fs_LandBrakeHeading
		{
			set Ship:Control:PilotMainThrottle to 0.
			if flightState = fs_LandBrakeHeading
				set groundHeading to getHeadingToTarget().
				
			set reqHeading to groundHeading.
            
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
				else if abs(a) < 1
					brakes on.
				else
					brakes off.
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
		
		// Ground collision avoidance
		if not rocketPlane and flightState >= fs_Flight and flightState <= fs_LandFinalApproach
		{
			set abortMode to false.
			if flightState = fs_LandFinalApproach
				set abortMode to abs(angle_off(shipHeading, reqHeading)) >= 8 or (Ship:VerticalSpeed < -8 and Ship:VerticalSpeed * -5 > Alt:Radar).
			else
				set abortMode to Ship:VerticalSpeed * -10 > Alt:Radar.
				
			if abortMode
			{
				print "Aborting landing".
				// do a go around, full throttle, 10 degree pitch up, neutral steering.
				set Ship:Control:PilotMainThrottle to 1.	// Always use reheat for go around.
				set reqSpeed to 0.
				set reqClimbRate to -1e8.
				set reqPitch to 20.
				set reqHeading to shipHeading.
				set groundHeading to shipHeading.
				set flightState to fs_Takeoff.
				set guiButtons["hdg"]:Pressed to false.
				set debugName:Text to "Abort".
				setFlaps(2).
				when alt:radar >= 20 and Ship:VerticalSpeed > 0 then { gear off. if currentFlapDeflect > 1 setFlaps(1). }
			}
		}

		if reqControl
		{
            // Anti-stall
            if reqClimbRate > 0
                set reqClimbRate to max(min(reqClimbRate, Ship:Airspeed - stallSpeed), 0).
                
            local ctrlDamp is 120 / max(Ship:AirSpeed, 80).
			if Ship:Status = "Landed"
				set ctrlDamp to ctrlDamp * 1.5.

            if reqClimbRate > -1e6
            {
                print "reqClimbRate=" + round(reqClimbRate, 1) + " / " + round(ship:verticalspeed, 1) + "   " at (0,0).
                
                set climbRatePid:kP to climbKP * ctrlDamp.
                set climbRatePid:kD to climbKD.
				set climbRatePid:kI to climbKI * ctrlDamp.
                
                set climbRatePid:SetPoint to reqClimbRate.
                set reqPitch to climbRatePid:Update(time:seconds, Ship:verticalspeed).
            }
            
            set ctrlDamp to ctrlDamp * max(0.1, min(controlSense, 10)).

            set pitchPid:kP to 0.06 * ctrlDamp.
            set pitchPid:kD to 0.04 * ctrlDamp.
			set pitchPid:kI to 0.002 * ctrlDamp.
            
            set pitchPid:SetPoint to reqPitch.
            set ship:control:pitch to pitchPid:update(time:seconds, ShipPitch).

            print "reqPitch=" + round(reqPitch, 2) + " / " + round(ShipPitch, 2) + "   " at (0,1).

			local reqBank is 0.
			if ((rocketPlane and not initialClimb) or abs(reqClimbRate - ship:verticalspeed) < 50) and alt:radar > 10
			{
				set bankPid:SetPoint to -angle_off(reqHeading, shipHeading).
                // Avoid twitchiness when turning close to 180 degrees.
                if bankPid:SetPoint < -175
                    set bankPid:SetPoint to 180.
				set reqBank to bankPid:Update(time:seconds, 0).
			}
            else
            {
                bankPid:Reset().
            }
			
			set rollPid:kP to 0.005 * ctrlDamp.
			set rollPid:kI to 0.0001 * ctrlDamp.
			set rollPid:kD to 0.002 * ctrlDamp.
			
			set rollPid:SetPoint to reqBank.
			set ship:control:roll to rollPid:Update(time:seconds, shipRoll()).
        }
		else
		{
			set Ship:Control:Neutralize to true.
            
			climbRatePid:Reset().
            pitchPid:Reset().
            rollPid:Reset().
        }

		if reqSpeed > 0
		{
			set throtPid:MaxOutput to maxThrottle.
		
			// Throttle control
			set throtPid:SetPoint to reqSpeed.
			set Ship:Control:PilotMainThrottle to throttleDamp * throttlePrev + throtPid:Update(time:seconds, Ship:AirSpeed) * (1 - throttleDamp).
            set throttleDamp to max(0, throttleDamp - 0.05).
        }
        else
        {
            set throttleDamp to 1.
            set throttlePrev to Ship:Control:PilotMainThrottle.
            throtPid:Reset().
        }

		if Ship:Status = "Landed"
		{
			local wheelError is angle_off(groundHeading, shipHeading).

			set wheelPid:kP to 0.02 / max(1, Ship:GroundSpeed / 12).
			set wheelPid:kD to wheelPid:kP * 2 / 3.

			set Ship:Control:WheelSteer to wheelPid:update(time:seconds, -wheelError).

			set guiButtons["dbg"]:Text to round(groundHeading, 1) + "° ".
		}
        else
        {
            wheelPid:Reset().
        }

        if reqControl and (abs(Ship:Control:PilotYaw) > 0.8 or abs(Ship:Control:PilotPitch) > 0.8 or abs(Ship:Control:PilotRoll) > 0.8)
        {
            set guiButtons["fl"]:Pressed to false.
            set guiButtons["cr"]:Pressed to false.
            set guiButtons["hdg"]:Pressed to false.
            set guiButtons["spd"]:Pressed to false.
            set flightState to fs_Flight.
			set debugName:Text to "Flight".
            set Ship:Control:PilotMainThrottle to maxThrottle.
            
            print "Autopilot disengaged.".
            
            set guiButtons["lnd"]:Enabled to true.
        }
	}
	else if guiButtons["to"]:TakePress
	{
		set flightState to fs_Takeoff.
		set debugName:Text to "Takeoff".
		set guiButtons["to"]:Enabled to false.

		set groundHeading to round(shipHeading, 1).

		if Ship:Status = "PreLaunch"
		{
			print "Engine start.".
			stage.
		}
		
		local allEngines is list().
		list engines in allEngines.

		for eng in allEngines
		{
			if eng:Stage = stage:Number
				eng:Activate().
		}

		set Ship:Control:PilotMainThrottle to maxThrottle.

		setFlaps(2).

		if brakes
		{
			print "Waiting for engines to spool.".

			local engineMaxThrust is 0.
			for eng in allEngines
			{
				if eng:Stage = stage:Number
					set engineMaxThrust to engineMaxThrust + eng:PossibleThrust().
			}

			local engineThrust is 0.
			until engineThrust > engineMaxThrust * 0.5 * maxThrottle
			{
				set engineThrust to 0.
				for eng in allEngines
				{
					if eng:Stage = stage:Number
						set engineThrust to engineThrust + eng:Thrust().
				}
				wait 0.
			}
		}
		brakes on.
		brakes off.

		print "Beginning takeoff roll.".

		when alt:radar >= 20 then { gear off. if currentFlapDeflect > 1 setFlaps(1). }
	}
	
	set guiButtons["rwh"]:Text to round(getHeadingToTarget(runwayCentre), 1) + "°".
	set guiButtons["rwd"]:Text to round(getDistanceToTarget(runwayCentre) * 0.001, 1) + " km".
 
    // throttle update rate
    wait 0.
}

ClearGuis().

set Ship:Control:Neutralize to true.
