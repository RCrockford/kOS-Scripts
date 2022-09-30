// Ground launch controller.

@clobberbuiltins on.
@lazyglobal off.

parameter engineStart.
parameter targetOrbitDlg.
parameter launchButton is 0.
parameter totalControlled is 0.

local targetOrbit is targetOrbitDlg().
local errorColour is "#f00000".

local function GetLaunchAngleRendezvous
{
	// From KER / MJ2
	local bodyAngVel is Ship:Body:AngularVel:Normalized.
	local lanVec is (SolarPrimeVector * AngleAxis(TargetOrbit:LAN, bodyAngVel)):Normalized.
	local orbitNormal is bodyAngVel * AngleAxis(-TargetOrbit:Inclination, lanVec).
	
	local inc is abs(vang(orbitNormal, bodyAngVel)).
	local bVec is vxcl(bodyAngVel, orbitNormal):Normalized.
	set bVec to bVec * Ship:Body:Radius * sin(Ship:Latitude) / tan(inc).
	
	local cVec is vcrs(orbitNormal, bodyAngVel):Normalized.
	local cMagSq is (Ship:Body:Radius * cos(Ship:Latitude)) ^ 2 - bVec:SqrMagnitude.
	set cMagSq to choose 0 if cMagSq <= 0 else sqrt(cMagSq).
	set cVec to cVec * cMagSq.
	
	local aVec1 is bVec + cVec.
	local aVec2 is bVec - cVec.
	
	local longVec is (LatLng(0,Ship:Longitude):Position - Ship:Body:Position):Normalized.
	
	local angle1 is abs(vang(longVec, aVec1)).
	if vdot(vcrs(longVec, aVec1), bodyAngVel) < 0
		set angle1 to 360 - angle1.
		
	local angle2 is abs(vang(longVec, aVec2)).
	if vdot(vcrs(longVec, aVec2), bodyAngVel) < 0
		set angle2 to 360 - angle2.

	return min(angle1, angle2).
}

local function GetLaunchAngleTerminator
{
	local sunVec is (Sun:Position - Body:Position):Normalized.
    local sunTangVec is vxcl(Up:Vector, sunVec):Normalized.

	local sunUp is vdot(sunVec, Up:Vector).
    local sunEast is vdot(North:StarVector, sunTangVec).
    
    // Launch when the sun is 90° to the up vector.
	local launchAngle is arccos(abs(vdot(sunVec, sunTangVec))).
    
    // If sun is up and east, or down and west then we're just past the launch window
    if (sunUp > 0) = (sunEast > 0)
        set launchAngle to 180 - launchAngle.
        
    return launchAngle.
}

local liftoffTime is -1.
// Initialise launch parameters
local launchDelay is max(10, engineStart + 2).

local launchStage is Stage:Number.
local mainEngines is LAS_GetStageEngines(launchStage).
until not mainEngines:Empty
{
    set launchStage to launchStage - 1.
    set mainEngines to LAS_GetStageEngines(launchStage).
}

local mainEnginesLF is list().  // Liquid fuelled for pre-start.

LAS_PrintEngineReliability(launchStage).

local startStagger is 0.1.
local autoStartTime is 0.
local engineMaxThrust is 0.

for eng in mainEngines
    set engineMaxThrust to engineMaxThrust + eng:PossibleThrust().

local engDisplayList is lexicon().

for eng in mainEngines
{
    local engType is "Liquid Fuel, pumped.".

    if not eng:AllowShutdown
    {
        set engType to "Solid Fuel.".
    }
    else if eng:Possiblethrust() < engineMaxThrust * 0.01
    {
        set engType to "Vernier".
    }
    else 
    {
        if eng:PressureFed
            set engType to "Liquid Fuel, pressure fed.".
        if not eng:Name:Contains("Aerobee")
            set autoStartTime to max(autoStartTime, LAS_CalcFullSpoolTime(eng) * 1.4 + 1).
    }

    if engDisplayList:HasKey(eng:Config)
        set engDisplayList[eng:Config]:Count to engDisplayList[eng:Config]:Count + 1.
    else
        engDisplayList:Add(eng:Config, lexicon("count", 1, "type", engType)).
    if eng:AllowShutdown and engType <> "Vernier"
        mainEnginesLF:add(eng).
}

