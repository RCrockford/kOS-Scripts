@lazyglobal off.

wait until Ship:Unpacked.

local p is readjson("1:/burn.json").

local lock tVec to Prograde:Vector.
local lock bVec to vcrs(tVec, up:vector):Normalized.
local lock nVec to vcrs(tVec, bVec):Normalized.

local dV is v(0,0,0).
if HasNode
{
    lock burnETA to NextNode:eta.
    set dV to NextNode:deltaV.
}
else
{
    lock burnETA to p:eta - Time:Seconds.
    set dV to tVec * p:dV:x + nVec * p:dV:y + bVec * p:dV:z.
}

print "Align in " + round(burnETA - p:align, 0) + " seconds (T-" + round(p:align) + ").".

wait until burnETA <= p:align.

kUniverse:Timewarp:CancelWarp().
print "Aligning ship".

local debugGui is GUI(350, 80).
set debugGui:X to 100.
set debugGui:Y to debugGui:Y + 300.
local mainBox is debugGui:AddVBox().
local debugStat is mainBox:AddLabel("Aligning ship").
debugGui:Show().

runoncepath("/FCFuncs").
runpath("flight/TuneSteering").

local ignitionTime is 0.
if p:eng
{
    runpath("/flight/EngineMgmt", p:stage).
    set ignitionTime to EM_IgDelay().
}

local function CheckHeading
{
    if HasNode and nextNode:eta <= p:align
        set dV to NextNode:deltaV.
    else if p:haskey("dV")
        set dV to tVec * p:dV:x + nVec * p:dV:y + bVec * p:dV:z.
}

local function RollControl
{
    local rollRate is vdot(Facing:Vector, Ship:AngularVel).
    if abs(rollRate) < 1e-3
        set ship:control:roll to choose -0.000011 if rollRate < 0 else 0.000011.
    else
        set ship:control:roll to 0.
}

LAS_Avionics("activate").
CheckHeading().

rcs on.
lock steering to LookDirUp(dV:Normalized, Facing:UpVector).

if p:inertial
{
    // spin up
    until burnETA <= ignitionTime
    {
        if vdot(dV:Normalized, Facing:Vector) > 0.99
        {
            local rollRate is vdot(Facing:Vector, Ship:AngularVel).
            if abs(rollRate) > p:spin * 1.25
            {
                set Ship:Control:Roll to 0.1.
            }
            else if abs(rollRate) > p:spin and abs(rollRate) < p:spin * 1.2
            {
                set Ship:Control:Roll to -0.1.
            }
            else
            {
                set Ship:Control:Roll to -1.
            }
        }

        CheckHeading().
        wait 0.
    }

    set Ship:Control:Roll to -0.1.
}
else
{
    until burnETA <= ignitionTime
    {
        RollControl().
    
        local err is vang(dV:Normalized, Facing:Vector).
        local omega is  vxcl(Facing:Vector, Ship:AngularVel):Mag * 180 / Constant:Pi.
		set debugStat:Text to "Aligning ship, <color=" + (choose "#ff8000" if err > 0.5 else "#00ff00") + ">Δθ: " + round(err, 2)
            + "°</color> <color=" + (choose "#ff8000" if err / max(omega, 1e-4) > burnETA - ignitionTime else "#00ff00") + ">ω: " + round(omega, 3) + "°/s</color> roll: " + round(vdot(Facing:Vector, Ship:AngularVel), 6).

        // Pre-ullage
        if p:eng and EM_IgDelay() > 0 and burnETA <= ignitionTime + 8
        {
            if Ship:Control:Fore > 0
            {
                if EM_GetEngines()[0]:FuelStability >= 0.99
                    set Ship:Control:Fore to 0.
            }
            else
            {
                if EM_GetEngines()[0]:FuelStability < 0.98  
                    set Ship:Control:Fore to 1.
            }
        }
        wait 0.
    }
    CheckHeading().
}

print "Starting burn".

// If we have engines, ignite them.
if p:eng
{
	set debugStat:Text to "Ignition".
	
	local duration to p:t.
	if not p:inertial
		set duration to (ship:Mass - ship:Mass / p:mRatio) / p:mFlow.
	
    local fuelRes is 0.
    local fuelTarget is 0.
    for r in Ship:Resources
    {
        if r:Name = p:fuelN
        {
            set fuelRes to r.
            // Wait until we have burned the right amount of fuel.
            set fuelTarget to r:Amount -  p:fFlow * duration.
        }
    }
	local fuelStart is fuelRes:Amount.

    EM_Ignition().

    // If this is a spun kick stage, then decouple it.
    if p:inertial
    {
        wait until Stage:Ready.
        unlock steering.
        set Ship:Control:Neutralize to true.
        rcs off.
        stage.
    }
	
	local burnStart is Time:Seconds.

    until fuelRes:Amount <= fuelTarget or not EM_CheckThrust(0.1)
    {
		local prevUpdate is Time:Seconds.
        CheckHeading().
        RollControl().
		set debugStat:Text to "Burning, Fuel: " + round(fuelRes:Amount, 2) + " / " + round(fuelTarget, 2) + " [" + round((fuelRes:Amount - fuelTarget) / p:fFlow, 2) + "s]".
        wait 0.
		// Break if we'll hit the target fuel in one update.
		if fuelRes:Amount - (p:fFlow * (Time:Seconds - prevUpdate)) <= fuelTarget
			break.
    }

    EM_Shutdown().
}
else
{
    // Otherwise assume this is an RCS burn
    set Ship:Control:Fore to 1.

    local stopTime is Time:Seconds + p:t.
    until stopTime <= Time:Seconds
    {
		set debugStat:Text to "Burning, Cutoff: " + round(stopTime - Time:Seconds, 1) + " s".
        CheckHeading().
        RollControl().
        wait 0.
    }

    unlock steering.
    set Ship:Control:Neutralize to true.
    rcs off.

    LAS_Avionics("shutdown").
}
ClearGuis().
