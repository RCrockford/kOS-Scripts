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
local _10 is lexicon("Count",0,"Mass",0,"PreStageMass",0,"FuelMass",0,"Thrust",0,"MassFlow",0,"DeltaV",0).
local function _f0
{
parameter _p0 is LAS_ShipPos().
parameter _p1 is Ship:Velocity:Surface.
local _11 is LanderSteering(_p0,_p1,0.2).
local _12 is-vdot(_p1:Normalized,Up:Vector)*_8.
local _13 is(_12*Up:Vector+sqrt(1-_12^2)*_11:vec):Normalized.
return _13.
}
local function _f1
{
parameter _p0.
parameter _p1.
parameter _p2 is 0.25.
local _14 is Ship:Velocity:Surface.
local _15 is _7.
local _16 is LAS_ShipPos().
local _17 is _10:Count>0.
local _18 is _5.
local _19 is _6.
local _20 is _6*2.
until vdot(_14,Up:Vector)>_p0 or _15<_20
{
local _21 is 0.
if _p1<_p2
set _21 to((_p2-_p1)/_p2).
local _22 is _21*_f0(_16,_14)*_18/_15.
set _p1 to max(0,_p1-_p2).
local g is-_16:Normalized*Body:Mu/_16:SqrMagnitude.
set _14 to _14+(_22+g)*_p2.
set _16 to _16+_14*_p2.
set _15 to _15-_19*_21*_p2.
if _17 and _15<=_10:PreStageMass
{
set _17 to false.
set _15 to _10:Mass.
set _18 to _10:Thrust.
set _19 to _10:MassFlow.
set _20 to _15-_10:FuelMass.
}
}
return _16.
}
local function RC
{
parameter _p0.
local _23 is 0.
local _24 is vdot(Facing:Vector,Ship:AngularVel).
if _9 or _10:Count>1
{
if abs(SteeringManager:AngleError)<1
{
if abs(_24)>1.2+_10:Count*0.5
{
set _23 to-0.001.
}
else
{
set _23 to-1.
}
}
}
else
{
if abs(_24)>0.01
set _23 to _24.
}
set ship:control:roll to _23.
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
local _25 is RGUI_Create().
_25:SetColumnCount(80,3).
local _26 is lexicon().
_26:Add("height",_25:AddReadout("Height")).
_26:Add("acgx",_25:AddReadout("Acgx")).
_26:Add("fr",_25:AddReadout("fr")).
_26:Add("throt",_25:AddReadout("Throttle")).
_26:Add("thrust",_25:AddReadout("Thrust")).
_26:Add("status",_25:AddReadout("Status")).
_26:Add("dist",_25:AddReadout("Distance")).
_26:Add("bearing",_25:AddReadout("Bearing")).
_26:Add("eta",_25:AddReadout("ETA")).
_25:Show().
RGUI_SetText(_26:status,"Ready",RGUI_ColourNormal).
if Stage:Number>_0 or Ship:Velocity:Surface:Mag>300
{
if _0<Stage:Number-1
{
local _27 is 0.
for eng in Ship:Engines
{
if(eng:Stage=Stage:Number-1)and(not eng:AllowShutdown)
{
set _10:Count to _10:Count+1.
set _10:FuelMass to _10:FuelMass+eng:Mass-Eng:DryMass.
set _10:Thrust to _10:Thrust+eng:PossibleThrust.
set _10:MassFlow to _10:MassFlow+eng:MaxMassFlow.
set _27 to max(_27,eng:residuals).
}
}
if _10:Count>0
{
for shipPart in Ship:Parts
{
local _28 is shipPart:DecoupledIn.
if shipPart:DecoupledIn<Stage:Number-1
{
set _10:Mass to _10:Mass+shipPart:Mass.
set _10:PreStageMass to _10:PreStageMass+shipPart:Mass.
}
else
{
set _10:PreStageMass to _10:PreStageMass+shipPart:DryMass.
}
}
set _10:FuelMass to _10:FuelMass*(1-_27).
local _29 is _10:Mass/(_10:Mass-_10:FuelMass).
set _10:DeltaV to ln(_29)*_10:Thrust/_10:MassFlow.
EM_ResetEngines(Stage:Number).
print"Using solid braking stage: "+round(_10:DeltaV,1)+" m/s".
}
else
{
set _9 to true.
print"Using unguided braking stage".
set _7 to 0.
for shipPart in Ship:Parts
{
local _30 is shipPart:DecoupledIn.
if shipPart:DecoupledIn<Stage:Number-1
{
set _7 to _7+shipPart:Mass.
}
}
}
}
print" Engine: "+_4[0]:Config+", Ship Mass: "+round(_7*1000,1)+" kg".
LanderSelectWP(_3).
local _31 is LanderTargetPos().
local _32 is(0.7-_7*0.035)*Body:Mu/(Body:Radius^2).
if Body:Mu/LAS_ShipPos():SqrMagnitude<_32 and Ship:GeoPosition:TerrainHeight/Body:Radius<0.01
{
if _31:IsType("GeoCoordinates")and Body:Mu/LAS_ShipPos():SqrMagnitude<_32*(choose 0.8 if _2 else 0.25)
{
print"Waiting for gravity to increase to "+round(_32*0.2,3)+" m/s for CCM".
set kUniverse:Timewarp:Rate to 10.
wait until Body:Mu/LAS_ShipPos():SqrMagnitude>=_32*0.2.
set kUniverse:Timewarp:Rate to 1.
local lock _f2 to vcrs(Ship:Velocity:Surface:Normalized,-Body:Position:Normalized):Normalized.
print"d="+vdot(_31:Position:Normalized,_f2).
if abs(vdot(_31:Position:Normalized,_f2))>2e-4
{
print"Performing course correction.".
LAS_Avionics("activate").
rcs on.
local lock _f3 to(_f2*vdot(_31:Position:Normalized,_f2)):Normalized.
lock steering to LookDirUp(_f3,Facing:UpVector).
until vdot(Facing:Vector,_f3)>0.999
{
RGUI_SetText(_26:fr,round(vdot(Facing:Vector,_f3),3),RGUI_ColourNormal).
wait 0.
}
set Ship:Control:Fore to 1.
until abs(vdot(_31:Position:Normalized,_f2))<1e-4 or vdot(Facing:Vector,_f3)<0.995
{
RGUI_SetText(_26:dist,round(vdot(_31:Position:Normalized,_f2),6),RGUI_ColourNormal).
RGUI_SetText(_26:fr,round(vdot(Facing:Vector,_f3),3),RGUI_ColourNormal).
wait 0.
}
unlock steering.
rcs off.
LAS_Avionics("shutdown").
}
}
print"Waiting for gravity to increase to "+round(_32,3)+" m/s for braking".
set kUniverse:Timewarp:Rate to 10.
wait until Body:Mu/LAS_ShipPos():SqrMagnitude>=_32.
}
set kUniverse:Timewarp:Rate to 1.
local _33 is choose-10 if stage:number>_0 else-50.
local _34 is v(0,0,0).
local function _f4
{
parameter _p0.
parameter _p1.
local lock _f5 to round(Ship:Velocity:Surface:Mag*_1).
local alt is Ship:Altitude.
until alt<_f5-Ship:VerticalSpeed*0.5
{
local _35 is Time:Seconds.
local _36 is _f1(_33,_p0).
local _37 is Body:GeoPositionOf(_36+Body:Position).
set alt to _36:Mag-Body:Radius-_37:TerrainHeight.
RGUI_SetText(_26:height,round(alt*0.001,1)+" km",RGUI_ColourNormal).
RGUI_SetText(_26:acgx,round(_f5*0.001,1)+" km",RGUI_ColourNormal).
if _31:IsType("GeoCoordinates")
{
local _38 is vang(vxcl(up:vector,_31:Position),vxcl(up:vector,Ship:Velocity:Surface)).
RGUI_SetText(_26:dist,round(_31:Distance*0.001,1)+" km",RGUI_ColourNormal).
RGUI_SetText(_26:bearing,round(_38,3)+"°",RGUI_ColourNormal).
}
local _39 is alt<_f5-Ship:VerticalSpeed*8.
if _39
{
if kUniverse:Timewarp:Rate<>1
set kUniverse:Timewarp:Rate to 1.
wait until Time:Seconds>=_35+0.2.
}
else
{
if not rcs and kUniverse:Timewarp:Rate<>10
set kUniverse:Timewarp:Rate to 10.
wait until Time:Seconds>=_35+1.
}
_p1(_39).
set _34 to _37.
}
}
RGUI_SetText(_26:status,"Wait Align",RGUI_ColourNormal).
_f4(choose 90 if _9 else 60,{parameter c.}).
set kUniverse:Timewarp:Rate to 1.
wait until kUniverse:Timewarp:Rate=1.
print"Aligning for burn".
RGUI_SetText(_26:status,"Aligning",RGUI_ColourNormal).
LAS_Avionics("activate").
rcs on.
if _9
{
local _40 is constant:e^(Velocity:Surface:Mag*_6/_5).
local _41 is _7/_40.
local _42 is(_7-_41)/_6.
set _8 to Ship:VerticalSpeed/(Ship:VerticalSpeed+_42*0.8*(Body:Mu/LAS_ShipPos():SqrMagnitude)).
}
lock steering to LookDirUp(_f0(),Facing:UpVector).
set navmode to"surface".
RGUI_SetText(_26:status,"Wait Ignition",RGUI_ColourNormal).
_f4(EM_IgDelay(),RC@).
print"Beginning braking burn".
RGUI_SetText(_26:status,"Braking",RGUI_ColourNormal).
RGUI_SetText(_26:throt,"100%",RGUI_ColourNormal).
until _4[0]:Ignitions=0 or EM_CheckThrust(0.1)
EM_Ignition(0.1).
if _10:Count<=1
set ship:control:roll to 0.
else
set ship:control:roll to-0.001.
if _9
{
wait until Stage:Ready.
stage.
set Ship:Control:Neutralize to true.
unlock steering.
}
if _31:IsType("GeoCoordinates")
{
local _43 is vdot(_31:Position-_34:Position,vxcl(Up:Vector,Ship:Velocity:Surface):Normalized).
set _8 to 1+max(-0.02,min((_43-2500)/20000,0.02)).
}
local _44 is _10:Count>0.
until(Ship:VerticalSpeed>=_33 and Ship:Velocity:Surface:Mag<-_33)or not EM_CheckThrust(0.1)
{
local t is Ship:Velocity:Surface:Mag*Ship:Mass/_5.
if _31:IsType("GeoCoordinates")
{
local _45 is vang(vxcl(up:vector,_31:Position),vxcl(up:vector,Ship:Velocity:Surface)).
RGUI_SetText(_26:dist,round(_31:Distance*0.001,1)+" km",RGUI_ColourNormal).
RGUI_SetText(_26:bearing,round(_45,3)+"°",RGUI_ColourNormal).
if t<100
{
local _46 is 1-vdot(Up:Vector,Ship:Velocity:Surface:Normalized)^2.
local _47 is _46*_5/Ship:Mass.
local _48 is Ship:GroundSpeed*t-0.5*_47*t^2.
local _49 is _31:Distance-(_46*-_33*30+_48).
if t<=60 and abs(_45)<2
{
set _8 to 1+max(-0.1,min((_49-1500)/10000,0.1)).
}
}
}
local h is Ship:Altitude-Ship:GeoPosition:TerrainHeight.
local _50 is-(_33^2-Ship:VerticalSpeed^2)/(2*h).
local fr is(_50+Body:Mu/Body:Position:SqrMagnitude)*Ship:Mass/_5.
RGUI_SetText(_26:height,round(h)+" m",RGUI_ColourNormal).
RGUI_SetText(_26:acgx,round(_50,3),RGUI_ColourNormal).
RGUI_SetText(_26:fr,round(fr,3),RGUI_ColourNormal).
local _51 is Ship:AvailableThrust.
RGUI_SetText(_26:thrust,round(100*min(Ship:Thrust/max(Ship:AvailableThrust,0.001),2),2)+"%",
choose RGUI_ColourGood if Ship:Thrust>_51*0.75 else(choose RGUI_ColourNormal if Ship:Thrust>_51*0.25 else RGUI_ColourFault)).
RGUI_SetText(_26:eta,round(t,2)+" s",RGUI_ColourNormal).
if _9 and vdot(Facing:Vector,SrfRetrograde:Vector)<0.3
break.
if stage:number=_0 and fr<0.8 and Ship:VerticalSpeed>=_33*2
break.
wait 0.
if _44 and((Velocity:Surface:Mag<_10:DeltaV-_33)or not EM_CheckThrust(0.1))
{
print"Firing solid stage".
EM_Cutoff().
Stage.
wait until stage:ready.
EM_ResetEngines(Stage:Number).
set _44 to false.
}
}
if stage:number>_0
{
set Ship:Control:PilotMainThrottle to 0.
set ship:control:roll to 0.
wait until(Ship:VerticalSpeed<=_33*2).
stage.
}
}
else
{
LanderSelectWP(_3).
LAS_Avionics("activate").
rcs on.
}
if abs(vdot(Facing:Vector,Ship:AngularVel))>0.2
{
set ship:control:roll to choose 1 if vdot(Facing:Vector,Ship:AngularVel)>0 else-1.
wait abs(vdot(Facing:Vector,Ship:AngularVel))<0.2.
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
runpath("/lander/finaldescent",_4,_26,LanderTargetPos()).
}