print "Main Engines:".
for k in engDisplayList:keys
{
    print "  " + engDisplayList[k]:Count + "x " + k + ", " + engDisplayList[k]:Type.
}

if engineStart < 0
{
    set engineStart to autoStartTime + startStagger * max(mainEnginesLF:length - 1, 0).
}

set startStagger to min(startStagger, engineStart * 0.1).

print "Ground Launch Controller ready.".
print "  Engine start at T-" + round(engineStart, 1) + ".".

local launchMass is Ship:Mass.
local launchMassFlow is 0.001.
local padFuelling is engineStart <= 0.5 or mainEnginesLF:empty().   // If not pre-spooling engines, then don't worry about pad fuel pumps
local ascentTime is 0.
local LaunchAngleFunc is 0.

// Ship description dump
{
    //local logPath is "0:/logs/shipstaging.txt".

    //log Ship:Name to logPath.
    //log "    mass=" + round(Ship:Mass * 1000, 1) + ", drymass=" + round(Ship:DryMass * 1000, 1) + ", wetmass=" + round(Ship:Mass * 1000, 1) to logPath.

    local stageWetMass is list().
    local stageDryMass is list().

    from {local s is 0.} until s > launchStage step {set s to s+1.} do
    {
        stageWetMass:Add(0).
        stageDryMass:Add(0).
    }

    for shipPart in Ship:Parts
    {
        // Ignore launch clamps
        if not shipPart:HasModule("LaunchClamp")
        {
            local partStage is shipPart:DecoupledIn + 1.

            // Unstaged parts go into the top stage mass.
            set partStage to max(partStage, 0).
            set partStage to min(partStage, launchStage).

            set stageWetMass[partStage] to stageWetMass[partStage] + shipPart:Mass.
            set stageDryMass[partStage] to stageDryMass[partStage] + shipPart:DryMass.
        }
        else
        {
            if shipPart:HasModule("RefuelingPump")
                set padFuelling to true.
            if shipPart:Stage < launchStage
            {
                print "Clamp " + shippart:title + " is incorrectly staged.".
                LGUI_SetInfo("Clamp " + shippart:title + " is incorrectly staged", errorColour).
                if launchButton:IsType("Button")
                    set launchButton:Enabled to false.
            }
        }
    }

    from {local s is 1.} until s > launchStage step {set s to s+1.} do
    {
        set stageWetMass[s] to stageWetMass[s] + stageWetMass[s - 1].
        set stageDryMass[s] to stageDryMass[s] + stageWetMass[s - 1].
    }

	set launchMass to stageWetMass[launchStage].
	local stageTime is 1.

    from {local s is launchStage.} until s < 0 step {set s to s-1.} do
    {
        local massFlow is 0.
        local vacThrust is 0.
        local slThrust is 0.

        local stageEngines is LAS_GetStageEngines(s).
        for eng in stageEngines
        {
            set massFlow to massFlow + eng:MaxMassFlow.
            set vacThrust to vacThrust + eng:PossibleThrustAt(0).
            set slThrust to slThrust + eng:PossibleThrustAt(1).
        }
        if s = launchStage
        {
            set launchMassFlow to massFlow.
            set launchMass to launchMass - massFlow.    // Allow for 1s of burning without control.
        }
		
		if stageTime > 0 and (defined LAS_TargetSMA or LAS_TargetAp > 100)
		{
			set stageTime to LAS_GuidanceBurnTime(s).
			set ascentTime to ascentTime + stageTime.
		}

        //log "  Stage " + s + ", drymass=" + round(stageDryMass[s] * 1000, 1) + ", wetmass=" + round(stageWetMass[s] * 1000, 1) +
        //    ", ThrustVac=" + round(vacThrust, 1) + ", IspVac=" + round(vacThrust / massFlow, 1) + ", IspSL=" + round(slThrust / massFlow, 1) to logPath.
    }
}

