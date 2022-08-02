// Launch window planning for polar direct ascent

@clobberbuiltins on.
@lazyglobal off.

// Wait for unpack
wait until Ship:Unpacked.

// Launch to the south?
local southerlyLaunch is Ship:Latitude > 0.

set config:ipu to 2000.

local isGroundStation is (Ship:Mass < 1) and (Ship:Status = "Landed").

local plannerSlots is choose 16 if isGroundStation else 8.

ClearGUIs().

local function GetPeriapsisLat
{
	parameter targetPe.
	parameter targetSMA.
	parameter aerovTheta.

	local ecc is 1 - targetPe / targetSMA.
	local L is targetSMA * (1 - ecc * ecc).
    local hT is sqrt(Ship:Body:Mu * L).

	local aeroLat is 1.5.	// assume ~1.5 degrees during first stage burn
	local guidanceLat is 0.

	local aeroAlt is 90000.

	local r is aeroAlt + Ship:Body:Radius.
	local rT is targetPe.
	local rv is 1000.
	local rvT is 0.
    local h is aerovTheta * r.
	local meanRadius is (r + rT) * 0.5.

	local firstEngineStage is -1.
	from {local s is Stage:Number - 1.} until s < 0 step {set s to s - 1.} do
	{
		local stagePerf is LAS_GetStagePerformance(s, true).

		if stagePerf:eV <= 0
            break.

        // First stage is aero stage.
        if firstEngineStage < 0 or (stagePerf:litPrevStage and firstEngineStage = s+1)
        {
            set firstEngineStage to s.
        }
        else
        {
            // Anomaly delta for stage, assuming full burn.
            local tau is stagePerf:eV / stagePerf:accel.
            local b0 is -stagePerf:eV * ln(1 - stagePerf:BurnTime / tau).
            local b1 is b0 * tau - stagePerf:eV * stagePerf:BurnTime.
            local c0 is b0 * stagePerf:BurnTime - b1.
            local c1 is c0 * tau - stagePerf:eV * stagePerf:BurnTime^2 * 0.5.
            local c2 is c1 * tau - stagePerf:eV * stagePerf:BurnTime^3 / 6.
            local d3 is h * rv / r^3.
            local d4 is (hT * rvT / rT^3 - d3) / stagePerf:BurnTime.

            local ftheta is 0.98.	// Estimate 2% cosine losses
            local fdtheta is 0.
            local fddtheta is 0.

            local dA is stagePerf:BurnTime * h / r^2
                + (ftheta * c0 + fdtheta * c1 + fddtheta * c2) / meanRadius
                - d3 * stagePerf:BurnTime^2 - d4 * stagePerf:BurnTime^3 / 3.

            set guidanceLat to guidanceLat + dA.
        }
	}

	set guidanceLat to guidanceLat * Constant:RadToDeg.

	return guidanceLat - aeroLat.
}

local function CalcRequiredSemiMajorAxis
{
	parameter targetPe.
	parameter MoonPos.
	parameter periapsisLat.

	local angle is periapsisLat + 90 - arccos(MoonPos:Normalized:y).
	local cosa is cos(angle).

	local denom is 4 * MoonPos:Mag * (1 - cosa) - 8 * targetPe.
	if denom < 0
		set denom to min(denom, -0.001).
	else
		set denom to max(denom, 0.001).
	local newA is -4 * targetPe * (MoonPos:Mag * cosa + targetPe) / denom.

	//print "  New SMA: " + round(newA * 0.001, 1) + " km for angle " + round(angle, 1).

	return newA.
}

