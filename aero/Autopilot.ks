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
    local dir is vxcl(Ship:Up:Vector, flightTarget + Ship:Body:Position).
    local ang is vang(dir, Ship:North:Vector).
    if vdot(dir, vcrs(Ship:North:Vector, Ship:Up:Vector)) > 0
        set ang to 360 - ang.
	return ang.
}
local function getDistanceToTarget
{
	return (flightTarget + Ship:Body:Position):Mag.
}
local function getClimbRateToTarget
{
	return vdot(flightTarget + Ship:Body:Position, Ship:Up:Vector) / (getDistanceToTarget() / Ship:AirSpeed).
}

local currentFlapDeflect is 0.
local allFlaps is list().
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
local targetSpeed is 150.
local targetHeading is round(shipHeading, 0).
local targetClimbRate is 0.
local rotateSpeed is 80.
local landingSpeed is 80.

local pitchPid is PIDloop(0.02, 0.001, 0.02, -1, 1).
local rollPid is PIDloop(0.005, 0.00005, 0.001, -1, 1).
local yawPid is PIDloop(0.1, 0.005, 0.03, -1, 1).
local bankPid is PIDloop(3, 0.0, 5, -45, 45).
local throtPid is PIDloop(0.1, 0.001, 0.05, 0, 1).
local climbSpeedPID is pidloop(0.25, 0.01, 0.2).
local wheelPid is PIDLoop(0.15, 0, 0.1, -1, 1).

local flightGui is Gui(300).
set flightGui:X to 100.
set flightGui:Y to flightGui:Y + 50.

local mainBox is flightGui:AddHBox().
local labelBox is mainBox:AddVBox().
set labelBox:style:width to 150.
local controlBox is mainBox:AddVBox().
set controlBox:style:width to 100.
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
    set ctrl:OnConfirm to dlg.
    guiElements:add(ctrl).
    
    if btnStr:Length > 0
        set ctrl to toggleBox:AddButton(BtnStr).
    else
        set ctrl to toggleBox:AddCheckBox(BtnStr, true).
    set ctrl:Style:Height to 25.
    guiButtons:add(tagStr, ctrl).
}

createGuiControls("hdg", "Heading", targetHeading, { parameter s. set targetHeading to s:ToNumber(targetHeading). }, "").
createGuiControls("spd", "Airspeed", targetSpeed, { parameter s. set targetSpeed to s:ToNumber(targetSpeed). }, "").
createGuiControls("fl", "Flight Level", targetFlightLevel, { parameter s. set targetFlightLevel to s:ToNumber(targetFlightLevel). }, "").
createGuiControls("cr", "Climb Rate", targetClimbRate, { parameter s. set targetClimbRate to s:ToNumber(targetClimbRate). }, "").

set guiButtons["cr"]:Pressed to false.

// climbRate / altitude control are exclusive
set guiButtons["fl"]:OnToggle to { parameter val. if val { climbSpeedPID:Reset(). set guiButtons["cr"]:Pressed to false. } }.
set guiButtons["cr"]:OnToggle to { parameter val. if val set guiButtons["fl"]:Pressed to false. }.

createGuiControls("to", "Rotate Speed", rotateSpeed, { parameter s. set rotateSpeed to s:ToNumber(rotateSpeed). }, "TO").
createGuiControls("lnd", "Landing Speed", landingSpeed, { parameter s. set landingSpeed to s:ToNumber(landingSpeed). }, "Land").

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

local flightState is fs_Flight.

local runwayEnd1 is V(0,0,0).
local runwayEnd2 is V(0,0,0).
local runwayHeading is -1.

local landingTarget is V(0,0,0).

if Ship:status = "PreLaunch" or Ship:status = "Landed"
{
    Core:Part:GetModule("kOSProcessor"):DoEvent("Open Terminal").

	set flightState to fs_Landed.
	set guiButtons["to"]:Enabled to true.
	set guiButtons["lnd"]:Enabled to false.

	set runwayHeading to round(shipHeading, 1).
	set runwayEnd1 to -Ship:Body:Position + Heading(shipHeading, 0):Vector * 200.
	set runwayEnd2 to runwayEnd1 + Heading(shipHeading, 0):Vector * 2200.

	print "Takeoff from runway " + round(runwayHeading / 10, 0).
}

FlightGui:Show().

