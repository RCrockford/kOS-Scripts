@lazyglobal off.
wait until Ship:Unpacked.
local p is lexicon(open("1:/burn.csv"):readall:string:split(",")).
for k in p:keys
set p[k]to p[k]:ToScalar(0).
local lock _f0 to Prograde:Vector.
local lock _f1 to vcrs(_f0,up:vector):Normalized.
local lock _f2 to vcrs(_f0,_f1):Normalized.
local dv is 0.
if HasNode
lock burnETA to NextNode:eta.
else
lock burnETA to p:eta-Time:Seconds.
print"Settle in "+round(burnETA-30,0)+" seconds.".
wait until burnETA<30.
kUniverse:Timewarp:CancelWarp().
print"Settling ship".
runoncepath("/FCFuncs").
local function _f3
{
if HasNode and nextNode:eta<60
set dV to NextNode:deltaV.
else if p:haskey("dVx")
set dV to _f0*p:dVx+_f2*p:dVy+_f1*p:dVz.
}
LAS_Avionics("activate").
_f3().
rcs on.
lock steering to"kill".
wait until burnETA<=0.
local _0 is p:t.
local _1 is Time:Seconds.
until _0<=0
{
local sf is facing.
local dvN is dv:Normalized.
local f is vdot(sf:vector,dvN).
local s is vdot(sf:starvector,dvN).
local u is vdot(sf:upvector,dvN).
set f to f*(choose p:fth if f>=0 else p:ath).
set s to s*(choose p:sth if s>=0 else p:pth).
set u to u*(choose p:uth if u>=0 else p:dth).
set ship:control:translation to V(s,u,f).
_f3().
wait 0.
local t is Time:Seconds.
local dt is t-_1.
set _1 to t.
set _0 to _0-dt*ship:control:translation:mag.
}
unlock steering.
set Ship:Control:Neutralize to true.
rcs off.
LAS_Avionics("shutdown").
