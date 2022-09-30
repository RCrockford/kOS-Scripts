@lazyglobal off.

wait until Ship:Unpacked.

parameter targetRoll is 1.

runpath("0:/flight/tunesteering").

unlock steering.
set Ship:Control:Neutralize to true.
rcs off.

local debugGui is GUI(300, 80).
set debugGui:X to 100.
set debugGui:Y to debugGui:Y + 300.
local mainBox is debugGui:AddVBox().
local debugStat1 is mainBox:AddLabel("Acceleration: ").
local debugStat2 is mainBox:AddLabel("Command Roll: ").
debugGui:Show().

print "Waiting for atmospheric interface".

wait until Ship:Altitude < Ship:Body:Atm:Height.

local chutesArmed is false.
for rc in Ship:ModulesNamed("RealChuteModule")
{
    if rc:HasEvent("arm parachute")
    {
        rc:DoEvent("arm parachute").
        set chutesArmed to true.
    }
    else if rc:HasEvent("deploy chute")
    {
        rc:DoEvent("deploy chute").
        set chutesArmed to true.
    }
}

if not chutesArmed
	chutes on.

print "Chutes armed.".

until Ship:Q > 1e-5
{
    set debugStat1:Text to "Waiting for Q > 1: " + round(Ship:Q * Constant:AtmTokPa * 1000, 1) + " Pa".
}

for a in Ship:ModulesNamed("ModuleProceduralAvionics")
{
	if a:HasEvent("activate avionics")
		a:DoEvent("activate avionics").
}

rcs on.
local initVec is choose Ship:Up:Vector if targetRoll > 0 else -Ship:Up:Vector.
local upVec is initVec.
lock steering to LookDirUp(SrfRetrograde:Vector, upVec).

local currentRoll is 0.
local rollPID is PIDLoop(6, 0.5, 6, 0, 180).
local currentSpeed is Ship:Velocity:Surface:Mag.
local currentTime is Time:Seconds.

set steeringmanager:RollControlAngleRange to 10.
set rollPID:SetPoint to 70.

local startTime is 0.

until Ship:Velocity:Surface:Mag < 1000
{
	wait 0.05.

	local accel is (Ship:Velocity:Surface:Mag - currentSpeed) / (Time:Seconds - currentTime).
	set currentSpeed to Ship:Velocity:Surface:Mag.
	set currentTime to Time:Seconds.
	
	set debugStat1:Text to "Acceleration: " + round(accel, 2) + " m/s²".
	set debugStat2:Text to "Command Roll: " + round(currentRoll, 2) + "°".
	
	if accel < -5 and steeringmanager:RollControlAngleRange < 180
    {
        // set minimum controls to "disable" steering manager yaw/pitch.
        set ship:control:yaw to 0.000011.
        set ship:control:pitch to 0.000011.
        set steeringmanager:RollControlAngleRange to 180.
        if Core:Part:HasModule("AdjustableComShifter")
        {
            local comModule is Core:Part:GetModule("AdjustableComShifter").
            print "Activating descent mode".
            if comModule:HasEvent("Turn Descent Mode On")
                comModule:DoEvent("Turn Descent Mode On").
        }
        set startTime to Time:Seconds.
    }
    
    set currentRoll to rollPID:Update(Time:Seconds, -accel - Ship:VerticalSpeed / 12).
    set upVec to initVec * angleaxis(CurrentRoll, SrfRetrograde:Vector).
}

if steeringmanager:RollControlAngleRange > 179 and Core:Part:HasModule("AdjustableComShifter")
{
    local comModule is Core:Part:GetModule("AdjustableComShifter").
    if comModule:HasEvent("Turn Descent Mode Off")
        comModule:DoEvent("Turn Descent Mode Off").
}

lock steering to "kill".
        
set core:bootfilename to "".

set kUniverse:TimeWarp:Mode to "Physics".
set kUniverse:TimeWarp:Rate to 1.

local droppedHS is false.

until Ship:Altitude - max(Ship:GeoPosition:TerrainHeight, 0) < 10
{
    local radarAlt is Ship:Altitude - max(Ship:GeoPosition:TerrainHeight, 0).
	set debugStat1:Text to "Landing ETA: " + round(radarAlt / Ship:Velocity:Surface:Mag, 1) + " s".
    if Ship:Velocity:Surface:Mag < 500
        set kUniverse:TimeWarp:Rate to min(max(1, round(radarAlt / 50)), 4).
        
    if Velocity:Surface:Mag < 80
    {
        set ship:control:yaw to 0.
        set ship:control:pitch to 0.
    }
        
    if Ship:Velocity:Surface:Mag < 50 and not droppedHS
    {
        for hs in Ship:ModulesNamed("ModuleDecouple")
        {
            if hs:HasEvent("jettison heat shield")
            {
                hs:DoEvent("jettison heat shield").
            }
        }
        set droppedHS to true.
    }
    
    wait 0.1.
}

clearGUIs().
