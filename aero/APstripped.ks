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
local _11 is PIDloop(0.02,0.001,0.02,-1,1).
local _12 is PIDloop(0.005,0.00005,0.001,-1,1).
local _13 is PIDloop(0.1,0.005,0.03,-1,1).
local _14 is PIDloop(3,0.0,5,-45,45).
local _15 is PIDloop(0.1,0.001,0.05,0,1).
local _16 is pidloop(0.25,0.01,0.2).
local _17 is PIDLoop(0.15,0,0.1,-1,1).
local _18 is Gui(300).
set _18:X to 100.
set _18:Y to _18:Y+50.
local _19 is _18:AddHBox().
local _20 is _19:AddVBox().
set _20:style:width to 150.
local _21 is _19:AddVBox().
set _21:style:width to 100.
local _22 is _19:AddVBox().
set _22:style:width to 50.
local _23 is list().
local _24 is lexicon().
local function _f8
{
parameter _p0.
parameter _p1.
parameter _p2.
parameter _p3.
parameter _p4.
local _25 is _20:AddLabel(_p1).
set _25:Style:Height to 25.
_23:add(_25).
set _25 to _21:AddTextField(_p2:ToString).
set _25:Style:Height to 25.
set _25:OnConfirm to _p3.
_23:add(_25).
if _p4:Length>0
set _25 to _22:AddButton(_p4).
else
set _25 to _22:AddCheckBox(_p4,true).
set _25:Style:Height to 25.
_24:add(_p0,_25).
}
_f8("hdg","Heading",_7,{parameter s.set _7 to s:ToNumber(_7).},"").
_f8("spd","Airspeed",_6,{parameter s.set _6 to s:ToNumber(_6).},"").
_f8("fl","Flight Level",_5,{parameter s.set _5 to s:ToNumber(_5).},"").
_f8("cr","Climb Rate",_8,{parameter s.set _8 to s:ToNumber(_8).},"").
set _24["cr"]:Pressed to false.
set _24["fl"]:OnToggle to{parameter val.if val{_16:Reset().set _24["cr"]:Pressed to false.}}.
set _24["cr"]:OnToggle to{parameter val.if val set _24["fl"]:Pressed to false.}.
_f8("to","Rotate Speed",_9,{parameter s.set _9 to s:ToNumber(_9).},"TO").
_f8("lnd","Landing Speed",_10,{parameter s.set _10 to s:ToNumber(_10).},"Land").
local _26 is _18:AddButton("Exit").
local _27 is round(_f0,1).
local _28 is 0.
local _29 is 0.
local _30 is 0.
local _31 is 0.
local _32 is Time:Seconds.
local _33 is 0.
local _34 is 1.
local _35 is 10.
local _36 is 20.
local _37 is 21.
local _38 is 22.
local _39 is 23.
local _40 is 24.
local _41 is 25.
local _42 is _35.
local _43 is V(0,0,0).
local _44 is V(0,0,0).
local _45 is-1.
local _46 is V(0,0,0).
if Ship:status="PreLaunch"or Ship:status="Landed"
{
Core:Part:GetModule("kOSProcessor"):DoEvent("Open Terminal").
set _42 to _33.
set _24["to"]:Enabled to true.
set _24["lnd"]:Enabled to false.
set _45 to round(_f0,1).
set _43 to-Ship:Body:Position+Heading(_f0,0):Vector*200.
set _44 to _43+Heading(_f0,0):Vector*2200.
print"Takeoff from runway "+round(_45/10,0).
}
FlightGui:Show().
until _26:TakePress
{
if _42<>_33
{
local _47 is 0.
local _48 is _f0.
local _49 is true.
local _50 is 0.
if _42=_34
{
if Ship:GroundSpeed>=_9 or Ship:Status="Flying"
{
set _47 to 10.
}
if _47>0 and Ship:Status="Flying"and _28=0
{
set _28 to Ship:AirSpeed.
print"Stall speed set to "+round(_28,1).
set Ship:Control:WheelSteer to 0.
set Ship:Control:Yaw to 0.
}
else if Ship:Status="Landed"
{
set _28 to 0.
}
set _48 to _27.
set Ship:Control:PilotMainThrottle to 1.
if Alt:Radar>250
{
_f7(0).
set _42 to _35.
set _24["lnd"]:Enabled to true.
}
if _47=0 and abs(_f3(_27,_f0))>5
{
print"Veering off course too far, check wheel steering. Takeoff aborted.".
brakes on.
set Ship:Control:PilotMainThrottle to 0.
set _42 to _40.
set _24["to"]:Enabled to true.
}
}
else if _42=_35
{
if _24["fl"]:Pressed or _24["cr"]:Pressed or _24["hdg"]:Pressed
{
if _24["fl"]:Pressed
{
local _51 is targetflightLevel*100-Ship:Altitude.
set _47 to max(-Ship:Airspeed*0.25,min(Ship:Airspeed*0.25,15*_51/Ship:Airspeed)).
if abs(_47)>Ship:Airspeed*0.2
{
set _16:MinOutput to-_47.
set _16:MaxOutput to _47.
local _52 is _28*1.5.
if _24["spd"]:Pressed
set _52 to _6.
set _47 to _47+_16:Update(Time:Seconds,_52-Ship:AirSpeed).
}
}
else if _24["cr"]:Pressed
{
set _47 to _8.
}
if _24["hdg"]:pressed
{
set _48 to _7.
}
}
else
{
set _49 to false.
}
if _24["spd"]:Pressed
{
if not _24["fl"]:Pressed or targetflightLevel*100<Ship:Altitude+max(Ship:VerticalSpeed*5,50)
{
set _50 to _6.
}
else
{
set Ship:Control:PilotMainThrottle to 1.
}
}
if _24["lnd"]:TakePress
{
if _45>=0
{
if(-Ship:Body:Position-_43):SqrMagnitude<(-Ship:Body:Position-_44):SqrMagnitude
{
set _46 to _43.
set _27 to _45.
}
else
{
set _46 to _44.
set _27 to mod(_45+180,360).
}
print"Landing at runway "+round(_27/10,0).
set _1 to _46-heading(_27,0):Vector*12000+Ship:Up:Vector*1000.
set _42 to _36.
set _24["lnd"]:Enabled to false.
}
else
{
set _42 to _41.
print"Manual landing assistance active".
when alt:radar<200 then{gear on.lights on.}
}
}
}
else if _42=_36
{
set _47 to _f6().
set _48 to _f4().
set _50 to(1.5+_f5()/10000)*_10.
local _53 is 1.5*_10.
set _50 to max(_53,min(Ship:Airspeed,_50)).
if _f5()<250
{
if abs(_f3(_27,_f0))<=30 and Ship:AirSpeed<_50*1.2
{
set _42 to _38.
set _1 to _46-heading(_27,0):Vector*4000+Ship:Up:Vector*300.
_f7(2).
print"On approach".
}
else
{
set _42 to _37.
}
}
}
else if _42=_37
{
set _47 to 0.
set _50 to 1.5*_10.
if _f5()<2500
{
set _48 to mod(_27+135,360).
local _54 is mod(_27+225,360).
if abs(_f3(_54,_f0))<abs(_f3(_48,_f0))
set _48 to _54.
}
else
{
set _48 to mod(_27+180,360).
if _f5()>5000
{
set _42 to _36.
}
}
}
else if _42=_38
{
set _47 to _f6().
set _48 to _f4().
set _50 to min((1+_f5()/16000),1.5)*_10.
if _f5()<50
{
set _42 to _39.
set _1 to _46+Ship:Up:Vector*50.
_f7(3).
gear on.
lights on.
print"Final approach".
}
}
else if _42=_39
{
set _48 to _f4().
set _50 to _10.
if Alt:radar<30 or abs(_f3(_48,_27))>=1
{
set _47 to-2.
set _48 to _27.
}
else
{
set _47 to _f6().
}
if Alt:Radar<10
{
set _47 to-0.5.
}
if Ship:Status="Landed"
{
brakes on.
print"Braking".
set _42 to _40.
}
}
else if _42=_40
{
set Ship:Control:PilotMainThrottle to 0.
set _48 to _27.
if Ship:GroundSpeed<1
{
_f7(0).
set _42 to _33.
}
}
else if _42=_41
{
set _49 to false.
if Ship:Status="Landed"
{
brakes on.
set _27 to _f0.
print"Braking".
set _42 to _40.
}
else if _24["lnd"]:TakePress
{
print"Landing assistance cancelled".
set _42 to _35.
}
}
if _49
{
if _47>0
set _47 to max(min(_47,Ship:Airspeed-_28),0).
local _55 is max(time:seconds-_32,0).
set _32 to time:seconds.
local _56 is 120/max(Ship:AirSpeed,80).
if _42=_34
{
if _47>0
{
set _11:kP to 0.04.
set _11:kI to 0.002.
set _11:kD to 0.04.
set _11:SetPoint to _47.
set ship:control:pitch to _11:update(time:seconds,_f2).
}
}
else
{
set _55 to _55*20.
set _47 to max(_31-_55,min(_47,_31+_55)).
if(_f2>40)
set _47 to min(_47,Ship:verticalspeed-_55).
if(_f2<40)
set _47 to max(_47,Ship:verticalspeed+_55).
set _31 to _47.
print"reqClimbRate="+round(_47,1)+" / "+round(ship:verticalspeed,1)+" "at(0,0).
set _11:kP to 0.02*_56.
set _11:kI to 0.0001*_56.
set _11:kD to 0.01*_56.
set _11:SetPoint to _47.
set ship:control:pitch to _11:update(time:seconds,Ship:verticalspeed).
}
local _57 is 0.
if abs(_47-ship:verticalspeed)<50 and alt:radar>10
{
set _14:SetPoint to-_f3(_48,_f0).
if _14:SetPoint<-178
set _14:SetPoint to 180.
set _57 to _14:Update(time:seconds,0).
}
else
{
_14:Reset().
}
set _12:kP to 0.005*_56.
set _12:kI to 0.00005*_56.
set _12:kD to 0.001*_56.
set _12:SetPoint to _57.
set ship:control:roll to _12:Update(time:seconds,_f1()).
}
else
{
set Ship:Control:Neutralize to true.
aoaPid:Reset().
_11:Reset().
_12:Reset().
}
if _50>0
{
set _15:SetPoint to _50.
set Ship:Control:PilotMainThrottle to _29*_30+_15:Update(time:seconds,Ship:AirSpeed)*(1-_29).
set _29 to max(0,_29-0.05).
}
else
{
set _29 to 1.
set _30 to Ship:Control:PilotMainThrottle.
_15:Reset().
}
if Ship:Status="Landed"
{
local _58 is _f3(_27,_f0).
set _17:kP to 0.015/max(1,Ship:GroundSpeed/10).
set _17:kD to _17:kP*2/3.
set Ship:Control:WheelSteer to _17:update(time:seconds,_58).
set Ship:Control:Yaw to _13:Update(time:seconds,_58).
}
else
{
_17:Reset().
}
if _49 and(abs(Ship:Control:PilotYaw)>0.8 or abs(Ship:Control:PilotPitch)>0.8 or abs(Ship:Control:PilotRoll)>0.8)
{
set _24["fl"]:Pressed to false.
set _24["cr"]:Pressed to false.
set _24["hdg"]:Pressed to false.
set _24["spd"]:Pressed to false.
set _42 to _35.
set Ship:Control:PilotMainThrottle to 1.
print"Autopilot disengaged.".
set _24["lnd"]:Enabled to true.
}
}
else if _24["to"]:TakePress
{
set _42 to _34.
set _24["to"]:Enabled to false.
set _27 to round(_f0,1).
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
local _59 is list().
list engines in _59.
local _60 is 0.
for eng in _59
{
set _60 to _60+eng:PossibleThrust().
}
local _61 is 0.
until _61>_60*0.5
{
set _61 to 0.
for eng in _59
{
set _61 to _61+eng:Thrust().
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
