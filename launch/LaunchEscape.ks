// Crewed launch escape system

@lazyglobal off.

local LESBoosters is list().
local LESDecouple is list().

for p in Ship:PartsTaggedPattern("\bles\b")
{
	if p:IsType("Engine")
		LESBoosters:Add(p).
	else
		LESDecouple:Add(p).
}

print "Found " + LESBoosters:Length + " escape engine" + (choose "" if LESBoosters:Length = 1 else "s") + " and " + LESDecouple:Length + " decoupler" + (choose "" if LESDecouple:Length = 1 else "s") + ".".
set LAS_HasEscapeSystem to true.

local function LAS_CrewEscapeImpl
{
    set kUniverse:TimeWarp:Rate to 1.
	print "Escape system activated.".

	for e in LESBoosters
	{
		e:Activate.
	}
	for d in LESDecouple
	{
		LAS_FireDecoupler(d).
	}
    
	wait 0.1.

    rcs off.
	for p in Ship:Parts
	{
		if p:IsType("rcs")
        {
            set p:enabled to true.
            rcs on.
        }
	}
    if rcs
        lock steering to lookdirup(Ship:Up, Facing:UpVector).
	
    local engineStart is Time:Seconds.
	local flamedOut is false.
	until flamedOut
	{
		// Get new engine list in case any have been destroyed.
		list engines in LESBoosters.
		set flamedOut to Time:Seconds > engineStart + 2.
		for e in LESBoosters
		{
			if e:tag:contains("les") and e:Thrust > e:PossibleThrust * 0.75
				set flamedOut to false.
		}
		
		wait 0.
	}
	print "Booster flameout".
	
	for e in LESBoosters
	{
		if e:tag:contains("les")
			LAS_FireDecoupler(e).
	}
	for p in Ship:PartsTaggedPattern("\blesbooster\b")
	{
		print "Decoupling " + p:Title.
		LAS_FireDecoupler(p).
	}
	
	wait until Ship:VerticalSpeed < 0.
    
    if rcs
        lock steering to lookdirup(SrfRetrograde:Vector, Facing:UpVector).
    
	for p in Ship:PartsTaggedPattern("\blescover\b")
	{
		print "Decoupling " + p:Title.
		LAS_FireDecoupler(p).
	}
    
	local chutesArmed is false.
	for modRealChute in Ship:ModulesNamed("RealChuteModule")
	{
		print "Arm chute: " + modRealChute:Part:Title.
		if modRealChute:HasEvent("arm parachute")
		{
			modRealChute:DoEvent("arm parachute").
			set chutesArmed to true.
		}
		else if modRealChute:HasEvent("deploy chute")
		{
			modRealChute:DoEvent("deploy chute").
			set chutesArmed to true.
		}
	}
	if not chutesArmed
		chutes on.
	print "Parachutes armed.".
    
    if rcs
    {
        wait until Alt:Radar < 4000.
        rcs off.
    }
    	
	shutdown.
}

local function LAS_EscapeJetissonImpl
{
	print "Escape system jetissoned.".
	for e in LESBoosters
	{
		e:Activate.		
		LAS_FireDecoupler(e).
	}
	for p in Ship:PartsTaggedPattern("\blesbooster\b")
	{
		LAS_FireDecoupler(p).
	}
	set LESBoosters to list().
	set LAS_HasEscapeSystem to false.
}

set LAS_CrewEscape to LAS_CrewEscapeImpl@.
set LAS_EscapeJetisson to LAS_EscapeJetissonImpl@.