local allRCS is list().
list rcs in allRCS.
for r in allRCS
{
    if not r:IsType("Engine")
    {
        set r:Enabled to false.
    }
}

if totalControlled > 0 and totalControlled < launchMass
{
    print "Insufficient avionics for liftoff control".
    print "  (Ctrl=" + round(totalControlled, 2) + "T, M=" + round(launchMass,2) + "T t=" + round((launchMass - totalControlled) / launchMassFlow + 1, 1) + "s).".
    LGUI_SetInfo("Insufficient avionics for liftoff control", errorColour).
    if launchButton:IsType("Button")
        set launchButton:Enabled to false.
}

// Check for sufficient thrust
{
    local engineMaxThrust is 0.
    for eng in mainEngines
    {
        set engineMaxThrust to engineMaxThrust + eng:PossibleThrust().
    }
	
	print "Liftoff thrust: " + round(engineMaxThrust, (choose 1 if engineMaxThrust < 1000 else 0)) + " kN.".

    local twr is engineMaxThrust / (launchMass * Ship:Body:Mu / LAS_ShipPos():SqrMagnitude).
    if twr < 1.1
    {
        print "Insufficient thrust for liftoff (TWR=" + round(twr, 2) + ", W=" + round((launchMass * Ship:Body:Mu / LAS_ShipPos():SqrMagnitude), 1) + "kN).".
        LGUI_SetInfo("Insufficient thrust for liftoff", errorColour).
        if launchButton:IsType("Button")
            set launchButton:Enabled to false.
    }
}

if not padFuelling
    print "  No launch pad fuel feed, launching on full thrust.".

local cmd is " ".

