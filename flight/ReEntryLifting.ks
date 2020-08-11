@lazyglobal off.

wait until Ship:Unpacked.

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

runpath("0:/flight/tunesteering").
set steeringmanager:RollControlAngleRange to 180.
set steeringmanager:rolltorquefactor to 5.

unlock steering.
set Ship:Control:Neutralize to true.
rcs off.

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
lock steering to LookDirUp(SrfRetrograde:Vector, Ship:Up:Vector).

local debugGui is GUI(300, 80).
set debugGui:X to 100.
set debugGui:Y to debugGui:Y + 300.
local mainBox is debugGui:AddVBox().
local debugStat is mainBox:AddLabel("Ballisitc mode").
debugGui:Show().

local currentSpeed is Ship:AirSpeed.
local currentTime is Time:Seconds.

until Ship:AirSpeed < 1000 or accel < -50
{
	wait 0.1.

	local accel is (Ship:AirSpeed - currentSpeed) / (Time:Seconds - currentTime).
	set currentSpeed to Ship:AirSpeed.
	set currentTime to Time:Seconds.
	
	set debugStat:Text to "Ballistic Mode: " + round(accel, 2) + " m/s".
}

// set minimum controls to "disable" steering manager yaw/pitch.
set ship:control:yaw to 0.000011.
set ship:control:pitch to 0.000011.

if Core:Part:HasModule("AdjustableComShifter")
{
	local comModule is Core:Part:GetModule("AdjustableComShifter").

	print "Activating descent mode".
	comModule:DoEvent("Turn Descent Mode On").
	local descentMode is true.

	until Ship:AirSpeed < 1000
	{
		wait 0.1.

		local accel is (Ship:AirSpeed - currentSpeed) / (Time:Seconds - currentTime).
		set currentSpeed to Ship:AirSpeed.
		set currentTime to Time:Seconds.
		
		if descentMode and (accel > -40 or abs(ShipRoll()) > 70)
		{
			comModule:DoAction("Toggle Descent Mode", false).
			set descentMode to false.
		}
		else if not descentMode and accel < -50 and abs(ShipRoll()) < 60
		{
			comModule:DoAction("Toggle Descent Mode", true).
			set descentMode to true.
		}
		
		set debugStat:Text to (choose "Descent Mode: " if descentMode else "Ballistic Mode: ") + round(accel, 2) + " m/s".
	}

	if descentMode
		comModule:DoAction("Toggle Descent Mode", false).
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
