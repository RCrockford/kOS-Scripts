@lazyglobal off.
wait until Ship:Unpacked.
local p is lexicon(open("1:/burn.csv"):readall:string:split(",")).
for k in p:keys
if k<>"fuelN"
set p[k]to p[k]:ToScalar(0).
local lock _f0 to Prograde:Vector.
local lock _f1 to vcrs(_f0,up:vector):Normalized.
local lock _f2 to vcrs(_f0,_f1):Normalized.
local dV is 0.
if HasNode
lock burnETA to NextNode:eta.
else
lock burnETA to p:eta-Time:Seconds.
print"Align in "+round(burnETA-p:align,0)+" seconds (T-"+round(p:align)+").".
wait until burnETA<=p:align.
kUniverse:Timewarp:CancelWarp().
if scriptpath():ToString[0]="0"
{
print"Waiting for downlink".
wait until HomeConnection:IsConnected.
}
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
local _4 is 0.
if p:eng>0
{
runpath("/flight/EngineMgmt",p:stage).
set _3 to EM_IgDelay().
set _4 to EM_GetEngines()[0].
}
global function CheckHeading
{
if HasNode and nextNode:eta<=p:align
set dV to NextNode:deltaV.
else if p:haskey("dVx")
set dV to _f0*p:dVx+_f2*p:dVy+_f1*p:dVz.
}
global function RollControl
{
local _5 is 0.
local _6 is vdot(Facing:Vector,Ship:AngularVel).
if p:int>0 and vdot(dV:Normalized,Facing:Vector)>0.99
{
if abs(_6)>p:spin*1.25
{
set _5 to 0.1.
}
else if abs(_6)>p:spin and abs(_6)<p:spin*1.2
{
set _5 to-0.1.
}
else
{
set _5 to-1.
}
}
else
{
if abs(_6)<1e-3
set _5 to choose-0.000011 if _6<0 else 0.000011.
}
set ship:control:roll to _5.
}
LAS_Avionics("activate").
CheckHeading().
rcs on.
lock steering to LookDirUp(dV:Normalized,Facing:UpVector).
until burnETA<=_3
{
RollControl().
local err is vang(dV:Normalized,Facing:Vector).
local _7 is vxcl(Facing:Vector,Ship:AngularVel):Mag*180/Constant:Pi.
set _2:Text to"Aligning ship, <color="+(choose"#ff8000"if err>0.5 else"#00ff00")+">Δθ: "+round(err,2)
+"°</color> <color="+(choose"#ff8000"if err/max(_7,1e-4)>burnETA-_3 else"#00ff00")+">ω: "+round(_7,3)+"°/s</color> roll: "+round(vdot(Facing:Vector,Ship:AngularVel),6).
if _3>0 and burnETA<=_3+8
{
if Ship:Control:Fore>0
{
if _4:FuelStability>=0.99
set Ship:Control:Fore to 0.
}
else
{
if _4:FuelStability<0.98
set Ship:Control:Fore to 1.
}
}
wait 0.
}
CheckHeading().
print"Starting burn".
if p:eng>0
runpath("flight/ExecuteBurnEng",p,_2).
else
runpath("flight/ExecuteBurnRCS",p,_2).
ClearGuis().