if defined LAS_LaunchTime
{
	set cmd to "l".
	print "Go for Launch!".

	local waitTime is LAS_LaunchTime - Time:Seconds.

	until waitTime <= launchDelay
	{
		print "T-" + round(waitTime, 0).
		set waitTime to waitTime - floor(waitTime / 5) * 5.
		wait waitTime.

		set waitTime to LAS_LaunchTime - Time:Seconds.
	}

    set launchDelay to round(max(launchDelay, waitTime), 0).
	set targetOrbit to 0.
}
else
{
	print "Ascent Time: " + round(ascentTime, 1) + " s".
    set ascentTime to ascentTime * 0.9.
	local waitTime is 0.
	
	if TargetOrbit = Sun
		set LaunchAngleFunc to GetLaunchAngleTerminator@.
	else if TargetOrbit:IsType("Orbit")
		set LaunchAngleFunc to GetLaunchAngleRendezvous@.

	if LaunchAngleFunc:IsType("UserDelegate")
	{
		set waitTime to LaunchAngleFunc() * Ship:Body:RotationPeriod / 360 - ascentTime.
		print "Launch window opening in approximately " + LAS_FormatTime(waitTime).
	}

    local prevLunarUpdate is Time:Seconds.
    local prevLunarWarp is 1.
    if defined LAS_CalcLunarLaunch@
        print "Lunar window updates enabled".

	print "Awaiting Launch command:".
    
	// Wait for command
	until cmd = "l" or cmd = "n"
	{
		wait 0.
		if launchButton:IsType("Button") and launchButton:TakePress
			set cmd to "l".
		else if Terminal:Input:HasChar
			set cmd to Terminal:Input:GetChar().
            
        local newOrbit is targetOrbitDlg().
        if targetOrbit <> newOrbit
        {
            set targetOrbit to newOrbit.
            set LaunchAngleFunc to GetLaunchAngleRendezvous@.
            set waitTime to LaunchAngleFunc() * Ship:Body:RotationPeriod / 360 - ascentTime.
            print "New target, launch window opening in approximately " + LAS_FormatTime(waitTime).
        }
        
        if defined LAS_CalcLunarLaunch@
        {
            if Time:Seconds - prevLunarUpdate > 60 or (kUniverse:TimeWarp:Rate = 1 and prevLunarWarp > 1) or cmd = "u"
            {
                local prevLunarInc is LAS_TargetInc.
                LAS_CalcLunarLaunch().
                set LGUI_GetControl("Launch South"):Pressed to LAS_TargetInc < 0.
                local incCtrl is LGUI_GetControl("inclination").
                set incCtrl:Text to round(max(Ship:Latitude, min(abs(LAS_TargetInc), 180 - Ship:Latitude)), 2):ToString.
                incCtrl:OnConfirm(incCtrl:Text).
                set prevLunarUpdate to Time:Seconds.
                set cmd to " ".
                if abs(Ship:Latitude - abs(prevLunarInc)) > 0.04 and abs(Ship:Latitude - abs(LAS_TargetInc)) <= 0.04
                    kUniverse:Timewarp:CancelWarp().
            }
            set prevLunarWarp to kUniverse:TimeWarp:Rate.
        }

		if cmd = "a"
		{
			print "Aborting Launch.".
			ClearGUIs().
			break.    // User aborted launch sequence.
		}
		if cmd = "r"
		{
			ClearGUIs().
			reboot.     // Direct reboot to allow for easy staging corrections.
		}
        if cmd = "p"
        {
            if TargetOrbit:IsType("Orbit")
                print "Target Orbit: sma=" + round(TargetOrbit:SemiMajorAxis / 1000, 1) + " inc=" + round(TargetOrbit:Inclination, 2) + " lan=" + round(TargetOrbit:LAN, 2).
            else
                print "No target orbit".
            set cmd to " ".
        }
		if (cmd = "n" or cmd = "c") and TargetOrbit:IsType("Orbit")
		{
			// Go 5 degrees past.
            if cmd = "n"
                set waitTime to waitTime + 5 * Ship:Body:RotationPeriod / 360.
			
			local waitGui is GUI(220).
			local mainBox is waitGui:AddVBox().

			local guiHeading is mainBox:AddLabel("Awaiting next launch window").

			local guiTime is mainBox:AddLabel("T-" + Time(waitTime):Clock).
			waitGui:Show().

			// Wait until we're within 60 seconds.
			until waitTime <= 60
			{
				local t is 1.
				if waitTime >= 3600
				{
					set t to mod(waitTime, 1800).
					if t < 10
						set t to t + 1800.
				}
				else if waitTime >= 120
				{
					set t to mod(waitTime, 60).
					if t < 1
						set t to t + 60.
				}

                if cmd = "n"
                    set kUniverse:TimeWarp:Rate to choose 10000 if t > 100 else 1000.
                else
                    set kUniverse:TimeWarp:Warp to round(min(log10(max(1, waitTime - 15)), 4), 0).

				wait t.

				if t > 0
				{
					set waitTime to waitTime - t.
					set guiTime:Text to "T-" + Time(waitTime):Clock.
				}
                
                if cmd = "c"
                    set waitTime to LaunchAngleFunc() * Ship:Body:RotationPeriod / 360 - (ascentTime + 120).
			}
			kUniverse:Timewarp:CancelWarp().
			ClearGUIs().
			reboot.
		}
	}

	if cmd = "l"
	{
		if launchButton:IsType("Button")
		{
			set launchButton:Pressed to true.
			set launchButton:Enabled to false.
		}
		print "Go for Launch!".
	}
}