until exitButton:TakePress
{
	if flightState <> fs_Landed
	{
		local reqClimbRate is 0.
		local reqHeading is shipHeading.
		local reqControl is true.
		local reqSpeed is 0.

		if flightState = fs_Takeoff
		{
			if Ship:GroundSpeed >= rotateSpeed or Ship:Status = "Flying"
			{
				// 10 degree rotation
				set reqClimbRate to 10.
			}

			if reqClimbRate > 0 and Ship:Status = "Flying" and stallSpeed = 0
			{
				set stallSpeed to Ship:AirSpeed.
				print "Stall speed set to " + round(stallSpeed, 1).
                set Ship:Control:WheelSteer to 0.
                set Ship:Control:Yaw to 0.
			}
            else if Ship:Status = "Landed"
            {
                set stallSpeed to 0.
            }

			set reqHeading to groundHeading.
			set Ship:Control:PilotMainThrottle to 1.

			if Alt:Radar > 250
			{
                setFlaps(0).
				set flightState to fs_Flight.
				set guiButtons["lnd"]:Enabled to true.
			}
            
            if reqClimbRate = 0 and abs(angle_off(groundHeading, shipHeading)) > 5
            {
                print "Veering off course too far, check wheel steering. Takeoff aborted.".
            
                brakes on.
                set Ship:Control:PilotMainThrottle to 0.
            
				set flightState to fs_LandBrake.
				set guiButtons["to"]:Enabled to true.                
            }
		}
		else if flightState = fs_Flight
		{
			if guiButtons["fl"]:Pressed or guiButtons["cr"]:Pressed or guiButtons["hdg"]:Pressed
			{
				// Altitude control
				if guiButtons["fl"]:Pressed
				{
					local altError is targetflightLevel * 100 - Ship:Altitude.
					set reqClimbRate to max(-Ship:Airspeed * 0.25, min(Ship:Airspeed * 0.25, 15 * altError / Ship:Airspeed)).

					// Cap maximum climb rate to avoid reducing speed too much
					if abs(reqClimbRate) > Ship:Airspeed * 0.2
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
				// If climbing always use 100% throttle and adjust pitch
				if not guiButtons["fl"]:Pressed or targetflightLevel * 100 < Ship:Altitude + max(Ship:VerticalSpeed * 5, 50)
				{
					set reqSpeed to targetSpeed.
				}
                else
                {
                    set Ship:Control:PilotMainThrottle to 1.
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

					print "Landing at runway " + round(groundHeading / 10, 0).

					// initial approach marker at 12 km out, 1km alt.
					set flightTarget to landingTarget - heading(groundHeading, 0):Vector  * 12000 + Ship:Up:Vector * 1000.
					set flightState to fs_LandInitApproach.
					set guiButtons["lnd"]:Enabled to false.
				}
				else
				{
					set flightState to fs_LandManual.
					print "Manual landing assistance active".
					when alt:radar < 200 then { gear on. lights on. }
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

			if getDistanceToTarget() < 250
			{
				if abs(angle_off(groundHeading, shipHeading)) <= 30 and Ship:AirSpeed < reqSpeed * 1.2
				{
					set flightState to fs_LandInterApproach.
					set flightTarget to landingTarget - heading(groundHeading, 0):Vector * 4000 + Ship:Up:Vector * 300.
					setFlaps(2).
					print "On approach".
				}
				else
				{
					set flightState to fs_LandTurn.
				}
			}
		}
		else if flightState = fs_LandTurn
		{
			set reqClimbRate to 0.
			set reqSpeed to 1.5 * landingSpeed.

            if getDistanceToTarget() < 2500
            {
                set reqHeading to mod(groundHeading + 135, 360).
                local heading2 is mod(groundHeading + 225, 360).
                if abs(angle_off(heading2, shipHeading)) < abs(angle_off(reqHeading, shipHeading))
                    set reqHeading to heading2.
            }
			else
            {
                set reqHeading to mod(groundHeading + 180, 360).

                if getDistanceToTarget() > 5000
                {
                    set flightState to fs_LandInitApproach.
                }
            }
        }
		else if flightState = fs_LandInterApproach
		{
			set reqClimbRate to getClimbRateToTarget().
			set reqHeading to getHeadingToTarget().
			set reqSpeed to min((1 + getDistanceToTarget() / 16000), 1.5) * landingSpeed.

			if getDistanceToTarget() < 50
			{
				set flightState to fs_LandFinalApproach.
				set flightTarget to landingTarget + Ship:Up:Vector * 50.
				setFlaps(3).
				gear on.
				lights on.
				print "Final approach".
			}
		}
		else if flightState = fs_LandFinalApproach
		{
			set reqHeading to getHeadingToTarget().
			set reqSpeed to landingSpeed.

			if Alt:radar < 30 or abs(angle_off(reqHeading, groundHeading)) >= 1
			{
				set reqClimbRate to -2.
				set reqHeading to groundHeading.
			}
			else
			{
				set reqClimbRate to getClimbRateToTarget().
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
				set flightState to fs_LandBrake.
			}
		}
		else if flightState = fs_LandBrake
		{
			set Ship:Control:PilotMainThrottle to 0.
			set reqHeading to groundHeading.

			if Ship:GroundSpeed < 1
			{
                setFlaps(0).
				set flightState to fs_Landed.
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
			}
			else if guiButtons["lnd"]:TakePress
			{
				print "Landing assistance cancelled".
				set flightState to fs_Flight.
			}
		}

		if reqControl
		{
            // Anti-stall
            if reqClimbRate > 0
                set reqClimbRate to max(min(reqClimbRate, Ship:Airspeed - stallSpeed), 0).
                
            local deltaT is max(time:seconds - lastUpdate, 0).
            set lastUpdate to time:seconds.

            local ctrlDamp is 120 / max(Ship:AirSpeed, 80).

            if flightState = fs_Takeoff
            {
                // Actually just commanded pitch
                if reqClimbRate > 0
                {
                    set pitchPid:kP to 0.04.
                    set pitchPid:kI to 0.002.
                    set pitchPid:kD to 0.04.
                    
                    set pitchPid:SetPoint to reqClimbRate.
                    set ship:control:pitch to pitchPid:update(time:seconds, shipPitch).
                }
            }
            else
            {
                // cap climb rate delta to 20 m/s^2 (around 2g).
                set deltaT to deltaT * 20.
                set reqClimbRate to max(prevReqClimb - deltaT, min(reqClimbRate, prevReqClimb + deltaT)).
                
                // Prevent over pitching
                if (shipPitch > 40)
                    set reqClimbRate to min(reqClimbRate, Ship:verticalspeed - deltaT).
                if (shipPitch < 40)
                    set reqClimbRate to max(reqClimbRate, Ship:verticalspeed + deltaT).
                
                set prevReqClimb to reqClimbRate.
                
                print "reqClimbRate=" + round(reqClimbRate, 1) + " / " + round(ship:verticalspeed, 1) + "   " at (0,0).
                
                set pitchPid:kP to 0.02 * ctrlDamp.
                set pitchPid:kI to 0.0001 * ctrlDamp.
                set pitchPid:kD to 0.01 * ctrlDamp.
                
                set pitchPid:SetPoint to reqClimbRate.
                set ship:control:pitch to pitchPid:update(time:seconds, Ship:verticalspeed).
            }

			local reqBank is 0.
			if abs(reqClimbRate - ship:verticalspeed) < 50 and alt:radar > 10
			{
				set bankPid:SetPoint to -angle_off(reqHeading, shipHeading).
                // Avoid twitchiness when turning close to 180 degrees.
                if bankPid:SetPoint < -178
                    set bankPid:SetPoint to 180.
				set reqBank to bankPid:Update(time:seconds, 0).
			}
            else
            {
                bankPid:Reset().
            }
            
            set rollPid:kP to 0.005 * ctrlDamp.
            set rollPid:kI to 0.00005 * ctrlDamp.
            set rollPid:kD to 0.001 * ctrlDamp.

			set rollPid:SetPoint to reqBank.
			set ship:control:roll to rollPid:Update(time:seconds, shipRoll()).
        }
		else
		{
			set Ship:Control:Neutralize to true.
            
            aoaPid:Reset().
            pitchPid:Reset().
            rollPid:Reset().
        }

		if reqSpeed > 0
		{
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

			set wheelPid:kP to 0.015 / max(1, Ship:GroundSpeed / 10).
			set wheelPid:kD to wheelPid:kP * 2 / 3.

			set Ship:Control:WheelSteer to wheelPid:update(time:seconds, wheelError).
            set Ship:Control:Yaw to yawPid:Update(time:seconds, wheelError).
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
            set Ship:Control:PilotMainThrottle to 1.
            
            print "Autopilot disengaged.".
            
            set guiButtons["lnd"]:Enabled to true.
        }
	}
	else if guiButtons["to"]:TakePress
	{
		set flightState to fs_Takeoff.
		set guiButtons["to"]:Enabled to false.

		set groundHeading to round(shipHeading, 1).

		if Ship:Status = "PreLaunch"
		{
			print "Engine start.".
			stage.
		}

		set Ship:Control:PilotMainThrottle to 1.

		setFlaps(2).

		if brakes
		{
			print "Waiting for engines to spool.".

			local allEngines is list().
			list engines in allEngines.

			local engineMaxThrust is 0.
			for eng in allEngines
			{
				set engineMaxThrust to engineMaxThrust + eng:PossibleThrust().
			}

			local engineThrust is 0.
			until engineThrust > engineMaxThrust * 0.5
			{
				set engineThrust to 0.
				for eng in allEngines
				{
					set engineThrust to engineThrust + eng:Thrust().
				}
				wait 0.
			}

			brakes off.
		}

		print "Beginning takeoff roll.".

		when alt:radar >= 50 then { gear off. lights off. setFlaps(1). }
	}
 
    // throttle update rate
    wait 0.
}

ClearGuis().

set Ship:Control:Neutralize to true.
