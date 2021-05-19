@lazyglobal off.

wait until Ship:Unpacked.

local p is lexicon(open("1:/burn.csv"):readall:string:split(",")).
for k in p:keys
    set p[k] to p[k]:ToScalar(0).

local lock tVec to Prograde:Vector.
local lock bVec to vcrs(tVec, up:vector):Normalized.
local lock nVec to vcrs(tVec, bVec):Normalized.

local dv is 0.
if HasNode
    lock burnETA to NextNode:eta.
else
	lock burnETA to p:eta - Time:Seconds.

print "Settle in " + round(burnETA - 30, 0) + " seconds.".

wait until burnETA < 30.

kUniverse:Timewarp:CancelWarp().
print "Settling ship".

runoncepath("/FCFuncs").

local function CheckHeading
{
	if HasNode and nextNode:eta < 60
		set dV to NextNode:deltaV.
    else if p:haskey("dVx")
        set dV to tVec * p:dVx + nVec * p:dVy + bVec * p:dVz.
}

LAS_Avionics("activate").
CheckHeading().

rcs on.
lock steering to "kill".

wait until burnETA <= 0.

local burnTime is p:t.
local startTime is Time:Seconds.
until burnTime <= 0
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
    
    local t is Time:Seconds.
    local dt is t - startTime.
    set startTime to t.
    set burnTime to burnTime - dt * ship:control:translation:mag.
}

unlock steering.
set Ship:Control:Neutralize to true.
rcs off.

LAS_Avionics("shutdown").