local function CalcFlightTime
{
	parameter targetPe.
	parameter targetSMA.
	parameter MoonPos.
	parameter periapsisLat.

	local ecc is 1 - targetPe / targetSMA.

	local angle is periapsisLat + 90 - arccos(MoonPos:Normalized:y).
	local trueAnomaly is 180 - angle.
	if southerlyLaunch
		set trueAnomaly to 180 + angle.

	//print "  r from true anom = " + round(0.001 * targetSMA * (1 - ecc^2) / (1 + ecc * cos(trueAnomaly)), 1) + " / " + round(MoonPos:Mag * 0.001, 1).

	local eccAnom is 0.
	local meanAnom is 0.

	if ecc < 1 and ecc >= 0
	{
		// Elliptic orbit
		set eccAnom to mod(arctan2(sqrt(1 - ecc^2) * sin(trueAnomaly), ecc + cos(trueAnomaly)) + 360, 360).
		set meanAnom to (eccAnom * constant:degtorad - ecc * sin(eccAnom)) * constant:radtodeg.
	}
	else if trueAnomaly >= 180 or ecc < 0
	{
		// Cannot reach via hyperbolic trajectory
		return 0.
	}
	else
	{
		// Hyperbolic trajectory
		local coshe is (cos(trueAnomaly) + ecc) / (1 + ecc * cos(trueanomaly)).
		// kOS doesn't have arccosh(x), so use the identity ln(x+sqrt(x^2-1))
		set eccAnom to ln(coshe + sqrt(coshe^2 - 1)).
		// kOS doesn't have sinh(x) so use the identity (e^x - e^-x) / 2
		set meanAnom to ecc * (constant:e^eccAnom - constant:e^(-eccAnom)) / 2 - eccAnom.
		// Convert above results back to degrees
		set eccAnom to eccAnom * constant:radtodeg.
		set meanAnom to meanAnom * constant:radtodeg.
	}

	local t is meanAnom * constant:pi * sqrt(abs(targetSMA)^3 / Ship:Body:Mu) / 180.
	//print "  e=" + round(ecc, 3) + " v=" + round(trueAnomaly, 1) + " E=" + round(eccAnom, 1) + " M=" + round(meanAnom, 1) + " t=" + round(t / 3600, 1) + " hours".

	return t.
}

local function GetMoonLongAtTime
{
	parameter launchTime.

	local currentMeridianVector is (ship:body:geopositionlatlng(0,0):position - ship:body:position):Normalized.
	local rotAngle is -(launchTime - Time:seconds) * 360 / Ship:Body:RotationPeriod.

	local meridianVector is V(0,0,0).
	set meridianVector:X to currentMeridianVector:X * cos(rotAngle) + currentMeridianVector:Z * sin(rotAngle).
	set meridianVector:Z to -currentMeridianVector:X * sin(rotAngle) + currentMeridianVector:Z * cos(rotAngle).

	local MoonVec is positionat(Moon, launchTime) - Ship:Body:Position.
	set MoonVec:Y to 0.

	// Longitude is angle between meridian vector and position.
	local long is arccos(vdot(MoonVec:Normalized, meridianVector)).

	// Check for east or west
	if vcrs(MoonVec:Normalized, meridianVector):Y < 0
		set long to -long.

	return long.
}

local function CalcLaunchTime
{
	parameter earliestLaunch.
	parameter flightTime.
	parameter leadAngle.

    local launchTime is earliestLaunch.
	local longDiff is 400.
	
	until abs(longDiff) < 0.1
	{
		if longDiff < 400
		{
			local deltaT is longDiff * Ship:Body:RotationPeriod / 360.
			set launchTime to launchTime + deltaT - (360 * deltaT / Moon:Orbit:Period) * Ship:Body:RotationPeriod / 360.
		
			if launchTime < earliestLaunch
				set launchTime to launchTime + Ship:Body:RotationPeriod.
		}
		
		local MoonArrivalVec is positionat(Moon, launchTime + flightTime) - Ship:Body:Position.
		set MoonArrivalVec:Y to 0.
		local MoonLaunchVec is positionat(Moon, launchTime) - Ship:Body:Position.
		set MoonLaunchVec:Y to 0.
		
		local orbitAngle is arccos(vdot(MoonLaunchVec:Normalized, MoonArrivalVec:Normalized)).
		local targetLong is Ship:Longitude + 180 - orbitAngle + leadAngle.
		
		set longDiff to mod(GetMoonLongAtTime(launchTime) - targetLong + 720, 360).

		//print "  T=" + LAS_FormatTime(launchTime - Time:Seconds) + " longdiff=" + round(longdiff, 1) + " orbAng=" + round(orbitAngle, 2).
	}

	return launchTime.
}

