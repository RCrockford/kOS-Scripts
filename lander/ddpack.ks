@clobberbuiltins on.
@lazyglobal off.
wait until Ship:Unpacked.
parameter _0 is max(Stage:Number-1,0).
parameter _1 is 1.5.
parameter _2 is false.
parameter _3 is 0.
switch to scriptpath():volume.
runpath("/flight/enginemgmt",min(Stage:Number,_0+1)).
runpath("/flight/tunesteering").
runoncepath("/lander/landersteering").
local _4 is EM_GetEngines().
local _5 is 0.
local _6 is 0.
for eng in _4
{
set _5 to _5+eng:PossibleThrust.
set _6 to _6+eng:MaxMassFlow.
}
local _7 is Ship:Mass.
local _8 is 1.
local _9 is false.
local function _f0
{
parameter _p0 is LAS_ShipPos().
parameter _p1 is Ship:Velocity:Surface.
local _10 is LanderSteering(_p0,_p1,0.2).
local _11 is-vdot(_p1:Normalized,Up:Vector)*_8.
local _12 is(_11*Up:Vector+sqrt(1-_11^2)*_10:vec):Normalized.
return _12.
}
local function _f1
{
parameter _p0.
parameter _p1.
parameter _p2 is 0.25.
local _13 is Ship:Velocity:Surface.
local _14 is _7.
local _15 is LAS_ShipPos().
until vdot(_13,Up:Vector)>_p0 or _14<_6*2
{
local _16 is 0.
if _p1<_p2
set _16 to((_p2-_p1)/_p2).
local _17 is _16*_f0(_15,_13)*_5/_14.
set _p1 to max(0,_p1-_p2).
local g is-_15:Normalized*Body:Mu/_15:SqrMagnitude.
set _13 to _13+(_17+g)*_p2.
set _15 to _15+_13*_p2.
set _14 to _14-_6*_16*_p2.
}
return _15.
}
local function RC
{
parameter _p0.
if _9 and abs(SteeringManager:AngleError)<1
{
local _18 is vdot(Facing:Vector,Ship:AngularVel).
if abs(_18)>1.2
{
set ship:control:roll to-0.01.
}
else
{
set ship:control:roll to-1.
}
}
if _p0 and EM_IgDelay()>0
{
if Ship:Control:Fore>0
{
if EM_GetEngines()[0]:FuelStability>=0.99
set Ship:Control:Fore to 0.
}
else
{
if EM_GetEngines()[0]:FuelStability<0.98
set Ship:Control:Fore to 1.
}
}
}
if Ship:Status="Flying"or Ship:Status="Sub_Orbital"or Ship:Status="Escaping"
{
print"Direct descent system online.".
if HasTarget and _3:IsType("Scalar")
set _3 to Target.
runoncepath("/mgmt/readoutgui").
local _19 is ReadoutGUI_Create().
_19:SetColumnCount(80,3).
local _20 is lexicon().
_20:Add("height",_19:AddReadout("Height")).
_20:Add("acgx",_19:AddReadout("Acgx")).
_20:Add("fr",_19:AddReadout("fr")).
_20:Add("throt",_19:AddReadout("Throttle")).
_20:Add("thrust",_19:AddReadout("Thrust")).
_20:Add("status",_19:AddReadout("Status")).
_20:Add("dist",_19:AddReadout("Distance")).
_20:Add("bearing",_19:AddReadout("Bearing")).
_20:Add("eta",_19:AddReadout("ETA")).
_19:Show().
ReadoutGUI_SetText(_20:status,"Ready",ReadoutGUI_ColourNormal).
if Stage:Number>_0 or Ship:Velocity:Surface:Mag>300
{
set _9 to _0<Stage:Number-1.
if _9
{
print"Using unguided braking stage".
set _7 to 0.
for shipPart in Ship:Parts
{
local _21 is shipPart:DecoupledIn.
if shipPart:DecoupledIn<Stage:Number-1
{
set _7 to _7+shipPart:Mass.
}
}
}
print" Engine: "+_4[0]:Config+", Ship Mass: "+round(_7*1000,1)+" kg".
LanderSelectWP(_3).
local _22 is LanderTargetPos().
local _23 is(0.7-_7*0.035)*Body:Mu/(Body:Radius^2).
if Body:Mu/LAS_ShipPos():SqrMagnitude<_23 and Ship:GeoPosition:TerrainHeight/Body:Radius<0.01
{
if _22:IsType("GeoCoordinates")and Body:Mu/LAS_ShipPos():SqrMagnitude<_23*(choose 0.8 if _2 else 0.25)
{
print"Waiting for gravity to increase to "+round(_23*0.2,3)+" m/s for CCM".
set kUniverse:Timewarp:Rate to 10.
wait until Body:Mu/LAS_ShipPos():SqrMagnitude>=_23*0.2.
set kUniverse:Timewarp:Rate to 1.
local lock _f2 to vcrs(Ship:Velocity:Surface:Normalized,-Body:Position:Normalized):Normalized.
print"d="+vdot(_22:Position:Normalized,_f2).
if abs(vdot(_22:Position:Normalized,_f2))>2e-4
{
print"Performing course correction.".
LAS_Avionics("activate").
rcs on.
local lock _f3 to(_f2*vdot(_22:Position:Normalized,_f2)):Normalized.
lock steering to LookDirUp(_f3,Facing:UpVector).
until vdot(Facing:Vector,_f3)>0.999
{
ReadoutGUI_SetText(_20:fr,round(vdot(Facing:Vector,_f3),3),ReadoutGUI_ColourNormal).
wait 0.
}
set Ship:Control:Fore to 1.
until abs(vdot(_22:Position:Normalized,_f2))<1e-4 or vdot(Facing:Vector,_f3)<0.995
{
ReadoutGUI_SetText(_20:dist,round(vdot(_22:Position:Normalized,_f2),6),ReadoutGUI_ColourNormal).
ReadoutGUI_SetText(_20:fr,round(vdot(Facing:Vector,_f3),3),ReadoutGUI_ColourNormal).
wait 0.
}
unlock steering.
rcs off.
LAS_Avionics("shutdown").
}
}
print"Waiting for gravity to increase to "+round(_23,3)+" m/s for braking".
set kUniverse:Timewarp:Rate to 10.
wait until Body:Mu/LAS_ShipPos():SqrMagnitude>=_23.
}
set kUniverse:Timewarp:Rate to 1.
local _24 is choose-10 if stage:number>_0 else-50.
local _25 is v(0,0,0).
local function _f4
{
parameter _p0.
parameter _p1.
local lock _f5 to round(Ship:Velocity:Surface:Mag*_1).
local alt is Ship:Altitude.
until alt<_f5-Ship:VerticalSpeed*0.5
{
local _26 is Time:Seconds.
local _27 is _f1(_24,_p0).
local _28 is Body:GeoPositionOf(_27+Body:Position).
set alt to _27:Mag-Body:Radius-_28:TerrainHeight.
ReadoutGUI_SetText(_20:height,round(alt*0.001,1)+" km",ReadoutGUI_ColourNormal).
ReadoutGUI_SetText(_20:acgx,round(_f5*0.001,1)+" km",ReadoutGUI_ColourNormal).
if _22:IsType("GeoCoordinates")
{
local _29 is vang(vxcl(up:vector,_22:Position),vxcl(up:vector,Ship:Velocity:Surface)).
ReadoutGUI_SetText(_20:dist,round(_22:Distance*0.001,1)+" km",ReadoutGUI_ColourNormal).
ReadoutGUI_SetText(_20:bearing,round(_29,3)+"°",ReadoutGUI_ColourNormal).
}
local _30 is alt<_f5-Ship:VerticalSpeed*8.
if _30
{
if kUniverse:Timewarp:Rate<>1
set kUniverse:Timewarp:Rate to 1.
wait until Time:Seconds>=_26+0.2.
}
else
{
if not rcs and kUniverse:Timewarp:Rate<>10
set kUniverse:Timewarp:Rate to 10.
wait until Time:Seconds>=_26+1.
}
_p1(_30).
set _25 to _28.
}
}
ReadoutGUI_SetText(_20:status,"Wait Align",ReadoutGUI_ColourNormal).
_f4(choose 90 if _9 else 60,{parameter c.}).
set kUniverse:Timewarp:Rate to 1.
wait until kUniverse:Timewarp:Rate=1.
print"Aligning for burn".
ReadoutGUI_SetText(_20:status,"Aligning",ReadoutGUI_ColourNormal).
LAS_Avionics("activate").
rcs on.
if _9
{
local _31 is constant:e^(Velocity:Surface:Mag*_6/_5).
local _32 is _7/_31.
local _33 is(_7-_32)/_6.
set _8 to Ship:VerticalSpeed/(Ship:VerticalSpeed+_33*0.8*(Body:Mu/LAS_ShipPos():SqrMagnitude)).
}
lock steering to LookDirUp(_f0(),Facing:UpVector).
set navmode to"surface".
ReadoutGUI_SetText(_20:status,"Wait Ignition",ReadoutGUI_ColourNormal).
_f4(EM_IgDelay(),RC@).
print"Beginning braking burn".
ReadoutGUI_SetText(_20:status,"Braking",ReadoutGUI_ColourNormal).
ReadoutGUI_SetText(_20:throt,"100%",ReadoutGUI_ColourNormal).
until _4[0]:Ignitions=0 or EM_CheckThrust(0.1)
EM_Ignition(0.1).
if _9
{
wait until Stage:Ready.
stage.
set Ship:Control:Neutralize to true.
unlock steering.
}
if _22:IsType("GeoCoordinates")
{
local _34 is vdot(_22:Position-_25:Position,vxcl(Up:Vector,Ship:Velocity:Surface):Normalized).
set _8 to 1+max(-0.02,min((_34-2500)/20000,0.02)).
}
until(Ship:VerticalSpeed>=_24 and Ship:Velocity:Surface:Mag<-_24)or not EM_CheckThrust(0.1)
{
local t is Ship:Velocity:Surface:Mag*Ship:Mass/_5.
if _22:IsType("GeoCoordinates")
{
local _35 is vang(vxcl(up:vector,_22:Position),vxcl(up:vector,Ship:Velocity:Surface)).
ReadoutGUI_SetText(_20:dist,round(_22:Distance*0.001,1)+" km",ReadoutGUI_ColourNormal).
ReadoutGUI_SetText(_20:bearing,round(_35,3)+"°",ReadoutGUI_ColourNormal).
if t<100
{
local _36 is 1-vdot(Up:Vector,Ship:Velocity:Surface:Normalized)^2.
local _37 is _36*_5/Ship:Mass.
local _38 is Ship:GroundSpeed*t-0.5*_37*t^2.
local _39 is _22:Distance-(_36*-_24*30+_38).
if t<=60 and abs(_35)<2
{
set _8 to 1+max(-0.1,min((_39-1500)/10000,0.1)).
}
}
}
local h is Ship:Altitude-Ship:GeoPosition:TerrainHeight.
local _40 is-(_24^2-Ship:VerticalSpeed^2)/(2*h).
local fr is(_40+Body:Mu/Body:Position:SqrMagnitude)*Ship:Mass/_5.
ReadoutGUI_SetText(_20:height,round(h)+" m",ReadoutGUI_ColourNormal).
ReadoutGUI_SetText(_20:acgx,round(_40,3),ReadoutGUI_ColourNormal).
ReadoutGUI_SetText(_20:fr,round(fr,3),ReadoutGUI_ColourNormal).
local _41 is Ship:AvailableThrust.
ReadoutGUI_SetText(_20:thrust,round(100*min(Ship:Thrust/max(Ship:AvailableThrust,0.001),2),2)+"%",
choose ReadoutGUI_ColourGood if Ship:Thrust>_41*0.75 else(choose ReadoutGUI_ColourNormal if Ship:Thrust>_41*0.25 else ReadoutGUI_ColourFault)).
ReadoutGUI_SetText(_20:eta,round(t,2)+" s",ReadoutGUI_ColourNormal).
if _9 and vdot(Facing:Vector,SrfRetrograde:Vector)<0.3
break.
if stage:number=_0 and fr<0.8 and Ship:VerticalSpeed>=_24*2
break.
wait 0.
}
if not EM_CheckThrust(0.1).
print"Fuel exhaustion in braking stage".
if stage:number>_0
{
set Ship:Control:PilotMainThrottle to 0.
wait until(Ship:VerticalSpeed<=_24*2).
stage.
}
}
else
{
LanderSelectWP(_3).
LAS_Avionics("activate").
rcs on.
}
if _9 and vdot(Facing:Vector,Ship:AngularVel)>0.25
{
set ship:control:roll to 1.
wait vdot(Facing:Vector,Ship:AngularVel)<0.25.
set ship:control:roll to 0.
}
wait until stage:ready.
set navmode to"surface".
for p in Ship:Parts
{
for r in p:resources
{
set r:enabled to true.
}
}
if _0>0
{
set _4 to LAS_GetStageEngines(_0).
}
else
{
list engines in _4.
}
set Ship:Control:PilotMainThrottle to 0.
for eng in _4
eng:Shutdown.
runpath("/lander/finaldescent",_4,_20,LanderTargetPos()).
}
