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
local _4 is false.
local _5 is false.
local _6 is true.
local _7 is false.
local _8 is list().
local _9 is 0.
local _10 is 0.
for p in Ship:parts
{
if p:HasModule("FARControllableSurface")
{
local _11 is p:GetModule("FARControllableSurface").
if _11:HasAction("increase flap deflection")and _11:HasAction("decrease flap deflection")
{
_3:add(_11).
}
}
else if p:HasModule("RealChuteModule")
{
_8:add(p).
}
if p:HasModule("ModuleEnginesAJEJet")
{
local _12 is p:GetModule("ModuleEnginesAJEJet").
if _12:HasField("afterburner throttle")
{
set _4 to true.
}
}
else if p:HasModule("ModuleEnginesRF")
{
local _13 is p:GetModule("ModuleEnginesRF").
if _13:HasField("ignitions remaining")
{
set _5 to true.
}
}
if p:HasModule("ModuleWheelBrakes")
{
if vdot(p:Position,Ship:RootPart:Facing:RightVector)>1
{
set _10 to p.
}
else if vdot(p:Position,Ship:RootPart:Facing:RightVector)<-1
{
set _9 to p.
}
else
{
p:GetModule("ModuleWheelBrakes"):SetField("brakes",0).
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
local _14 is 50.
local _15 is 250.
local _16 is round(_f0,0).
local _17 is 0.
local _18 is 120.
local _19 is 90.
local _20 is 1.
local _21 is 1.
local _22 is 0.1.
local _23 is 0.25.
local _24 is 1.
if _5 and not ship:rootpart:tag:contains("noclimb")
{
set _14 to 0.
set _17 to 50.
}
else
{
set _6 to false.
}
local _25 is PIDloop(0.02,0.001,0.02,-1,1).
local _26 is PIDloop(0.005,0.00005,0.001,-1,1).
local _27 is PIDloop(0.1,0.002,0.05,0,1).
local _28 is PIDloop(3,0.0,5,-45,45).
local _29 is pidloop(0.5,0.01,0.1,-40,45).
local _30 is pidloop(0.25,0.01,0.2).
local _31 is PIDLoop(0.15,0,0.1,-1,1).
local _32 is Gui(300).
set _32:X to 200.
set _32:Y to _32:Y+60.
local _33 is _32:AddHBox().
local _34 is _33:AddVBox().
set _34:style:width to 150.
local _35 is _33:AddVBox().
set _35:style:width to 120.
local _36 is _33:AddVBox().
set _36:style:width to 50.
local _37 is list().
local _38 is lexicon().
local function _f8
{
parameter _p0.
parameter _p1.
parameter _p2.
parameter _p3.
parameter _p4.
local _39 is _34:AddLabel(_p1).
set _39:Style:Height to 25.
_37:add(_39).
set _39 to _35:AddTextField(_p2:ToString).
set _39:Style:Height to 25.
if _p3:IsType("UserDelegate")
set _39:OnConfirm to _p3.
else
set _39:Enabled to false.
_37:add(_39).
if _p4:Length>0
set _39 to _36:AddButton(_p4).
else
set _39 to _36:AddCheckBox(_p4,true).
set _39:Style:Height to 25.
_38:add(_p0,_39).
}
local function _f9
{
parameter _p0.
parameter _p1.
parameter _p2.
local _40 is _34:AddLabel(_p1).
set _40:Style:Height to 25.
_37:add(_40).
set _40 to _35:AddTextField(_p2:ToString).
set _40:Style:Height to 25.
set _40:Enabled to false.
_37:add(_40).
_38:add(_p0,_40).
}
_f8("hdg","Heading",_16,{parameter s.set _16 to s:ToNumber(_16).},"").
_f8("spd","Airspeed",_15,{parameter s.set _15 to s:ToNumber(_15).},"").
_f8("fl","Flight Level",_14,{parameter s.set _14 to s:ToNumber(_14).},"").
_f8("cr","Climb Rate",_17,{parameter s.set _17 to s:ToNumber(_17).},"").
if _5
{
set _38["fl"]:Pressed to false.
set _38["spd"]:Pressed to false.
}
else
{
set _38["cr"]:Pressed to false.
}
set _38["fl"]:OnToggle to{parameter val.if val{_30:Reset().set _38["cr"]:Pressed to false.}}.
set _38["cr"]:OnToggle to{parameter val.if val set _38["fl"]:Pressed to false.}.
_f8("to","Rotate Speed",_18,{parameter s.set _18 to s:ToNumber(_18).},"TO").
_f8("lnd","Landing Speed",_19,{parameter s.set _19 to s:ToNumber(_19).},"Land").
if _4
{
_f8("rht","Reheat",0,0,"").
set _38["rht"]:Pressed to false.
}
_f9("rwh","Runway Heading","0.0°").
_f9("rwd","Runway Distance","0.0 km").
_f9("dbg","Debug","").
local _41 is _37[_37:Length-2].
local _42 is _32:AddButton("Exit").
local _43 is round(_f0,1).
local _44 is 0.
local _45 is 0.
local _46 is 0.
local _47 is 0.
local _48 is Time:Seconds.
local _49 is 0.
local _50 is 1.
local _51 is 10.
local _52 is 20.
local _53 is 21.
local _54 is 22.
local _55 is 23.
local _56 is 24.
local _57 is 25.
local _58 is 26.
local _59 is 27.
local _60 is _51.
set _41:Text to"Flight".
local _61 is V(0,0,0).
local _62 is V(0,0,0).
local _63 is V(0,0,0).
local _64 is-1.
local _65 is V(0,0,0).
local function _f10
{
parameter _p0.
local _66 is round(_p0/10,0).
if _66<10
return"0"+_66:ToString.
return _66:ToString.
}
if Ship:status="PreLaunch"or Ship:status="Landed"
{
Core:Part:GetModule("kOSProcessor"):DoEvent("Open Terminal").
set _60 to _49.
set _41:Text to"Landed".
set _38["to"]:Enabled to true.
set _38["lnd"]:Enabled to false.
set _64 to round(_f0,1).
set _61 to-Ship:Body:Position.
set _62 to _61+Heading(_f0,0):Vector*2400.
set Ship:Type to"Plane".
set _63 to(_61+_62)*0.5.
print"Takeoff from runway "+_f10(_64).
}
_32:Show().
until _42:TakePress
{
if _4
{
if _38["rht"]:Pressed
set _24 to 1.
else
set _24 to 2/3.
}
if _60<>_49
{
local _67 is-1e8.
local _68 is _f2.
local _69 is _f0.
local _70 is true.
local _71 is 0.
if _60=_50
{
if Ship:GroundSpeed>=_18 or Ship:Status="Flying"
{
set _68 to 10.
if _5 or _7
set _68 to 20.
}
if _68>0 and Ship:Status="Flying"and _44=0
{
set _44 to Ship:AirSpeed.
print"Stall speed set to "+round(_44,1).
set Ship:Control:WheelSteer to 0.
}
else if Ship:Status="Landed"
{
set _44 to 0.
}
set _69 to _43.
set Ship:Control:PilotMainThrottle to 1.
local _72 is 250.
if _6
set _72 to 10.
else if _7
set _72 to 500.
if Alt:Radar>_72 and Ship:VerticalSpeed>0
{
_f7(0).
set _60 to _51.
set _41:Text to"Flight".
set _38["lnd"]:Enabled to true.
}
if _68<10 and abs(_f3(_43,_f0))>5
{
print"Veering off course too far, check wheel steering. Takeoff aborted.".
brakes on.
set Ship:Control:PilotMainThrottle to 0.
set _60 to _59.
set _41:Text to"Brake".
set _38["to"]:Enabled to true.
set _1 to _62.
}
}
else if _60=_51
{
if _38["fl"]:Pressed or _38["cr"]:Pressed or _38["hdg"]:Pressed
{
if _6
{
set _68 to _17.
if Ship:VerticalSpeed<0
{
set _6 to false.
}
}
else if _38["fl"]:Pressed
{
local _73 is _14*100-Ship:Altitude.
set _67 to max(-Ship:Airspeed*0.25,min(Ship:Airspeed*0.25,15*_73/Ship:Airspeed)).
if _67>Ship:Airspeed*0.2
{
set _30:MinOutput to-_67.
set _30:MaxOutput to _67.
local _74 is _44*1.5.
if _38["spd"]:Pressed
set _74 to _15.
set _67 to _67+_30:Update(Time:Seconds,_74-Ship:AirSpeed).
}
}
else if _38["cr"]:Pressed
{
set _67 to _17.
}
if _6
{
set _69 to _f0.
}
else if _38["hdg"]:pressed
{
set _69 to _16.
}
}
else
{
set _70 to false.
}
if _38["spd"]:Pressed
{
if not _38["fl"]:Pressed or _14*100<Ship:Altitude+max(Ship:VerticalSpeed*5,50)
{
set _71 to _15.
}
else
{
set Ship:Control:PilotMainThrottle to _24.
}
}
if _38["lnd"]:TakePress
{
if _64>=0
{
if(-Ship:Body:Position-_61):SqrMagnitude<(-Ship:Body:Position-_62):SqrMagnitude
{
set _65 to _61.
set _43 to _64.
}
else
{
set _65 to _62.
set _43 to mod(_64+180,360).
}
print"Landing at runway "+_f10(_43).
set _1 to _65-heading(_43,0):Vector*12000+Ship:Up:Vector*1000.
if _5
set _1 to _1+Ship:Up:Vector*600.
set _60 to _52.
set _41:Text to"Initial Approach".
set _38["lnd"]:Enabled to false.
}
else
{
set _60 to _57.
set _41:Text to"Manual Landing".
print"Manual landing assistance active".
when alt:radar<200 then{gear on.lights on.}
}
for chute in _8
{
local _75 is chute:GetModule("RealChuteModule").
if _75:HasEvent("arm parachute")
{
_75:DoEvent("arm parachute").
}
}
}
}
else if _60=_52
{
set _67 to _f6().
set _69 to _f4().
set _71 to(1.5+_f5()/10000)*_19.
local _76 is 1.5*_19.
set _71 to max(_76,min(Ship:Airspeed,_71)).
local _77 is 200.
if _5 or abs(_f3(_43,_f0))<=60
set _77 to _77+abs(_f3(_43,_f0))*Ship:Airspeed*0.25.
set _38["dbg"]:Text to round(_69,1)+"° "+round(_f5()*0.001,1)+"/"+round(_77*0.001,1).
if _f5()<_77
{
if _5 or(abs(_f3(_43,_f0))<=60 and Ship:AirSpeed<_71*1.2)
{
set _60 to _54.
set _41:Text to"Approach".
set _1 to _65-heading(_43,0):Vector*4000+Ship:Up:Vector*250.
if _5
set _1 to _1+Ship:Up:Vector*100.
_f7(2).
print"On approach".
}
else
{
set _60 to _53.
set _41:Text to"Turn 1".
if Ship:AirSpeed>=_71*1.2
print"Turning to reduce speed".
else
print"Turning to correct heading".
}
}
else if _5 and Alt:Radar<1000
{
set _60 to _58.
set _41:Text to"Ditching".
set _43 to _f0.
print"Insufficient momentum for landing, ditching aircraft".
}
}
else if _60=_53
{
set _67 to(1000-Ship:Altitude)*0.025.
set _71 to 1.5*_19.
local _78 is 2500*_19*_19/6400.
if _f5()<_78
{
set _69 to mod(_43+135,360).
local _79 is mod(_43+225,360).
if abs(_f3(_79,_f0))<abs(_f3(_69,_f0))
set _69 to _79.
set _38["dbg"]:Text to round(_69,1)+"° "+round(_f5()*0.001,2)+" / "+round(_78*0.001,2).
}
else
{
set _69 to mod(_43+180,360).
set _41:Text to"Turn 2".
set _38["dbg"]:Text to round(_69,1)+"° "+round(_f5()*0.001,2)+" / "+round(_78*0.002,2).
if _f5()>_78*2
{
set _60 to _52.
set _41:Text to"Initial Approach".
}
}
}
else if _60=_54
{
set _67 to _f6().
set _69 to _f4().
set _71 to min((1+_f5()/16000),1.5)*_19.
set _38["dbg"]:Text to round(_69,1)+"° "+round(_f5()*0.001,2)+"/0.05".
if _f5()<50
{
kUniverse:Timewarp:CancelWarp().
set _60 to _55.
set _41:Text to"Final".
set _1 to _65+Ship:Up:Vector*10.
_f7(3).
gear on.
when alt:radar<200 then{lights off.lights on.}
print"Final approach".
}
}
else if _60=_55
{
set _69 to _f4().
set _71 to _19.
set _38["dbg"]:Text to round(_69,1)+"° ".
if Alt:radar<30 or(Alt:Radar<40 and _5)
{
set _67 to-2.
set _69 to _43.
}
else
{
set _67 to _f6().
if not _5
set _67 to max(_67,-6).
}
if Alt:Radar<10
{
set _67 to-0.5.
}
if Ship:Status="Landed"
{
brakes on.
print"Braking".
set _60 to _59.
set _41:Text to"Brake".
if(_65-_61):SqrMagnitude<(_65-_62):SqrMagnitude
set _1 to _62.
else
set _65 to _61.
}
}
else if _60=_56 or _60=_59
{
set Ship:Control:PilotMainThrottle to 0.
if _60=_59
set _43 to _f4().
set _69 to _43.
if Ship:GroundSpeed<1
{
_f7(0).
set _60 to _49.
set _41:Text to"Landed".
}
else
{
local a is _f3(_f0,_69).
if Ship:GroundSpeed<8
set a to 0.
local _80 is max(100-Ship:GroundSpeed,0)*min(max(3-abs(a),0),1).
if _9:IsType("part")and _10:IsType("part")
{
_9:GetModule("ModuleWheelBrakes"):SetField("brakes",_80*min(max(1.5-a,0.1),1.25)).
_10:GetModule("ModuleWheelBrakes"):SetField("brakes",_80*min(max(1.5+a,0.1),1.25)).
}
else if abs(a)<1
brakes on.
else
brakes off.
}
}
else if _60=_57
{
set _70 to false.
if Ship:Status="Landed"
{
brakes on.
set _43 to _f0.
print"Braking".
set _60 to _56.
set _41:Text to"Brake".
}
else if _38["lnd"]:TakePress
{
print"Landing assistance cancelled".
set _60 to _51.
set _41:Text to"Flight".
}
}
else if _60=_58
{
set _69 to _43.
if Alt:Radar>1
set _67 to-((Alt:Radar/10)^0.8).
if Ship:Status="Landed"
{
brakes on.
print"Braking".
set _60 to _56.
set _41:Text to"Brake".
}
}
if not _5 and _60>=_51 and _60<=_55
{
set _7 to false.
if _60=_55
set _7 to abs(_f3(_f0,_69))>=8 or(Ship:VerticalSpeed<-8 and Ship:VerticalSpeed*-5>Alt:Radar).
else
set _7 to Ship:VerticalSpeed*-10>Alt:Radar.
if _7
{
print"Aborting landing".
set Ship:Control:PilotMainThrottle to 1.
set _71 to 0.
set _67 to-1e8.
set _68 to 20.
set _69 to _f0.
set _43 to _f0.
set _60 to _50.
set _38["hdg"]:Pressed to false.
set _41:Text to"Abort".
_f7(2).
when alt:radar>=20 and Ship:VerticalSpeed>0 then{gear off.if _2>1 _f7(1).}
}
}
if _70
{
if _67>0
set _67 to max(min(_67,Ship:Airspeed-_44),0).
local _81 is 120/max(Ship:AirSpeed,80).
if Ship:Status="Landed"
set _81 to _81*1.5.
if _67>-1e6
{
print"reqClimbRate="+round(_67,1)+" / "+round(ship:verticalspeed,1)+" "at(0,0).
set _29:kP to _21*_81.
set _29:kD to _23.
set _29:kI to _22*_81.
set _29:SetPoint to _67.
set _68 to _29:Update(time:seconds,Ship:verticalspeed).
}
set _81 to _81*max(0.1,min(_20,10)).
set _25:kP to 0.06*_81.
set _25:kD to 0.04*_81.
set _25:kI to 0.002*_81.
set _25:SetPoint to _68.
set ship:control:pitch to _25:update(time:seconds,_f2).
print"reqPitch="+round(_68,2)+" / "+round(_f2,2)+" "at(0,1).
local _82 is 0.
if((_5 and not _6)or abs(_67-ship:verticalspeed)<50)and alt:radar>10
{
set _28:SetPoint to-_f3(_69,_f0).
if _28:SetPoint<-175
set _28:SetPoint to 180.
set _82 to _28:Update(time:seconds,0).
}
else
{
_28:Reset().
}
set _26:kP to 0.005*_81.
set _26:kI to 0.0001*_81.
set _26:kD to 0.002*_81.
set _26:SetPoint to _82.
set ship:control:roll to _26:Update(time:seconds,_f1()).
}
else
{
set Ship:Control:Neutralize to true.
_29:Reset().
_25:Reset().
_26:Reset().
}
if _71>0
{
set _27:MaxOutput to _24.
set _27:SetPoint to _71.
set Ship:Control:PilotMainThrottle to _45*_46+_27:Update(time:seconds,Ship:AirSpeed)*(1-_45).
set _45 to max(0,_45-0.05).
}
else
{
set _45 to 1.
set _46 to Ship:Control:PilotMainThrottle.
_27:Reset().
}
if Ship:Status="Landed"
{
local _83 is _f3(_43,_f0).
set _31:kP to 0.02/max(1,Ship:GroundSpeed/12).
set _31:kD to _31:kP*2/3.
set Ship:Control:WheelSteer to _31:update(time:seconds,-_83).
set _38["dbg"]:Text to round(_43,1)+"° ".
}
else
{
_31:Reset().
}
if _70 and(abs(Ship:Control:PilotYaw)>0.8 or abs(Ship:Control:PilotPitch)>0.8 or abs(Ship:Control:PilotRoll)>0.8)
{
set _38["fl"]:Pressed to false.
set _38["cr"]:Pressed to false.
set _38["hdg"]:Pressed to false.
set _38["spd"]:Pressed to false.
set _60 to _51.
set _41:Text to"Flight".
set Ship:Control:PilotMainThrottle to _24.
print"Autopilot disengaged.".
set _38["lnd"]:Enabled to true.
}
}
else if _38["to"]:TakePress
{
set _60 to _50.
set _41:Text to"Takeoff".
set _38["to"]:Enabled to false.
set _43 to round(_f0,1).
if Ship:Status="PreLaunch"
{
print"Engine start.".
stage.
}
local _84 is list().
list engines in _84.
for eng in _84
{
if eng:Stage=stage:Number
eng:Activate().
}
set Ship:Control:PilotMainThrottle to _24.
_f7(2).
if brakes
{
print"Waiting for engines to spool.".
local _85 is 0.
for eng in _84
{
if eng:Stage=stage:Number
set _85 to _85+eng:PossibleThrust().
}
local _86 is 0.
until _86>_85*0.5*_24
{
set _86 to 0.
for eng in _84
{
if eng:Stage=stage:Number
set _86 to _86+eng:Thrust().
}
wait 0.
}
}
brakes on.
brakes off.
print"Beginning takeoff roll.".
when alt:radar>=20 then{gear off.if _2>1 _f7(1).}
}
set _38["rwh"]:Text to round(_f4(_63),1)+"°".
set _38["rwd"]:Text to round(_f5(_63)*0.001,1)+" km".
wait 0.
}
ClearGuis().
set Ship:Control:Neutralize to true.