if cmd = "l"
{

if LaunchAngleFunc:IsType("UserDelegate")
{
    local waitGui is GUI(200).
    local mainBox is waitGui:AddVBox().

    local guiHeading is mainBox:AddLabel("Awaiting launch window").

    // Launch window planning, simply matches ascending nodes.
	local waitTime is LaunchAngleFunc() * Ship:Body:RotationPeriod / 360 - ascentTime.

    local guiTime is mainBox:AddLabel("T-" + Time(waitTime):Clock).
    waitGui:Show().

    // Wait until we're within launch time
    until waitTime <= launchDelay
    {
        local t is 1.
        if waitTime > 3600
        {
            set t to mod(waitTime, 1800).
            if t < 10
                set t to t + 1800.
        }
        else if waitTime > 120
        {
            set t to mod(waitTime, 60).
            if t < 1
                set t to t + 60.
        }

		set kUniverse:TimeWarp:Warp to round(min(log10(max(1, waitTime - 15)), 3), 0).

        wait t.

        if t > 0
        {
            set waitTime to waitTime - t.
            set guiTime:Text to "T-" + Time(waitTime):Clock.
        }

        set waitTime to LaunchAngleFunc() * Ship:Body:RotationPeriod / 360 - ascentTime.
    }
    kUniverse:Timewarp:CancelWarp().

    waitGui:Hide().

    set launchDelay to round(max(launchDelay, waitTime), 0).
}

local countdown is launchDelay.
set liftoffTime to Time:Seconds + launchDelay.

local function TMinusString
{
    local tMinus is liftoffTime - Time:Seconds.
    local str is (choose "T-" if tMinus > 0 else "T+") + round(abs(tMinus), 1).
    if not str:Contains(".")
        return str + ".0".
    return str.
}

local function GLCAbort
{
    local parameter reason.

    local allEngines is list().
    list engines in allEngines.

    // Shutdown all engines
    for eng in allEngines
    {
        eng:Shutdown().
    }

    print TMinusString + " " + reason.
    print TMinusString + " Aborting launch.".

    if Ship:Status = "Flying"
    {
		HudText("RSO: Commanded ship destruction.", 5, 2, 15, red, false).

		// Tell all other CPUs to destroy themselves.
		for cpu in Ship:ModulesNamed("kOSProcessor")
		{
			if cpu <> Core
				cpu:Connection:SendMessage("RSO").
		}.

        LAS_CrewEscape().

        if Ship:Crew:Empty
            Core:Part:GetModule("ModuleRangeSafety"):DoAction("Range Safety", true).
    }

    // Release control
    set Ship:Control:Neutralize to true.

    Shutdown.
}

local infoText is "Countdown started".

// Setup countdown trigger
on ceiling(liftoffTime - Time:Seconds)
{
    set countdown to ceiling(liftoffTime - Time:Seconds).
    print countdown.
    LGUI_SetInfo("T-" + countdown + " " + infoText, "#" + min(countdown, 9) + "fff00").
    return countdown > 0.
}

when Terminal:Input:HasChar() then
{
    if Terminal:Input:GetChar() = "a" and countdown > 0
        GLCAbort("Received abort command").
}

// Start launch
print "Auto launch sequence started.".
print "Liftoff in T-" + countdown + ".".

if kUniverse:TimeWarp:Mode = "Rails"
	kUniverse:TimeWarp:CancelWarp().

local armModules is Ship:ModulesNamed("ModuleAnimateGeneric").
for arm in Ship:ModulesNamed("ModuleAnimateGenericExtra")
    armModules:add(arm).

for arm in armModules
{
    if arm:HasAction("Toggle hatch access")
    {
        arm:DoAction("Toggle hatch access", false).
        set infoText to "Retract hatch gantry".
    }
    else if arm:HasAction("Toggle crew arm")
    {
        arm:DoAction("Toggle crew arm", false).
        set infoText to "Retract hatch gantry".
    }
    else if arm:HasField("horizontal adjust") and arm:HasAction("toggle")
    {
        arm:DoAction("toggle", false).
        set infoText to "Retract hatch gantry".
    }
}

local armRetractTime is max(8, engineStart + 0.5).
wait until liftoffTime - Time:Seconds <= armRetractTime.

local armParts is uniqueset().

for arm in armModules
{
    if arm:HasEvent("Retract Crew Arm")
    {
        arm:DoEvent("Retract Crew Arm").
        set infoText to "Latch back crew arm".
    }
    else if arm:HasAction("Toggle crew arm") and arm:HasEvent("Retract arm")
    {
        arm:DoEvent("Retract arm").
        set infoText to "Latch back crew arm".
    }
    armParts:Add(arm:part).
}

// Engine start sequence for liquid fuels
if engineStart > 0.5 and not mainEnginesLF:empty()
{
    wait until liftoffTime - Time:Seconds <= engineStart.

    // Stage swing arms etc.
    if stage:number > launchStage + 1 and stage:ready
        stage.

	kUniverse:TimeWarp:CancelWarp().
    print TMinusString + " Ignition sequence start.".
    set infoText to "Ignition sequence start".

    // Throttle up to maximum
    set Ship:Control:PilotMainThrottle to 1.

    // Ignite all engines
    for eng in mainEnginesLF
    {
        LAS_IgniteEngine(eng).

        // Staggered start for multiple engines.
        wait startStagger.
    }

    local engCount is 1.
    for eng in mainEnginesLF
    {
        if not eng:Ignition()
        {
            GLCAbort(eng:Config + " #" + engCount + " failed to ignite.").
        }
        set engCount to engCount + 1.
    }

    // Wait for full thrust
    local engineMaxThrust is 0.
    for eng in mainEnginesLF
    {
        set engineMaxThrust to engineMaxThrust + eng:PossibleThrust().
    }

    local engineThrust is 0.
    until Time:Seconds - liftoffTime >= -0.2
    {
        set engineThrust to 0.
        for eng in mainEnginesLF
        {
            set engineThrust to engineThrust + eng:Thrust().
        }

        if engineThrust >= engineMaxThrust * 0.998
        {
            break.
        }

        wait 0.1.
    }

    print TMinusString + " Main engines report " + round(100 * engineThrust / max(engineMaxThrust, 0.01), 1) + "% thrust".
    set infoText to "Main engines nominal".

    if engineThrust < engineMaxThrust * 0.98
    {
        GLCAbort("Main engines failed to reach commanded thrust.").
    }

    for eng in mainEnginesLF
    {
        if eng:Name = "ROE-RD108"
        {
            // Reduce roll torque calculation
            set SteeringManager:RollTorqueFactor to 12.
            break.
        }
    }
}

// Wait for countdown
wait until countdown = 0 or not padFuelling.

// Check for main engine issues just before liftoff.
local engCount is 1.
for eng in mainEnginesLF
{
	if engineStart > 0.5 and eng:Thrust < eng:PossibleThrust * 0.98
		GLCAbort(eng:Config + " #" + engCount + " reported reduced thrust.").
	set engCount to engCount + 1.
}

local liftoffHeading is Ship:Facing.
lock Steering to liftoffHeading.

// Stage any boosters and launch clamps
if mainEngines:length() > mainEnginesLF:length()
{
    print TMinusString + " Booster Ignition".
    LGUI_SetInfo("T+0 Booster ignition", "#00ff00").
}
else
{
    LGUI_SetInfo("T+0 Liftoff!", "#00ff00").
}

set Ship:Control:PilotMainThrottle to 1.
stage.

wait 0.1.

until Ship:VerticalSpeed >= 2 and Ship:Status = "Flying"
{
    // Check for vertical movement
    if Ship:VerticalSpeed < -1
    {
        GLCAbort("Failed to achieve liftoff.").
    }
    wait 0.
}

print TMinusString + " Liftoff!".
}
// End of GLC, handoff to flight.