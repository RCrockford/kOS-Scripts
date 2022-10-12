@lazyglobal off.
wait until Ship:Unpacked.
local p is lexicon(open("1:/burn.csv"):readall:string:split(",")).
for k in p:keys
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
runoncepath("mgmt/readoutgui").
local _0 is RGUI_Create().
_0:SetColumnCount(60,list(160)).
local _1 is lexicon().
_1:Add("stat",_0:AddReadout("Status")).
_1:Add("ang",_0:AddReadout("Δθ")).
_1:Add("acc",_0:AddReadout("ω")).
_0:Show().
runoncepath("/fcfuncs").
runpath("flight/tunesteering").
local _2 is 0.
local _3 is 0.
if p:eng>0
{
runpath("/flight/enginemgmt",p:stage).
set _2 to EM_IgDelay().
set _3 to EM_GetEngines()[0].
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
local _4 is 0.
local _5 is vdot(Facing:Vector,Ship:AngularVel).
if p:haskey("spin")and vdot(dV:Normalized,Facing:Vector)>0.999
{
if abs(_5)>p:spin*1.25
{
set _4 to 0.1.
}
else if abs(_5)>p:spin and abs(_5)<p:spin*1.2
{
set _4 to-0.1.
}
else
{
set _4 to-1.
}
}
else
{
if abs(_5)<0.01
set _4 to choose-0.0001 if _5<0 else 0.0001.
}
set ship:control:roll to _4.
}
LAS_Avionics("activate").
CheckHeading().
rcs on.
lock steering to LookDirUp(dV:Normalized,Facing:UpVector).
RGUI_SetText(_1:stat,"Aligning").
until burnETA<=_2
{
RollControl().
CheckHeading().
local err is vang(dV:Normalized,Facing:Vector).
local _6 is vxcl(Facing:Vector,Ship:AngularVel):Mag*180/Constant:Pi.
local col is"#00ff00".
if err>0.5
set col to"#ff8000".
RGUI_SetText(_1:ang,round(err,2)+"°",col).
if err>0.5 and err/max(_6,1e-4)<burnETA-_2
set col to"#00ff00".
RGUI_SetText(_1:acc,round(_6,2)+"°/s",col).
local wr is kUniverse:TimeWarp:Rate.
if wr>1 and burnETA<=_2+20
kUniverse:Timewarp:CancelWarp().
if wr=1 and burnETA>=_2+40 and err<0.5 and _6<1/burnETA
set kUniverse:TimeWarp:Warp to 1.
if _2>0 and burnETA<=_2+8
{
if Ship:Control:Fore>0
{
if _3:FuelStability>=0.99
set Ship:Control:Fore to 0.
}
else
{
if _3:FuelStability<0.98
set Ship:Control:Fore to 1.
}
RGUI_SetText(_1:stat,"Ullage").
}
wait 0.
}
print"Starting burn T-"+round(_2,2).
if p:eng>0
runpath("flight/executeburneng",p,_0,dV).
else
runpath("flight/executeburnrcs",p,_0).
ClearGuis().
