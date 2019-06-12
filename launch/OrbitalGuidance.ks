@lazyglobal off.
local rT is 0.
local rvT is 0.
local hT is 0.
local _0 is 0.
local ET is 0.
local _1 is list().
local _2 is list().
local _3 is list().
local _4 is list().
local _5 is list().
local _6 is list().
local _7 is-1.
local _8 is-1.
local _9 is 0.
local _10 is 0.
{
local _11 is 180000.
local _12 is 180000.
if defined LAS_TargetPe
set _11 to LAS_TargetPe.
if defined LAS_TargetAp
set _12 to LAS_TargetAp.
if defined LAS_LastStage
set _7 to LAS_LastStage.
if _11<100000
{
print"Suborbital flight, no orbital guidance.".
}
else
{
print"Target Orbit: Pe="+round(_11*0.001,1)+" km, Ap="+round(_12*0.001,1)+" km".
set _11 to _11+Ship:Body:Radius.
set _12 to _12+Ship:Body:Radius.
local a is(_12+_11)/2.
local e is 1-_11/a.
local L is a*(1-e*e).
set rT to _11.
set rvT to 0.
set hT to sqrt(Ship:Body:Mu*L).
set _0 to hT/(_11*_11).
set ET to-Ship:Body:Mu/(2*a).
local _13 is list().
list engines in _13.
from{local s is Stage:Number.}until s<0 step{set s to s-1.}do
{
_1:add(0).
_2:add(0).
_3:add(0).
_4:add(0).
_5:add(0).
_6:add(0).
}
from{local s is Stage:Number.}until s<0 step{set s to s-1.}do
{
local _14 is Ship:RootPart.
local _15 is 0.
local _16 is 0.
local _17 is 0.
local _18 is-1.
for eng in _13
{
if eng:Stage=s and not eng:Title:Contains("Separation")and not eng:Tag:Contains("ullage")
{
set _15 to _15+eng:PossibleThrustAt(0)/(Constant:g0*eng:VacuumIsp).
set _16 to _16+eng:VacuumIsp.
set _17 to _17+1.
set _18 to max(_18,LAS_GetEngineBurnTime(eng)).
set _14 to eng:Decoupler.
}
}
if not _14:IsType("Decoupler")
set _14 to Ship:RootPart.
local _19 is 0.
local _20 is 0.
for shipPart in Ship:Parts
{
if not shipPart:HasModule("LaunchClamp")
{
if shipPart:DecoupledIn<s and shipPart:DecoupledIn>=_14:stage
{
set _19 to _19+shipPart:WetMass.
set _20 to _20+shipPart:DryMass.
}
else if shipPart:DecoupledIn<_14:stage
{
set _19 to _19+shipPart:WetMass.
set _20 to _20+shipPart:WetMass.
}
}
}
if _16>0 and _15>0
{
set _16 to _16/max(_17,1).
if _18>0
{
set _3[s]to _18.
}
else
{
set _3[s]to(_19-_20)/_15.
}
set _5[s]to Constant:g0*_16.
set _6[s]to _15*Constant:g0*_16/max(_19,1e-6).
print"Guidance for stage "+s+": T="+round(_3[s],2)+" Ev="+round(_5[s],1)+" a="+round(_6[s],2).
}
}
}
}
local function _f0
{
local s is max(Stage:Number,_7).
if _3[s]<10
{
return.
}
local r is LAS_ShipPos():Mag.
local r2 is LAS_ShipPos():SqrMagnitude.
local rv is vdot(Ship:Velocity:Orbit,LAS_ShipPos():Normalized).
local h is vcrs(LAS_ShipPos(),Ship:Velocity:Orbit):Mag.
local _21 is vcrs(LAS_ShipPos(),Ship:Velocity:Orbit):Normalized.
local _22 is h/r2.
local _23 is MissionTime-_9.
local _24 is LAS_GetStageEngines().
local _25 is 0.
local _26 is 0.
local _27 is 0.
local _28 is 0.
for eng in _24
{
if eng:Thrust>0 and not eng:Title:Contains("Separation")and not eng:Tag:Contains("ullage")
{
set _25 to _25+eng:Isp.
set _26 to _26+eng:Thrust.
set _27 to _27+eng:PossibleThrust.
set _28 to _28+1.
}
}
if _28<1 or _26<_27*0.4 or _25<1e-4
{
return.
}
set _25 to _25/_28.
local _29 is Constant:g0*_25.
local _30 is _26/Ship:Mass.
local tau is _29/_30.
local _31 is max(_8,_7+1).
until s<_31
{
local _32 is s-1.
until _5[_32]>0
set _32 to _32-1.
set _1[s]to _1[s]+_2[s]*_23.
set _3[s]to max(_3[s]-_23,1).
local T is min(_3[s],tau-1).
local _33 is _30/(1-T/tau).
local b0 is-_29*ln(1-T/tau).
local b1 is b0*tau-_29*T.
local c0 is b0*T-b1.
local c1 is c0*tau-_29*(T*T)*0.5.
local rS is r+rv*T+c0*_1[s]+c1*_2[s].
local rvS is rv+b0*_1[s]+b1*_2[s].
local _34 is _4[s].
local fr is _1[s]+(Ship:Body:Mu/r2-(_22*_22)*r)/_30.
local frS is _1[s]+_2[s]*T+(Ship:Body:Mu/(rS*rS)-(_34*_34)*rS)/_33.
local fdr is(frS-fr)/T.
local _35 is 1-(fr*fr)*0.5.
local _36 is-(fr*fdr).
local _37 is-0.5*((fdr*fdr)).
local b2 is b1*tau-_29*(T*T)*0.5.
local hS is h+(r+rS)*0.5*(_35*b0+_36*b1+_37*b2).
set _34 to hS/(rS*rS).
set _4[s]to _34.
local x is Ship:Body:Mu/(rS*rS)-(_34*_34)*rS.
local y is 1/_33-1/_6[_32].
local _38 is x*y.
local _39 is-x*(1/_29-1/_5[_32])+(3*(_34*_34)-2*Ship:Body:Mu/(rS^3))*rvS*y.
set _29 to _5[_32].
set _30 to _6[_32].
set tau to _29/_30.
local T2 is min(_3[_32],tau-1).
set _33 to _30/(1-T2/tau).
local nb0 is-_29*ln(1-T2/tau).
local nb1 is nb0*tau-_29*T2.
local nc0 is nb0*T2-nb1.
local nc1 is nc0*tau-_29*(T2*T2)*0.5.
local rS2 is rT.
local _40 is rvT.
if _32>_7
{
set rS2 to rS+rvS*T2+nc0*_1[_32]+nc1*_2[_32].
set _40 to rvS+nb0*_1[_32]+nb1*_2[_32].
}
local M00 is b0+nb0.
local M01 is b1+nb1+nb0*T.
local M10 is c0+nc0+b0*T2.
local M11 is c1+b1*T2+nc0*T+nc1.
local Mx is _40-rv-nb0*_38-nb1*_39.
local My is rS2-r-rv*(T+T2)-nc0*_38-nc1*_39.
local det is M00*M11-M01*M10.
if(abs(det)>1e-7)
{
set _1[s]to(M11*Mx-M01*My)/det.
set _2[s]to(M00*My-M10*Mx)/det.
}
set _1[_32]to _38+_1[s]+_2[s]*T.
set _2[_32]to _39+_2[s].
set s to _32.
set r to rS.
set r2 to rS*rS.
set rv to rvS.
set h to hS.
set _22 to _34.
set _23 to 0.
}
if s=_7
{
set _1[s]to _1[s]+_2[s]*_23.
set _3[s]to _3[s]-_23.
local T is min(_3[s],tau-1).
local _41 is _30/(1-T/tau).
local fr is _1[s]+(Ship:Body:Mu/r2-(_22*_22)*r)/_30.
local frT is _1[s]+_2[s]*T+(Ship:Body:Mu/(rT*rT)-(_0*_0)*rT)/_41.
local fdr is(frT-fr)/T.
local _42 is 1-(fr*fr)*0.5.
local _43 is-(fr*fdr).
local _44 is-0.5*((fdr*fdr)).
local dh is hT-h.
local _45 is(r+rT)*0.5.
local _46 is dh/_45.
set _46 to _46+_29*T*(_43+_44*tau).
set _46 to _46+_44*_29*(T*T)*0.5.
set _46 to _46/(_42+(_43+_44*tau)*tau).
set T to tau*(1-constant:e^(-_46/_29)).
set _3[s]to T.
local b0 is _46.
local b1 is b0*tau-_29*T.
local c0 is b0*T-b1.
local c1 is c0*tau-_29*(T*T)*0.5.
local Mx is rvT-rv.
local My is rT-r-rv*T.
local det is b0*c1-b1*c0.
if(abs(det)>1e-7)
{
set _1[s]to(c1*Mx-b1*My)/det.
set _2[s]to(b0*My-c0*Mx)/det.
}
set _9 to MissionTime.
}
}
global function LAS_GetGuidanceAim
{
if rT<=0
return V(0,0,0).
local s is Stage:Number.
local t is MissionTime-_9.
local r is LAS_ShipPos():Mag.
local r2 is LAS_ShipPos():SqrMagnitude.
local _47 is vcrs(vcrs(LAS_ShipPos(),Ship:Velocity:Orbit):Normalized,LAS_ShipPos():Normalized).
local _48 is vdot(Ship:Velocity:Orbit,_47)/r.
local _49 is LAS_GetStageEngines().
local _50 is 0.
for eng in _49
{
if eng:Thrust>0 and not eng:Title:Contains("Separation")and not eng:Tag:Contains("ullage")
{
set _50 to _50+eng:Thrust.
}
}
local _51 is _50/Ship:Mass.
if _50>1e-3
{
local fr is _1[s]+_2[s]*t.
set fr to fr+(Ship:Body:Mu/r2-(_48*_48)*r)/_51.
if abs(fr)<0.999
{
return fr*LAS_ShipPos():Normalized+sqrt(1-fr*fr)*_47.
}
}
return V(0,0,0).
}
global function LAS_StartGuidance
{
if rT<=0
return.
set _3[Stage:Number]to LAS_GetStageBurnTime().
set _10 to Ship:Velocity:Orbit:sqrMagnitude/2-Ship:Body:Mu/LAS_ShipPos():Mag.
if _7<0
{
local r is LAS_ShipPos():Mag.
local h is vcrs(LAS_ShipPos(),Ship:Velocity:Orbit):Mag.
local _52 is(hT-h)*2.2/(rT+r).
local _53 is 0.
from{local i is Stage:Number.}until i<0 step{set i to i-1.}do
{
if _5[i]>0
{
set _53 to _53-_5[i]*ln(1-_3[i]*_6[i]/_5[i]).
set _7 to i.
if _53>=_52
break.
}
}
print"Last guidance stage: "+_7.
}
set _8 to Stage:Number.
local _54 is 0.
until _8<_7
{
local A is _1[_8].
set _9 to MissionTime.
_f0().
if abs(_1[_8]-A)<0.01
set _8 to _8-1.
set _54 to _54+1.
if _54>30
break.
}
if _8<_7
print"Guidance converged successfully.".
else
print"Guidance failed to converge.".
}
global function LAS_GuidanceUpdate
{
if rT<=0
return.
if MissionTime-_9<0.98
return.
_f0().
}
global function LAS_GuidanceCutOff
{
if rT<=0
return false.
local _55 is _10.
set _10 to Ship:Velocity:Orbit:sqrMagnitude/2-Ship:Body:Mu/LAS_ShipPos():Mag.
return _10+(_10-_55)*0.5>=ET.
}
