@lazyglobal off.
wait until Ship:Unpacked.
local p is readjson("1:/burn.json").
local lock _f0 to Prograde:Vector.
local lock _f1 to vcrs(_f0,up:vector):Normalized.
local lock _f2 to vcrs(_f0,_f1):Normalized.
local dV is v(0,0,0).
if HasNode
{
lock burnETA to NextNode:eta.
set dV to NextNode:deltaV.
}
else
{
lock burnETA to p:eta-Time:Seconds.
set dV to _f0*p:dV:x+_f2*pDv:y+_f1*p:dV:z.
}
print"Align in "+round(burnETA-p:align,0)+" seconds.".
wait until burnETA<=p:align.
kUniverse:Timewarp:CancelWarp().
print"Aligning ship".
local _0 is GUI(350,80).
set _0:X to 100.
set _0:Y to _0:Y+300.
local _1 is _0:AddVBox().
local _2 is _1:AddLabel("Aligning ship").
_0:Show().
runoncepath("/FCFuncs").
runpath("flight/TuneSteering").
local _3 is 0.
if p:eng
{
runpath("/flight/EngineMgmt",p:stage).
set _3 to EM_IgDelay().
}
local function _f3
{
if HasNode and nextNode:eta<=p:align
set dV to NextNode:deltaV.
else if p:haskey("dV")
set dV to _f0*p:dV:x+_f2*pDv:y+_f1*p:dV:z.
}
LAS_Avionics("activate").
_f3().
rcs on.
lock steering to LookDirUp(dV:Normalized,Facing:UpVector).
if p:inertial
{
until burnETA<=_3
{
if vdot(dV:Normalized,Facing:Vector)>0.99
{
local _4 is vdot(Facing:Vector,Ship:AngularVel).
if abs(_4)>p:spin*1.25
{
set Ship:Control:Roll to 0.1.
}
else if abs(_4)>p:spin and abs(_4)<p:spin*1.2
{
set Ship:Control:Roll to-0.1.
}
else
{
set Ship:Control:Roll to-1.
}
}
_f3().
wait 0.
}
set Ship:Control:Roll to-0.1.
}
else
{
until burnETA<=_3+min(max(p:align/40,2),10).
{
local err is vang(dV:Normalized,Facing:Vector).
local _5 is Ship:AngularVel:Mag*180/Constant:Pi.
set _2:Text to"Aligning ship, <color="+(choose"#ff8000"if err>0.5 else"#00ff00")+">Δθ: "+round(err,2)
+"°</color> <color="+(choose"#ff8000"if err/max(_5,1e-4)>burnETA-_3 else"#00ff00")+">ω: "+round(_5,3)+"°/s</color>".
wait 0.
}
_f3().
if p:eng and EM_IgDelay()>0
{
rcs on.
set Ship:Control:Fore to 1.
until burnETA<=_3
{
if EM_GetEngines()[0]:FuelStability>=0.99
{
set ship:control:fore to 0.
break.
}
wait 0.
}
}
wait until burnETA<=_3.
}
print"Starting burn".
if p:eng
{
set _2:Text to"Ignition".
local _6 to p:t.
if not p:inertial
set _6 to(ship:Mass-ship:Mass/p:mRatio)/p:mFlow.
local _7 is 0.
local _8 is 0.
for r in Ship:Resources
{
if r:Name=p:fuelN
{
set _7 to r.
set _8 to r:Amount-p:fFlow*_6.
}
}
local _9 is _7:Amount.
EM_Ignition().
if p:inertial
{
wait until Stage:Ready.
unlock steering.
set Ship:Control:Neutralize to true.
rcs off.
stage.
}
local _10 is Time:Seconds.
until _7:Amount<=_8 or not EM_CheckThrust(0.1)
{
local _11 is Time:Seconds.
_f3().
set _2:Text to"Burning, Fuel: "+round(_7:Amount,2)+" / "+round(_8,2)+" ["+round((_7:Amount-_8)/p:fFlow,2)+"s]".
wait 0.
if _7:Amount-(p:fFlow*(Time:Seconds-_11))<=_8
break.
}
EM_Shutdown().
}
else
{
set Ship:Control:Fore to 1.
local _12 is Time:Seconds+p:t.
until _12<=Time:Seconds
{
set _2:Text to"Burning, Cutoff: "+round(_12-Time:Seconds,1)+" s".
_f3().
wait 0.
}
unlock steering.
set Ship:Control:Neutralize to true.
rcs off.
LAS_Avionics("shutdown").
}
ClearGuis().
