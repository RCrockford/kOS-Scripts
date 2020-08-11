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
	print "Escape system activated.".

	for e in LESBoosters
	{
		e:Activate.
	}
	for d in LESDecouple
	{
		LAS_FireDecoupler(d).
	}
	
	wait 0.2.
	local flamedOut is false.
	until flamedOut
	{
		// Get new engine list in case any have been destroyed.
		list engines in LESBoosters.
		set flamedOut to true.
		for e in LESBoosters
		{
			if e:tag:contains("les") and not e:Flameout
				set flamedOut to false.
		}
		
		wait 0.
	}
	print "Flameout on engines:".
	print LESBoosters.
	
	for e in LESBoosters
	{
		if e:tag:contains("les")
			LAS_FireDecoupler(e).
	}
	for p in Ship:PartsTaggedPattern("\blesbooster\b")
	{
		print "Decoupling " + p:Name.
		LAS_FireDecoupler(p).
	}
	
	wait until Ship:VerticalSpeed < 0.

	local chutesArmed is false.
	for modRealChute in Ship:ModulesNamed("RealChuteModule")
	{
		print "Arm chute: " + modRealChute:Part:Name.
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
