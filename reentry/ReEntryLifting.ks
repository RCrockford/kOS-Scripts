@lazyglobal off.

wait until Ship:Unpacked.

parameter targetRoll is 1.

runpath("0:/flight/tunesteering").

unlock steering.
set Ship:Control:Neutralize to true.
rcs off.

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

wait until Ship:Q > 1e-5.

for a in Ship:ModulesNamed("ModuleProceduralAvionics")
{
	if a:HasEvent("activate avionics")
		a:DoEvent("activate avionics").
}

rcs on.
local initVec is choose Ship:Up:Vector if targetRoll > 0 else -Ship:Up:Vector.
local upVec is initVec.
lock steering to LookDirUp(SrfRetrograde:Vector, upVec).

local debugGui is GUI(300, 80).
set debugGui:X to 100.
set debugGui:Y to debugGui:Y + 300.
local mainBox is debugGui:AddVBox().
local debugStat1 is mainBox:AddLabel("Acceleration: ").
local debugStat2 is mainBox:AddLabel("Command Roll: ").
debugGui:Show().

local currentRoll is 0.
local rollPID is PIDLoop(6, 0.5, 6, 0, 180).
local currentSpeed is Ship:AirSpeed.
local currentTime is Time:Seconds.

set steeringmanager:RollControlAngleRange to 10.
set rollPID:SetPoint to 70.

local startTime is 0.

until Ship:AirSpeed < 1000
{
	wait 0.1.

	local accel is (Ship:AirSpeed - currentSpeed) / (Time:Seconds - currentTime).
	set currentSpeed to Ship:AirSpeed.
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
    
    if steeringmanager:RollControlAngleRange > 179
    {
        set currentRoll to rollPID:Update(Time:Seconds, -accel - Ship:VerticalSpeed / 12).
        set upVec to initVec * angleaxis(CurrentRoll, SrfRetrograde:Vector).
    }
}

if steeringmanager:RollControlAngleRange > 179 and Core:Part:HasModule("AdjustableComShifter")
{
    local comModule is Core:Part:GetModule("AdjustableComShifter").
    if comModule:HasEvent("Turn Descent Mode Off")
        comModule:DoEvent("Turn Descent Mode Off").
}
        
clearGuis().

unlock steering.
set Ship:Control:Neutralize to true.
rcs off.

set core:bootfilename to "".

wait until ship:airspeed < 50.

for hs in Ship:ModulesNamed("ModuleDecouple")
{
    if hs:HasEvent("jettison heat shield")
    {
        hs:DoEvent("jettison heat shield").
    }
}