local deltaVBudget is 0.
local goTime is -1.
local setKACAlarm is 0.

local function UpdateGuiEntry
{
	parameter guiEntry.
	parameter guiData.

	if guiData:launch = 0
		return.

	local color is "white".
	if not guiData:valid
		set color to "grey".

	set guiEntry:launch:text to "<color=" + color + ">" + LAS_FormatTimeStamp(guiData:launch - Time:Seconds) + "</color>".
	set guiEntry:flight:text to "<color=" + color + ">" + LAS_FormatTime(guiData:flight) + "</color>".
	set guiEntry:arrival:text to "<color=" + color + ">" + LAS_FormatTimeStamp(guiData:arrival - Time:Seconds) + "</color>".

	set color to "#00ff00".
	if guiData:deltaV > deltaVBudget + 250
		set color to "#f00000".
	else if guiData:deltaV > deltaVBudget
		set color to "#ff8000".
	else if guiData:deltaV > deltaVBudget - 250
		set color to "#ffff00".
	if guiData:valid
		set color to color + "ff".
	else
		set color to color + "7f".
	set guiEntry:deltaV:text to "<color=" + color + ">" + round(guiData:deltaV, 0) + " m/s</color>".

	if abs(goTime - guiData:launch) > 60
	{
		set guiEntry:Go:Pressed to false.
		if guiData:go:IsType("KACAlarm")
		{
			DeleteAlarm(guiData:go:id).
			set guiData:go to 0.
		}
	}
	else if guiEntry:Go:Pressed
	{
		if setKACAlarm:Pressed and not guiData:go:IsType("KACAlarm") and guiData:launch > 1800
		{
			local lwName is (choose "Lunar" if isGroundStation else Ship:Name).
			set guiData:go to AddAlarm("Raw", guiData:launch - 1800, lwName + " Launch Window", lwName + " is nearing its launch window").
		}
	}
}

