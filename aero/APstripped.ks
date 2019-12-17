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
parameter _p0 is _1.
local dir is vxcl(Ship:Up:Vector,_p0+Ship:Body:Position).
local ang is vang(dir,Ship:North:Vector).
if vdot(dir,vcrs(Ship:North:Vector,Ship:Up:Vector))>0
set ang to 360-ang.
return ang.
}
local function _f5
{
parameter _p0 is _1.
return(_p0+Ship:Body:Position):Mag.
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
local _12 is 1.
local _13 is 0.1.
local _14 is 0.25.
local _15 is PIDloop(0.02,0.001,0.02,-1,1).
local _16 is PIDloop(0.005,0.00005,0.001,-1,1).
local _17 is PIDloop(0.1,0.005,0.03,-1,1).
local _18 is PIDloop(0.1,0.002,0.05,0,1).
local _19 is PIDloop(3,0.0,5,-45,45).
local _20 is pidloop(0.5,0.01,0.1,-40,40).
local _21 is pidloop(0.25,0.01,0.2).
local _22 is PIDLoop(0.15,0,0.1,-1,1).
local _23 is Gui(300).
set _23:X to 200.
set _23:Y to _23:Y+60.
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
local function _f9
{
parameter _p0.
parameter _p1.
parameter _p2.
local _31 is _25:AddLabel(_p1).
set _31:Style:Height to 25.
_28:add(_31).
set _31 to _26:AddTextField(_p2:ToString).
set _31:Style:Height to 25.
set _31:Enabled to false.
_28:add(_31).
_29:add(_p0,_31).
}
_f8("hdg","Heading",_7,{parameter s.set _7 to s:ToNumber(_7).},"").
_f8("spd","Airspeed",_6,{parameter s.set _6 to s:ToNumber(_6).},"").
_f8("fl","Flight Level",_5,{parameter s.set _5 to s:ToNumber(_5).},"").
_f8("cr","Climb Rate",_8,{parameter s.set _8 to s:ToNumber(_8).},"").
_f8("sns1","Ctrl Sensitivity",_11,{parameter s.set _11 to s:ToNumber(_11).},"").
_f8("sns2","Climb kP",_12,{parameter s.set _12 to s:ToNumber(_12).},"").
_f8("sns3","Climb kI",_13,{parameter s.set _13 to s:ToNumber(_13).},"").
_f8("sns4","Climb kD",_14,{parameter s.set _14 to s:ToNumber(_14).},"").
set _29["cr"]:Pressed to false.
set _29["fl"]:OnToggle to{parameter val.if val{_21:Reset().set _29["cr"]:Pressed to false.}}.
set _29["cr"]:OnToggle to{parameter val.if val set _29["fl"]:Pressed to false.}.
_f8("to","Rotate Speed",_9,{parameter s.set _9 to s:ToNumber(_9).},"TO").
_f8("lnd","Landing Speed",_10,{parameter s.set _10 to s:ToNumber(_10).},"Land").
_f9("rwh","Runway Heading","0.0°").
_f9("rwd","Runway Distance","0.0 km").
local _32 is _23:AddButton("Exit").
local _33 is round(_f0,1).
local _34 is 0.
local _35 is 0.
local _36 is 0.
local _37 is 0.
local _38 is Time:Seconds.
local _39 is 0.
local _40 is 1.
local _41 is 10.
local _42 is 20.
local _43 is 21.
local _44 is 22.
local _45 is 23.
local _46 is 24.
local _47 is 25.
local _48 is _41.
local _49 is V(0,0,0).
local _50 is V(0,0,0).
local _51 is V(0,0,0).
local _52 is-1.
local _53 is V(0,0,0).
if Ship:status="PreLaunch"or Ship:status="Landed"
{
Core:Part:GetModule("kOSProcessor"):DoEvent("Open Terminal").
set _48 to _39.
set _29["to"]:Enabled to true.
set _29["lnd"]:Enabled to false.
set _52 to round(_f0,1).
set _49 to-Ship:Body:Position.
set _50 to _49+Heading(_f0,0):Vector*2400.
set Ship:Type to"Plane".
set _51 to(_49+_50)*0.5.
print"Takeoff from runway "+round(_52/10,0).
}
_23:Show().
until _32:TakePress
{
if _48<>_39
{
local _54 is-1e8.
local _55 is _f2.
local _56 is _f0.
local _57 is true.
local _58 is 0.
if _48=_40
{
if Ship:GroundSpeed>=_9 or Ship:Status="Flying"
{
set _55 to 10.
}
if _55>0 and Ship:Status="Flying"and _34=0
{
set _34 to Ship:AirSpeed.
print"Stall speed set to "+round(_34,1).
set Ship:Control:WheelSteer to 0.
set Ship:Control:Yaw to 0.
}
else if Ship:Status="Landed"
{
set _34 to 0.
}
set _56 to _33.
set Ship:Control:PilotMainThrottle to 1.
if Alt:Radar>250
{
_f7(0).
set _48 to _41.
set _29["lnd"]:Enabled to true.
}
if _55=0 and abs(_f3(_33,_f0))>5
{
print"Veering off course too far, check wheel steering. Takeoff aborted.".
brakes on.
set Ship:Control:PilotMainThrottle to 0.
set _48 to _46.
set _29["to"]:Enabled to true.
}
}
else if _48=_41
{
if _29["fl"]:Pressed or _29["cr"]:Pressed or _29["hdg"]:Pressed
{
if _29["fl"]:Pressed
{
local _59 is _5*100-Ship:Altitude.
set _54 to max(-Ship:Airspeed*0.25,min(Ship:Airspeed*0.25,15*_59/Ship:Airspeed)).
if _54>Ship:Airspeed*0.2
{
set _21:MinOutput to-_54.
set _21:MaxOutput to _54.
local _60 is _34*1.5.
if _29["spd"]:Pressed
set _60 to _6.
set _54 to _54+_21:Update(Time:Seconds,_60-Ship:AirSpeed).
}
}
else if _29["cr"]:Pressed
{
set _54 to _8.
}
if _29["hdg"]:pressed
{
set _56 to _7.
}
}
else
{
set _57 to false.
}
if _29["spd"]:Pressed
{
if not _29["fl"]:Pressed or _5*100<Ship:Altitude+max(Ship:VerticalSpeed*5,50)
{
set _58 to _6.
}
else
{
set Ship:Control:PilotMainThrottle to 1.
}
}
if _29["lnd"]:TakePress
{
if _52>=0
{
if(-Ship:Body:Position-_49):SqrMagnitude<(-Ship:Body:Position-_50):SqrMagnitude
{
set _53 to _49.
set _33 to _52.
}
else
{
set _53 to _50.
set _33 to mod(_52+180,360).
}
print"Landing at runway "+round(_33/10,0).
set _1 to _53-heading(_33,0):Vector*12000+Ship:Up:Vector*1000.
set _48 to _42.
set _29["lnd"]:Enabled to false.
}
else
{
set _48 to _47.
print"Manual landing assistance active".
when alt:radar<200 then{gear on.lights on.}
}
}
}
else if _48=_42
{
set _54 to _f6().
set _56 to _f4().
set _58 to(1.5+_f5()/10000)*_10.
local _61 is 1.5*_10.
set _58 to max(_61,min(Ship:Airspeed,_58)).
if _f5()<250
{
if abs(_f3(_33,_f0))<=30 and Ship:AirSpeed<_58*1.2
{
set _48 to _44.
set _1 to _53-heading(_33,0):Vector*4000+Ship:Up:Vector*250.
_f7(2).
print"On approach".
}
else
{
set _48 to _43.
if Ship:AirSpeed>=_58*1.2
print"Turning to reduce speed".
else
print"Turning to correct heading".
}
}
}
else if _48=_43
{
set _54 to(1000-Ship:Altitude)*0.025.
set _58 to 1.5*_10.
if _f5()<2500
{
set _56 to mod(_33+135,360).
local _62 is mod(_33+225,360).
if abs(_f3(_62,_f0))<abs(_f3(_56,_f0))
set _56 to _62.
}
else
{
set _56 to mod(_33+180,360).
if _f5()>5000
{
set _48 to _42.
}
}
}
else if _48=_44
{
set _54 to _f6().
set _56 to _f4().
set _58 to min((1+_f5()/16000),1.5)*_10.
if _f5()<50
{
kUniverse:Timewarp:CancelWarp().
set _48 to _45.
set _1 to _53+Ship:Up:Vector*20.
_f7(3).
gear on.
lights on.
print"Final approach".
}
}
else if _48=_45
{
set _56 to _f4().
set _58 to _10.
if Alt:radar<30 or abs(_f3(_56,_33))>=1
{
set _54 to-2.
set _56 to _33.
}
else
{
set _54 to _f6().
}
if Alt:Radar<10
{
set _54 to-0.5.
}
if Ship:Status="Landed"
{
brakes on.
print"Braking".
set _48 to _46.
}
else if abs(_f3(_f0,_56))>=10
{
print"Aborting landing".
set Ship:Control:PilotMainThrottle to 1.
set _58 to 0.
set _54 to-1e8.
set _55 to 10.
set _56 to _f0.
set _33 to _f0.
set _48 to _40.
}
}
else if _48=_46
{
set Ship:Control:PilotMainThrottle to 0.
set _56 to _33.
if Ship:GroundSpeed<1
{
_f7(0).
set _48 to _39.
}
}
else if _48=_47
{
set _57 to false.
if Ship:Status="Landed"
{
brakes on.
set _33 to _f0.
print"Braking".
set _48 to _46.
}
else if _29["lnd"]:TakePress
{
print"Landing assistance cancelled".
set _48 to _41.
}
}
if _57
{
if _54>0
set _54 to max(min(_54,Ship:Airspeed-_34),0).
local _63 is 120/max(Ship:AirSpeed,80).
if _54>-1e6
{
print"reqClimbRate="+round(_54,1)+" / "+round(ship:verticalspeed,1)+" "at(0,0).
set _20:kP to _12*_63.
set _20:kI to _13*_63.
set _20:kD to _14.
set _20:SetPoint to _54.
set _55 to _20:Update(time:seconds,Ship:verticalspeed).
}
set _63 to _63*max(0.1,min(_11,10)).
set _15:kP to 0.06*_63.
set _15:kI to 0.002*_63.
set _15:kD to 0.04*_63.
set _15:SetPoint to _55.
set ship:control:pitch to _15:update(time:seconds,_f2).
print"reqPitch="+round(_55,2)+" / "+round(_f2,2)+" "at(0,1).
local _64 is 0.
if abs(_54-ship:verticalspeed)<50 and alt:radar>10
{
set _19:SetPoint to-_f3(_56,_f0).
if _19:SetPoint<-175
set _19:SetPoint to 180.
set _64 to _19:Update(time:seconds,0).
}
else
{
_19:Reset().
}
set _16:kP to 0.005*_63.
set _16:kI to 0.00005*_63.
set _16:kD to 0.001*_63.
set _16:SetPoint to _64.
set ship:control:roll to _16:Update(time:seconds,_f1()).
}
else
{
set Ship:Control:Neutralize to true.
aoaPid:Reset().
_15:Reset().
_16:Reset().
}
if _58>0
{
set _18:SetPoint to _58.
set Ship:Control:PilotMainThrottle to _35*_36+_18:Update(time:seconds,Ship:AirSpeed)*(1-_35).
set _35 to max(0,_35-0.05).
}
else
{
set _35 to 1.
set _36 to Ship:Control:PilotMainThrottle.
_18:Reset().
}
if Ship:Status="Landed"
{
local _65 is _f3(_33,_f0).
set _22:kP to 0.018/max(1,Ship:GroundSpeed/10).
set _22:kD to _22:kP*2/3.
set Ship:Control:WheelSteer to _22:update(time:seconds,_65).
set Ship:Control:Yaw to _17:Update(time:seconds,_65).
}
else
{
_22:Reset().
}
if _57 and(abs(Ship:Control:PilotYaw)>0.8 or abs(Ship:Control:PilotPitch)>0.8 or abs(Ship:Control:PilotRoll)>0.8)
{
set _29["fl"]:Pressed to false.
set _29["cr"]:Pressed to false.
set _29["hdg"]:Pressed to false.
set _29["spd"]:Pressed to false.
set _48 to _41.
set Ship:Control:PilotMainThrottle to 1.
print"Autopilot disengaged.".
set _29["lnd"]:Enabled to true.
}
}
else if _29["to"]:TakePress
{
set _48 to _40.
set _29["to"]:Enabled to false.
set _33 to round(_f0,1).
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
local _66 is list().
list engines in _66.
local _67 is 0.
for eng in _66
{
set _67 to _67+eng:PossibleThrust().
}
local _68 is 0.
until _68>_67*0.5
{
set _68 to 0.
for eng in _66
{
set _68 to _68+eng:Thrust().
}
wait 0.
}
}
brakes off.
print"Beginning takeoff roll.".
when alt:radar>=50 then{gear off.lights off._f7(1).}
}
set _29["rwh"]:Text to round(_f4(_51),1)+"°".
set _29["rwd"]:Text to round(_f5(_51)*0.001,1)+" km".
wait 0.
}
ClearGuis().
set Ship:Control:Neutralize to true.
