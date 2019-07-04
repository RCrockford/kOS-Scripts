@lazyglobal off.
wait until Ship:Unpacked.
local lock _f0 to mod(360-latlng(90,0):bearing,360).
local function _f1
{
local raw is vang(Ship:up:vector,-Ship:facing:starvector).
if vang(Ship:up:vector,Ship:facing:topvector)>90{
if raw>90{
return raw-270.
}else{
return raw+90.
}
}else{
return 90-raw.
}
}
local lock _f2 to 90-vang(Ship:up:vector,Ship:facing:forevector).
local function _f3
{
parameter a1,a2.
local _0 is a2-a1.
if _0<-180{
set _0 to _0+360.
}else if _0>180{
set _0 to _0-360.
}
return _0.
}
local _1 is 0.
local function _f4
{
local dir is vxcl(Ship:Up:Vector,_1+Ship:Body:Position).
local ang is vang(dir,Ship:North:Vector).
if vdot(dir,vcrs(Ship:North:Vector,Ship:Up:Vector))>0
set ang to 360-ang.
return ang.
}
local function _f5
{
return(_1+Ship:Body:Position):Mag.
}
local function _f6
{
return vdot(_1+Ship:Body:Position,Ship:Up:Vector)/(_f5()/Ship:AirSpeed).
}
local _2 is 0.
local _3 is list().
for p in Ship:parts
{
if p:HasModule("FARControllableSurface")
{
local _4 is p:GetModule("FARControllableSurface").
if _4:HasAction("increase flap deflection")and _4:HasAction("decrease flap deflection")
{
_3:add(_4).
}
}
}
local function _f7
{
parameter _p0.
until _2=_p0
{
if _2<_p0
{
for f in _3
f:DoAction("increase flap deflection",true).
set _2 to _2+1.
}
else
{
for f in _3
f:DoAction("decrease flap deflection",true).
set _2 to _2-1.
}
}
if not _3:Empty
print"Flaps "+_2.
}
local _5 is 50.
local _6 is 150.
local _7 is round(_f0,0).
local _8 is 0.
local _9 is 80.
local _10 is 80.
local _11 is 1.
local _12 is 0.5.
local _13 is 0.1.
local _14 is 0.8.
local _15 is PIDloop(0.02,0.001,0.02,-1,1).
local _16 is PIDloop(0.005,0.00005,0.001,-1,1).
local _17 is PIDloop(0.1,0.005,0.03,-1,1).
local _18 is PIDloop(0.1,0.001,0.05,0,1).
local _19 is PIDloop(3,0.0,5,-45,45).
local _20 is pidloop(0.5,0.01,0.1,-40,40).
local _21 is pidloop(0.25,0.01,0.2).
local _22 is PIDLoop(0.15,0,0.1,-1,1).
local _23 is Gui(300).
set _23:X to 100.
set _23:Y to _23:Y+50.
local _24 is _23:AddHBox().
local _25 is _24:AddVBox().
set _25:style:width to 150.
local _26 is _24:AddVBox().
set _26:style:width to 100.
local _27 is _24:AddVBox().
set _27:style:width to 50.
local _28 is list().
local _29 is lexicon().
local function _f8
{
parameter _p0.
parameter _p1.
parameter _p2.
parameter _p3.
parameter _p4.
local _30 is _25:AddLabel(_p1).
set _30:Style:Height to 25.
_28:add(_30).
set _30 to _26:AddTextField(_p2:ToString).
set _30:Style:Height to 25.
set _30:OnConfirm to _p3.
_28:add(_30).
if _p4:Length>0
set _30 to _27:AddButton(_p4).
else
set _30 to _27:AddCheckBox(_p4,true).
set _30:Style:Height to 25.
_29:add(_p0,_30).
}
_f8("hdg","Heading",_7,{parameter s.set _7 to s:ToNumber(_7).},"").
_f8("spd","Airspeed",_6,{parameter s.set _6 to s:ToNumber(_6).},"").
_f8("fl","Flight Level",_5,{parameter s.set _5 to s:ToNumber(_5).},"").
_f8("cr","Climb Rate",_8,{parameter s.set _8 to s:ToNumber(_8).},"").
_f8("sns1","Ctrl Sensitivity",_11,{parameter s.set _11 to s:ToNumber(_11).},"").
_f8("sns2","Climb kP",climbSense,{parameter s.set _12 to s:ToNumber(_12).},"").
_f8("sns3","Climb kI",climbSense,{parameter s.set _13 to s:ToNumber(_13).},"").
_f8("sns4","Climb kD",climbSense,{parameter s.set _14 to s:ToNumber(_14).},"").
set _29["cr"]:Pressed to false.
set _29["fl"]:OnToggle to{parameter val.if val{_21:Reset().set _29["cr"]:Pressed to false.}}.
set _29["cr"]:OnToggle to{parameter val.if val set _29["fl"]:Pressed to false.}.
_f8("to","Rotate Speed",_9,{parameter s.set _9 to s:ToNumber(_9).},"TO").
_f8("lnd","Landing Speed",_10,{parameter s.set _10 to s:ToNumber(_10).},"Land").
local _31 is _23:AddButton("Exit").
local _32 is round(_f0,1).
local _33 is 0.
local _34 is 0.
local _35 is 0.
local _36 is 0.
local _37 is Time:Seconds.
local _38 is 0.
local _39 is 1.
local _40 is 10.
local _41 is 20.
local _42 is 21.
local _43 is 22.
local _44 is 23.
local _45 is 24.
local _46 is 25.
local _47 is _40.
local _48 is V(0,0,0).
local _49 is V(0,0,0).
local _50 is-1.
local _51 is V(0,0,0).
if Ship:status="PreLaunch"or Ship:status="Landed"
{
Core:Part:GetModule("kOSProcessor"):DoEvent("Open Terminal").
set _47 to _38.
set _29["to"]:Enabled to true.
set _29["lnd"]:Enabled to false.
set _50 to round(_f0,1).
set _48 to-Ship:Body:Position+Heading(_f0,0):Vector*200.
set _49 to _48+Heading(_f0,0):Vector*2200.
print"Takeoff from runway "+round(_50/10,0).
}
_23:Show().
until _31:TakePress
{
if _47<>_38
{
local _52 is-1e8.
local _53 is _f2.
local _54 is _f0.
local _55 is true.
local _56 is 0.
if _47=_39
{
if Ship:GroundSpeed>=_9 or Ship:Status="Flying"
{
set _53 to 10.
}
if _53>0 and Ship:Status="Flying"and _33=0
{
set _33 to Ship:AirSpeed.
print"Stall speed set to "+round(_33,1).
set Ship:Control:WheelSteer to 0.
set Ship:Control:Yaw to 0.
}
else if Ship:Status="Landed"
{
set _33 to 0.
}
set _54 to _32.
set Ship:Control:PilotMainThrottle to 1.
if Alt:Radar>250
{
_f7(0).
set _47 to _40.
set _29["lnd"]:Enabled to true.
}
if _53=0 and abs(_f3(_32,_f0))>5
{
print"Veering off course too far, check wheel steering. Takeoff aborted.".
brakes on.
set Ship:Control:PilotMainThrottle to 0.
set _47 to _45.
set _29["to"]:Enabled to true.
}
}
else if _47=_40
{
if _29["fl"]:Pressed or _29["cr"]:Pressed or _29["hdg"]:Pressed
{
if _29["fl"]:Pressed
{
local _57 is _5*100-Ship:Altitude.
set _52 to max(-Ship:Airspeed*0.25,min(Ship:Airspeed*0.25,15*_57/Ship:Airspeed)).
if abs(_52)>Ship:Airspeed*0.2
{
set _21:MinOutput to-_52.
set _21:MaxOutput to _52.
local _58 is _33*1.5.
if _29["spd"]:Pressed
set _58 to _6.
set _52 to _52+_21:Update(Time:Seconds,_58-Ship:AirSpeed).
}
}
else if _29["cr"]:Pressed
{
set _52 to _8.
}
if _29["hdg"]:pressed
{
set _54 to _7.
}
}
else
{
set _55 to false.
}
if _29["spd"]:Pressed
{
if not _29["fl"]:Pressed or _5*100<Ship:Altitude+max(Ship:VerticalSpeed*5,50)
{
set _56 to _6.
}
else
{
set Ship:Control:PilotMainThrottle to 1.
}
}
if _29["lnd"]:TakePress
{
if _50>=0
{
if(-Ship:Body:Position-_48):SqrMagnitude<(-Ship:Body:Position-_49):SqrMagnitude
{
set _51 to _48.
set _32 to _50.
}
else
{
set _51 to _49.
set _32 to mod(_50+180,360).
}
print"Landing at runway "+round(_32/10,0).
set _1 to _51-heading(_32,0):Vector*12000+Ship:Up:Vector*1000.
set _47 to _41.
set _29["lnd"]:Enabled to false.
}
else
{
set _47 to _46.
print"Manual landing assistance active".
when alt:radar<200 then{gear on.lights on.}
}
}
}
else if _47=_41
{
set _52 to _f6().
set _54 to _f4().
set _56 to(1.5+_f5()/10000)*_10.
local _59 is 1.5*_10.
set _56 to max(_59,min(Ship:Airspeed,_56)).
if _f5()<250
{
if abs(_f3(_32,_f0))<=30 and Ship:AirSpeed<_56*1.2
{
set _47 to _43.
set _1 to _51-heading(_32,0):Vector*4000+Ship:Up:Vector*300.
_f7(2).
print"On approach".
}
else
{
set _47 to _42.
}
}
}
else if _47=_42
{
set _52 to 0.
set _56 to 1.5*_10.
if _f5()<2500
{
set _54 to mod(_32+135,360).
local _60 is mod(_32+225,360).
if abs(_f3(_60,_f0))<abs(_f3(_54,_f0))
set _54 to _60.
}
else
{
set _54 to mod(_32+180,360).
if _f5()>5000
{
set _47 to _41.
}
}
}
else if _47=_43
{
set _52 to _f6().
set _54 to _f4().
set _56 to min((1+_f5()/16000),1.5)*_10.
if _f5()<50
{
set _47 to _44.
set _1 to _51+Ship:Up:Vector*50.
_f7(3).
gear on.
lights on.
print"Final approach".
}
}
else if _47=_44
{
set _54 to _f4().
set _56 to _10.
if Alt:radar<30 or abs(_f3(_54,_32))>=1
{
set _52 to-2.
set _54 to _32.
}
else
{
set _52 to _f6().
}
if Alt:Radar<10
{
set _52 to-0.5.
}
if Ship:Status="Landed"
{
brakes on.
print"Braking".
set _47 to _45.
}
else if abs(_f3(_f0,_54))>=10
{
print"Aborting landing".
set Ship:Control:PilotMainThrottle to 1.
set _56 to 0.
set _52 to-1e8.
set _53 to 10.
set _54 to _f0.
set _32 to _f0.
set _47 to _39.
}
}
else if _47=_45
{
set Ship:Control:PilotMainThrottle to 0.
set _54 to _32.
if Ship:GroundSpeed<1
{
_f7(0).
set _47 to _38.
}
}
else if _47=_46
{
set _55 to false.
if Ship:Status="Landed"
{
brakes on.
set _32 to _f0.
print"Braking".
set _47 to _45.
}
else if _29["lnd"]:TakePress
{
print"Landing assistance cancelled".
set _47 to _40.
}
}
if _55
{
if _52>0
set _52 to max(min(_52,Ship:Airspeed-_33),0).
local _61 is 120/max(Ship:AirSpeed,80).
if _52>-1e6
{
print"reqClimbRate="+round(_52,1)+" / "+round(ship:verticalspeed,1)+" "at(0,0).
set _20:kP to _12*_61.
set _20:kI to _13*_61.
set _20:kD to _14.
set _20:SetPoint to _52.
set _53 to _20:Update(time:seconds,Ship:verticalspeed).
}
set _61 to _61*max(0.1,min(_11,10)).
set _15:kP to 0.06*_61.
set _15:kI to 0.002*_61.
set _15:kD to 0.04*_61.
set _15:SetPoint to _53.
set ship:control:pitch to _15:update(time:seconds,_f2).
print"reqPitch="+round(_53,2)+" / "+round(_f2,2)+" "at(0,1).
local _62 is 0.
if abs(_52-ship:verticalspeed)<50 and alt:radar>10
{
set _19:SetPoint to-_f3(_54,_f0).
if _19:SetPoint<-175
set _19:SetPoint to 180.
set _62 to _19:Update(time:seconds,0).
}
else
{
_19:Reset().
}
set _16:kP to 0.005*_61.
set _16:kI to 0.00005*_61.
set _16:kD to 0.001*_61.
set _16:SetPoint to _62.
set ship:control:roll to _16:Update(time:seconds,_f1()).
}
else
{
set Ship:Control:Neutralize to true.
aoaPid:Reset().
_15:Reset().
_16:Reset().
}
if _56>0
{
set _18:SetPoint to _56.
set Ship:Control:PilotMainThrottle to _34*_35+_18:Update(time:seconds,Ship:AirSpeed)*(1-_34).
set _34 to max(0,_34-0.05).
}
else
{
set _34 to 1.
set _35 to Ship:Control:PilotMainThrottle.
_18:Reset().
}
if Ship:Status="Landed"
{
local _63 is _f3(_32,_f0).
set _22:kP to 0.018/max(1,Ship:GroundSpeed/10).
set _22:kD to _22:kP*2/3.
set Ship:Control:WheelSteer to _22:update(time:seconds,_63).
set Ship:Control:Yaw to _17:Update(time:seconds,_63).
}
else
{
_22:Reset().
}
if _55 and(abs(Ship:Control:PilotYaw)>0.8 or abs(Ship:Control:PilotPitch)>0.8 or abs(Ship:Control:PilotRoll)>0.8)
{
set _29["fl"]:Pressed to false.
set _29["cr"]:Pressed to false.
set _29["hdg"]:Pressed to false.
set _29["spd"]:Pressed to false.
set _47 to _40.
set Ship:Control:PilotMainThrottle to 1.
print"Autopilot disengaged.".
set _29["lnd"]:Enabled to true.
}
}
else if _29["to"]:TakePress
{
set _47 to _39.
set _29["to"]:Enabled to false.
set _32 to round(_f0,1).
if Ship:Status="PreLaunch"
{
print"Engine start.".
stage.
}
set Ship:Control:PilotMainThrottle to 1.
_f7(2).
if brakes
{
print"Waiting for engines to spool.".
local _64 is list().
list engines in _64.
local _65 is 0.
for eng in _64
{
set _65 to _65+eng:PossibleThrust().
}
local _66 is 0.
until _66>_65*0.5
{
set _66 to 0.
for eng in _64
{
set _66 to _66+eng:Thrust().
}
wait 0.
}
brakes off.
}
print"Beginning takeoff roll.".
when alt:radar>=50 then{gear off.lights off._f7(1).}
}
wait 0.
}
ClearGuis().
set Ship:Control:Neutralize to true.