// Must be prelaunch for system to activate (allows for reboots after liftoff).
if Ship:Status = "PreLaunch" or isGroundStation
{
    Core:DoEvent("Open Terminal").

    switch to 0.

    runoncepath("0:/launch/lasfunctions").

	local planningGui is Gui(300).
	set planningGui:Y to 200.

	local listBox is planningGui:AddHBox().
	local tweaksBox is planningGui:AddHBox().
	local controlBox is planningGui:AddHBox().

	local guiColumns is list(
		lexicon("heading", "Launch Time", "name", "launch", "guiBox", 0),
		lexicon("heading", "Flight Time", "name", "flight", "guiBox", 0),
		lexicon("heading", "Arrival Time", "name", "arrival", "guiBox", 0),
		lexicon("heading", "Delta V", "name", "deltav", "guiBox", 0),
		lexicon("heading", "Go", "name", "go", "guiBox", 0)
	).

	local fieldWidth is 100.
	for col in guiColumns
	{
		set col:guiBox to listBox:AddVBox().
		set col:guiBox:style:width to fieldWidth.
		col:guiBox:AddLabel("<b>" + col:heading + "</b>").
		col:guiBox:AddSpacing(4).
	}

	set guiColumns[guiColumns:Length-1]:guiBox:style:width to 35.

	local guiEntries is list().
	local guiData is list().

	local entryHeight is 22.
	from {local i is 0.} until i >= plannerSlots step {set i to i + 1.} do
	{
		local entry is lexicon().
		local data is lexicon().

		for col in guiColumns
		{
			if col:name = "go"
			{
				local box is col:guiBox:AddCheckBox("").
				entry:add(col:name, box).
				set box:ontoggle to { parameter t. if t set goTime to data:launch. else if abs(goTime - data:launch) < 60 set goTime to 0. }.
			}
			else
			{
				local tf is col:guiBox:AddTextField("").
				set tf:enabled to false.
				entry:add(col:name, tf).
			}

			set entry[col:name]:style:height to entryHeight.

			data:add(col:name, 0).
		}
		data:add("sma", 0).
		data:add("valid", false).

		guiEntries:Add(entry).
		guiData:Add(data).
	}

	local nextUpdate is 0.
	local nextTick is 0.
    
	local targetPe is LAS_TargetPe * 1000 + Ship:Body:Radius.
    local estPeLat is 0.
	if isGroundStation
	{
		if exists("1:/pelat.json")
		{
			local peLat to readjson("1:/pelat.json").
			set estPeLat to abs(Ship:Latitude - peLat[0]).
		}
		else
			set estPeLat to 22.
	}
	else
	{
		set estPeLat to GetPeriapsisLat(LAS_TargetPe * 1000 + Ship:Body:Radius, Moon:Altitude + Ship:Body:Radius + targetPe, 4000).
	}
    if not southerlyLaunch
        set estPeLat to -estPeLat.
    
	set tweaksBox:AddLabel("Pe Lat"):style:height to 25.
	local PeriapsisLat is tweaksBox:AddTextField(LAS_GetPartParam(Core:Part, "pelat=", Ship:Latitude - estPeLat):ToString()).
	set PeriapsisLat:style:width to 50.
	set PeriapsisLat:style:height to 25.

	set tweaksBox:AddLabel("Lead Angle"):style:height to 25.
	local leadAngle is tweaksBox:AddTextField("0").
	set leadAngle:style:width to 50.
	set leadAngle:style:height to 25.
	set leadAngle:OnConfirm to { parameter s. set nextUpdate to 0. }.

	local southLaunch is controlBox:AddCheckBox("Launch South").
	set southLaunch:Pressed to southerlyLaunch.
	set southLaunch:style:height to 25.

	controlBox:AddSpacing(10).
	local autoWarp is controlBox:AddCheckBox("Auto Warp").
	set autoWarp:Pressed to not isGroundStation.
	set autoWarp:style:height to 25.

	controlBox:AddSpacing(10).
	set setKACAlarm to controlBox:AddCheckBox("Set Alarm").
	set setKACAlarm:Pressed to isGroundStation.
	set setKACAlarm:style:height to 25.

	controlBox:AddSpacing(10).
	local debugText is controlBox:AddLabel("").
	set debugText:style:height to 25.

	planningGui:Show().

	if isGroundStation
	{
		set deltaVBudget to 12500.
	}
	else
	{
		local prevStagePerf is 0.

		from {local s is Stage:Number - 1.} until s < 0 step {set s to s - 1.} do
		{
			local stagePerf is LAS_GetStagePerformance(s, true).
			
			if stagePerf:eV <= 0
				break.

			if stagePerf:litPrevStage and prevStagePerf:IsType("lexicon")
			{
				local vacThrust is stagePerf:Accel * stagePerf:WetMass.

				// Model as two separate burns
				local burn1Accel is vacThrust / prevStagePerf:WetMass.
				local burn1dV is -stagePerf:eV * ln(1 - prevStagePerf:BurnTime * burn1Accel / stagePerf:eV).

				local burn2Accel is vacThrust / (stagePerf:WetMass - stagePerf:MassFlow * prevStagePerf:BurnTime).
				local burn2dV is -stagePerf:eV * ln(1 - (stagePerf:BurnTime - prevStagePerf:BurnTime) * burn2Accel / stagePerf:eV).

				set deltaVBudget to deltaVBudget + burn1dV + burn2dV.
			}
			else
			{
				local deltaV is -stagePerf:eV * ln(1 - stagePerf:BurnTime * stagePerf:Accel / stagePerf:eV).
				set deltaVBudget to deltaVBudget + deltaV.
			}

			set prevStagePerf to stagePerf.
		}
	}
	print "DeltaV budget: " + round(deltaVBudget, 1) + "m/s".
    
	local goForLaunch is -1.
	local prevWarpRate is 1.
	
	// Initial ETA 68 hours.
	set guiData[0]:flight to 68 * 3600.

	until goForLaunch >= 0
	{
		local goIndex is -1.

		if prevWarpRate > 1 and kUniverse:TimeWarp:Rate = 1 and (nextUpdate - Time:Seconds) > 15
			set nextUpdate to Time:Seconds.

		set prevWarpRate to kUniverse:TimeWarp:Rate.

		if (nextUpdate <= Time:Seconds or southerlyLaunch <> southLaunch:Pressed) and (nextUpdate = 0 or goTime = 0 or goTime - Time:Seconds > 300)
		{
			from {local i is 0.} until i >= plannerSlots step {set i to i + 1.} do
			{
				set guiData[i]:valid to false.
				UpdateGuiEntry(guiEntries[i], guiData[i]).
				if southerlyLaunch <> southLaunch:Pressed
					set guiData[i]:flight to 0.
			}
			if southerlyLaunch <> southLaunch:Pressed
			{
				set guiData[0]:flight to 68*3600.
				set guiData[0]:launch to 0.
			}

			set southerlyLaunch to southLaunch:Pressed.

			local earliestLaunch is guiData[0]:launch - 1800.
			if earliestLaunch < 0
				set earliestLaunch to Time:Seconds - 300.

			from {local i is 0.} until i >= plannerSlots step {set i to i + 1.} do
			{
				local prevFlightTime is 0.
				local flightTime is guiData[i]:flight.
				if flightTime = 0
					set flightTime to guiData[i-1]:flight.
				
				if (kUniverse:TimeWarp:Rate = 1 and goTime = 0) or abs(goTime - guiData[i]:launch) < 60
				{
					local launchTime is 0.
					local targetSMA is Moon:Altitude + Ship:Body:Radius + targetPe.
					local isGoLaunch is abs(goTime - guiData[i]:launch) < 60.
					local firstPass is true.

					until abs(flightTime - prevFlightTime) < 60
					{
						//print i + " Earliest launch in " + LAS_FormatTime(earliestLaunch - Time:Seconds) + " fT=" + LAS_FormatTime(flightTime).
						set launchTime to CalcLaunchTime(earliestLaunch, flightTime, leadAngle:Text:ToScalar(0)).
                        
                        set debugText:Text to LAS_FormatTime(launchTime - Time:Seconds).

						// Moon pos relative to earth centre
						local MoonPos is PositionAt(Moon, launchTime + flightTime) - Ship:Body:Position.

						local periapsisLatitude is PeriapsisLat:Text:ToScalar(Ship:Latitude - estPeLat).
                        if southerlyLaunch <> (periapsisLatitude < Ship:Latitude)
                        {
                            set periapsisLatitude to 2 * Ship:Latitude - periapsisLatitude.
                            set PeriapsisLat:Text to round(periapsisLatitude, 2):ToString().
                        }

						set targetSMA to CalcRequiredSemiMajorAxis(targetPe, MoonPos, periapsisLatitude).

						set prevFlightTime to flightTime.
						set flightTime to CalcFlightTime(targetPe, targetSMA, MoonPos, periapsisLatitude).
						if flightTime = 0 or flightTime > 8 * 24 * 3600
						{
							// Unreachable, try jumping forward
							//print "Moon not reachable from this launch window".
							set earliestLaunch to launchTime + 3600 * 6.
							if i > 0
								set flightTime to guiData[i-1]:flight.
							else
								set flightTime to 68*3600.
							set prevFlightTime to 0.
							set firstPass to true.
						}
						else
						{
							if not firstPass
								set flightTime to (flightTime + prevFlightTime) * 0.5.
							set firstPass to false.
						}

						if southerlyLaunch <> southLaunch:Pressed
							break.
					}

					set guiData[i]:launch to launchTime.
					set guiData[i]:flight to flightTime.
					set guiData[i]:arrival to launchTime + flightTime.
					set guiData[i]:sma to targetSMA.

					local ecc is 1 - targetPe / targetSMA.
					local L is targetSMA * (1 - ecc * ecc).
					local hT is sqrt(Ship:Body:Mu * L).
					// Approximately 1500 dV for aero losses.
					local deltaV is 1500 + hT / targetPe.
					set guiData[i]:deltaV to 1500 + hT / targetPe.

					set guiData[i]:valid to true.

					if isGoLaunch and abs(goTime - guiData[i]:launch) < 1800
					{
						set goTime to guiData[i]:launch.
						set goIndex to i.
					}

					if guiData[i]:go:IsType("KACAlarm")
					{
						if abs(guiData[i]:go:Remaining - (guiData[i]:launch - 120)) >= 60
						{
							DeleteAlarm(guiData[i]:go:id).
							set guiData[i]:go to 0.
						}
					}
				}

				UpdateGuiEntry(guiEntries[i], guiData[i]).

				set earliestLaunch to guiData[i]:launch + 3600 * 12.

				if southerlyLaunch <> southLaunch:Pressed
					break.
			}

			if southerlyLaunch = southLaunch:Pressed
			{
				if goTime > 0
				{
					if (goTime - Time:Seconds) > 3600
						set nextUpdate to goTime - floor((goTime - Time:Seconds) / 3600) * 3600.
					else
						set nextUpdate to goTime - floor((goTime - Time:Seconds) / 600) * 600.
					if nextUpdate - Time:Seconds < 30
						set nextUpdate to nextUpdate + 600.
				}
				else
				{
					set nextUpdate to Time:Seconds + max(600, kUniverse:TimeWarp:Rate * 4).
				}
			}
		}
		else
		{
			from {local i is 0.} until i >= plannerSlots step {set i to i + 1.} do
			{
				UpdateGuiEntry(guiEntries[i], guiData[i]).
				if abs(goTime - guiData[i]:launch) < 60
					set goIndex to i.
			}
		}

		if goIndex > -1 and guiEntries[goIndex]:go:Pressed
		{
			if autoWarp:pressed
			{
				local warpRate is 1.
				if (goTime - Time:Seconds) > 3600 * 4
					set warpRate to 10000.
				else if (goTime - Time:Seconds) > 60 * 35
					set warpRate to 1000.
				else if (goTime - Time:Seconds) > 90
					set warpRate to 100.
				else if (goTime - Time:Seconds) > 22
					set warpRate to 10.
				if (goTime - Time:Seconds) < 900 and abs(nextUpdate - Time:Seconds) < 16
					set warpRate to 1.
				if kUniverse:TimeWarp:Rate <> warpRate
					set kUniverse:TimeWarp:Rate to warpRate.
			}

			if guiData[goIndex]:launch - Time:Seconds <= 25
			{
				set goForLaunch to goIndex.
			}
		}
		else
		{
			set goTime to 0.
		}
		
		if isGroundStation
		{
			local periapsisLatitude is PeriapsisLat:Text:ToScalar(Ship:Latitude - estPeLat).
			writejson(list(periapsisLatitude), "1:/pelat.json").
		}

		wait until nextTick < Time:Seconds.
		set nextTick to floor(Time:Seconds) + 1.
	}

	kUniverse:Timewarp:CancelWarp().
	
	if goForLaunch >= 0
	{
		local prevFlightTime is 0.
		local flightTime is guiData[goForLaunch]:flight.
		local targetSMA is guiData[goForLaunch]:sma.
		local firstPass is true.
					
		until abs(flightTime - prevFlightTime) < 60
		{
			// Moon pos relative to earth centre
			local MoonPos is PositionAt(Moon, goTime + flightTime) - Ship:Body:Position.
            
            local periapsisLatitude is PeriapsisLat:Text:ToScalar(Ship:Latitude - estPeLat).
            if southerlyLaunch <> (periapsisLatitude < Ship:Latitude)
            {
                set periapsisLatitude to 2 * Ship:Latitude - periapsisLatitude.
                set PeriapsisLat:Text to round(periapsisLatitude, 2):ToString().
            }

			set targetSMA to CalcRequiredSemiMajorAxis(targetPe, MoonPos, periapsisLatitude).

			set prevFlightTime to flightTime.
			set flightTime to CalcFlightTime(targetPe, targetSMA, MoonPos, periapsisLatitude).
			if not firstPass
				set flightTime to (flightTime + prevFlightTime) * 0.5.
			set firstPass to false.
		}
		
		print "  Est periapsis lat is " + PeriapsisLat:Text + ", Lead Angle=" + leadAngle:Text:ToScalar(0).
	
		global LAS_LaunchTime is goTime.
		global LAS_TargetSMA is targetSMA.
		global LAS_TargetInc is 90.
		if southerlyLaunch
			set LAS_TargetInc to -90.
	}
	
	ClearGUIs().
}