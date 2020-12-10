@lazyglobal off.

wait until Ship:Unpacked.

local p is readjson("1:/burn.json").

local lock tVec to Prograde:Vector.
local lock bVec to vcrs(tVec, up:vector):Normalized.
local lock nVec to vcrs(tVec, bVec):Normalized.

local dv is V(0,0,0).
if HasNode
{
    lock burnETA to NextNode:eta.
	set dV to NextNode:deltaV.
}
else
{
	lock burnETA to p:eta - Time:Seconds.
    set dV to tVec * p:dV:x + nVec * p:dv:y + bVec * p:dV:z.
}

print "Settle in " + round(burnETA - 30, 0) + " seconds.".

wait until burnETA < 30.

kUniverse:Timewarp:CancelWarp().
print "Settling ship".

runoncepath("/FCFuncs").

local function CheckHeading
{
	if HasNode and nextNode:eta < 60
		set dV to NextNode:deltaV.
	else if p:haskey("dV")
		set dV to tVec * p:dV:x + nVec * p:dV:y + bVec * p:dV:z.
}

LAS_Avionics("activate").
CheckHeading().

rcs on.
lock steering to "kill".

wait until burnETA <= 0.

local stopTime is Time:Seconds + p:t.
until stopTime <= Time:Seconds
{
	// Set thrust vector
	local sf is facing.
	local dvN is dv:Normalized.
	local f is vdot(sf:vector, dvN).
	local s is vdot(sf:starvector, dvN).
	local u is vdot(sf:upvector, dvN).
	
	// scale by throttles for nominal thrust
	set f to f * (choose p:fth if f >= 0 else p:ath).
	set s to s * (choose p:sth if s >= 0 else p:pth).
	set u to u * (choose p:uth if u >= 0 else p:dth).
	
	set ship:control:translation to V(s, u, f).

	CheckHeading().
	wait 0.
}

unlock steering.
set Ship:Control:Neutralize to true.
rcs off.

LAS_Avionics("shutdown").