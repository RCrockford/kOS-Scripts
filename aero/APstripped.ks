@lazyglobal off.
local _0 is lexicon(
"VAFB",lexicon("end1",latlng(34.585765,-120.641),"end2",latlng(34.585765,-120.6141),"alt",190,"hdg",90),
"KSC",lexicon("end1",latlng(28.612852,-80.6179),"end2",latlng(28.612852,-80.5925),"alt",78.5,"hdg",90)
).
wait until Ship:Unpacked.
local lock _f0 to mod(360-latlng(90,0):bearing,360).
local function _f1
{
local _1 is vcrs(up:vector,north:vector).
local _2 is vdot(north:vector,velocity:surface).
local _3 is vdot(_1,velocity:surface).
local _4 is arctan2(_3,_2).
return mod(_4+360,360).
}
local function _f2
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
local lock _f3 to 90-vang(Ship:up:vector,Ship:facing:forevector).
local function _f4
{
parameter a1,a2.
local _5 is a2-a1.
if _5<-180{
set _5 to _5+360.
}else if _5>180{
set _5 to _5-360.
}
return _5.
}
local _6 is 0.
local _7 is 0.
local function _f5
{
return _6:AltitudePosition(_7):Mag.
}
local function _f6
{
return(_7-Ship:Altitude)/(_f5()/Ship:AirSpeed).
}
local function _f7
{
parameter _p0.
if _p0:HasField("eng. internal temp")
{
local ts is _p0:GetField("eng. internal temp").
set ts to ts:split("/")[1]:replace(",","").
set ts to ts:substring(0,ts:find("K")).
return ts:ToScalar(0).
}
return 0.
}
local function _f8
{
parameter _p0.
local ts is _p0:GetField("eng. internal temp").
set ts to ts:replace(",","").
set ts to ts:substring(0,ts:find("K")).
return ts:ToScalar(0).
}
local _8 is 0.
local _9 is list().
local _10 is false.
local _11 is false.
local _12 is false.
local _13 is list().
local _14 is list().
local _15 is list().
local _16 is true.
local _17 is true.
local _18 is false.
local _19 is list().
local _20 is 0.
local _21 is 0.
local _22 is 0.
for p in Ship:parts
{
if p:HasModule("FARControllableSurface")
{
local _23 is p:GetModule("FARControllableSurface").
if _23:HasAction("increase flap deflection")and _23:HasAction("decrease flap deflection")
{
_9:add(_23).
}
}
else if p:HasModule("RealChuteModule")
{
_19:add(p).
}
if p:HasModule("ModuleEnginesAJEJet")
{
local _24 is p:GetModule("ModuleEnginesAJEJet").
if _24:HasField("afterburner throttle")
set _10 to true.
set _11 to true.
set _22 to _22+p:PossibleThrust.
local _25 is lexicon("part",p,"aje",_24,"restartSpeed",0,"maxtemp",_f7(_24),"reheat",_24:HasField("afterburner throttle"),"heatpid",PIDloop(1,0,0.2,-2,0.2)).
set _25:heatpid:SetPoint to _25:maxTemp-10.
_15:add(_25).
}
else if p:HasModule("ModuleEnginesAJERamjet")
{
local _26 is p:GetModule("ModuleEnginesAJERamjet").
set _11 to true.
set _22 to _22+p:PossibleThrust.
local _27 is lexicon("part",p,"aje",_26,"maxtemp",_f7(_26),"heatpid",PIDloop(1,0,0.2,-2,0.2)).
set _27:heatpid:SetPoint to _27:maxTemp-10.
_14:add(_27).
}
else if p:HasModule("ModuleEnginesRF")
{
local _28 is p:GetModule("ModuleEnginesRF").
if _28:HasField("ignitions remaining")
{
set _12 to true.
}
if p:tag:contains("rato")
_13:Add(p).
}
if p:HasModule("ModuleWheelBrakes")
{
if vdot(p:Position,Ship:RootPart:Facing:RightVector)>1
{
set _21 to p.
}
else if vdot(p:Position,Ship:RootPart:Facing:RightVector)<-1
{
set _20 to p.
}
else
{
p:GetModule("ModuleWheelBrakes"):SetField("brakes",0).
}
}
}
if _11
set _12 to false.
local function _f9
{
parameter _p0.
until _8=_p0
{
if _8<_p0
{
for f in _9
f:DoAction("increase flap deflection",true).
set _8 to _8+1.
}
else
{
for f in _9
f:DoAction("decrease flap deflection",true).
set _8 to _8-1.
}
}
if not _9:Empty
print"Flaps "+_8.
}
local function _f10
{
local _29 is list().
list engines in _29.
local _30 is false.
until _30
{
for eng in _29
{
if eng:Stage=stage:Number and not eng:HasModule("ModuleEnginesAJERamjet")
{
eng:Activate.
set _30 to true.
}
}
if not _30
stage.
}
set Ship:Control:PilotMainThrottle to 1.
}
local function _f11
{
local _31 is list().
list engines in _31.
for eng in _31
{
if eng:Ignitions<0 and not eng:HasModule("ModuleEnginesAJERamjet")
eng:Activate.
}
}
local function _f12
{
local _32 is list().
list engines in _32.
for eng in _32
{
eng:Shutdown.
}
}
local function _f13
{
parameter _p0.
local _33 is round(_p0/10,0).
if _33<10
return"0"+_33:ToString.
return _33:ToString.
}
local _34 is 50.
local _35 is 0.
local _36 is round(_f0,0).
local _37 is 0.
local _38 is 100.
local _39 is 0.
local _40 is 1.
if Core:Part:Tag:Contains("rot=")
{
local f is Core:Part:Tag:Find("rot=")+4.
set _38 to Core:Part:Tag:Substring(f,Core:Part:Tag:Length-f):Split(" ")[0]:ToNumber(_38).
}
set _38 to round(_38*0.2,0)*5.
set _39 to round(_38*0.17,0)*5.
set _35 to _38*2.
if _12 and not Core:Part:tag:contains("noclimb")
{
set _34 to 0.
set _37 to 30.
}
else
{
set _16 to false.
}
local _41 is PIDloop(0.5,0.05,0.2,-1,1).
local _42 is PIDLoop(0.15,0,0.1,-1,1).
local _43 is PIDloop(0.1,0,0.1,-1,1).
local _44 is 0.05.
local _45 is Gui(300).
set _45:X to 200.
set _45:Y to _45:Y+60.
local _46 is _45:AddHBox().
local _47 is _46:AddVBox().
set _47:style:width to 150.
local _48 is _46:AddVBox().
set _48:style:width to 120.
local _49 is _46:AddVBox().
set _49:style:width to 50.
local _50 is list().
local _51 is lexicon().
local function _f14
{
parameter _p0.
parameter _p1.
parameter _p2.
parameter _p3.
parameter _p4.
local _52 is _47:AddLabel(_p1).
set _52:Style:Height to 25.
_50:add(_52).
set _52 to _48:AddTextField(_p2:ToString).
set _52:Style:Height to 25.
if _p3:IsType("UserDelegate")
set _52:OnConfirm to _p3.
else
set _52:Enabled to false.
_50:add(_52).
if _p4:Length>0
set _52 to _49:AddButton(_p4).
else
set _52 to _49:AddCheckBox(_p4,true).
set _52:Style:Height to 25.
_51:add(_p0,_52).
}
local function _f15
{
parameter _p0.
parameter _p1.
parameter _p2.
local _53 is _47:AddLabel(_p1).
set _53:Style:Height to 25.
_50:add(_53).
set _53 to _48:AddTextField(_p2:ToString).
set _53:Style:Height to 25.
set _53:Enabled to false.
_50:add(_53).
_51:add(_p0,_53).
}
_f14("hdg","Heading",_36,{parameter s.set _36 to s:ToNumber(_36).},"").
_f14("spd","Airspeed",_35,{parameter s.set _35 to s:ToNumber(_35).},"").
_f14("fl","Flight Level",_34,{parameter s.set _34 to s:ToNumber(_34).},"").
_f14("cr","Climb Rate",_37,{parameter s.set _37 to s:ToNumber(_37).},"").
if _12
{
set _51["fl"]:Pressed to false.
set _51["spd"]:Pressed to false.
}
else
{
set _51["cr"]:Pressed to false.
}
set _51["fl"]:OnToggle to{parameter val.if val{set _51["cr"]:Pressed to false.}}.
set _51["cr"]:OnToggle to{parameter val.if val set _51["fl"]:Pressed to false.}.
_f14("to","Rotate Speed",_38,{parameter s.set _38 to s:ToNumber(_38).},"TO").
_f14("lnd","Landing Speed",_39,{parameter s.set _39 to s:ToNumber(_39).},"Land").
local _54 is 0.
if _10
{
_f14("rht","Fuel Cons (Reheat)",0,0,"").
set _51["rht"]:Pressed to true.
}
else
{
_f15("rht","Fuel Consumption","0").
}
set _54 to _50[_50:Length-1].
local _55 is latlng(0,0).
local _56 is latlng(0,0).
local _57 is 0.
local _58 is-1.
local _59 is"".
{
local _60 is 1e8.
set _59 to"".
for rw in _0:keys
{
local d is _0[rw]:end1:distance.
if d<_60
{
set _60 to d.
set _59 to rw.
}
}
set _55 to _0[_59]:end1.
set _56 to _0[_59]:end2.
set _57 to _0[_59]:alt.
set _58 to _0[_59]:hdg.
}
_f15("rwy",_59+" Runway","0.0° 0.0 km").
_f15("dbg","Debug","").
local _61 is _50[_50:Length-2].
local _62 is round(_f0,1).
local _63 is true.
local _64 is Time:Seconds.
local _65 is 0.
local _66 is 1.
local _67 is 2.
local _68 is 3.
local _69 is 10.
local _70 is 20.
local _71 is 21.
local _72 is 22.
local _73 is 23.
local _74 is 24.
local _75 is 25.
local _76 is 26.
local _77 is 27.
local _78 is _69.
set _61:Text to"Flight".
local _79 is 0.
local _80 is 0.
local _81 is 0.
local _82 is _45:AddHBox().
local _83 is _82:AddButton("Taxi "+_f13(_58)).
local _84 is _82:AddButton("Taxi "+_f13(mod(_58+180,360))).
local _85 is-1.
local _86 is 0.2.
if Ship:status="PreLaunch"or Ship:status="Landed"
{
Core:Part:GetModule("kOSProcessor"):DoEvent("Open Terminal").
set _78 to _65.
set _61:Text to"Landed".
set _51["to"]:Enabled to true.
set _51["lnd"]:Enabled to false.
set Ship:Type to"Plane".
brakes on.
set _86 to 1.2/(8-_f3).
}
else
{
set _51["to"]:Enabled to false.
}
if _12
set _86 to _86*2.
local _87 is _82:AddButton("Exit").
local _88 is 0.
local _89 is Time:Seconds.
set addons:aa:fbw to true.
set addons:aa:pseudoflc to false.
set addons:aa:maxg to 9.
set addons:aa:maxsideg to 8.
set addons:aa:moderateaoa to true.
set addons:aa:moderatesideslip to true.
set addons:aa:moderateg to true.
set addons:aa:moderatesideg to true.
set addons:aa:rollratelimit to 1.
set addons:aa:wingleveler to true.
set addons:aa:directorstrength to 0.6.
set addons:aa:maxclimbangle to choose 45 if _22/(ship:mass*9.81)>=0.8 else 30.
print"TWR="+round(_22/(ship:mass*9.81),2)+" maxclimb="+addons:aa:maxclimbangle.
_45:Show().
until _87:TakePress
{
if not _15:Empty
{
local _90 is 100.
if _10 and not _51["rht"]:Pressed and _78>=_69
set _90 to 200/3.
for jet in _15
{
if jet:maxTemp>0 and _78>=_69
{
if jet:part:Ignition
{
local _91 is jet:heatpid:Update(time:seconds,_f8(jet:aje)).
set jet:part:ThrustLimit to min(max(4,jet:part:ThrustLimit+_91),choose _90 if jet:reheat else 100).
if jet:part:ThrustLimit>=50
{
set jet:restartSpeed to floor(Ship:AirSpeed).
}
else if(jet:part:ThrustLimit<=20 or jet:part:Thrust<=0)and Ship:AirSpeed>jet:restartSpeed+1
{
jet:part:shutdown.
print"Shutting down "+jet:part:title+" restart at "+jet:restartSpeed+" m/s.".
}
}
else
{
if Ship:AirSpeed<=jet:restartSpeed
jet:part:activate.
}
}
else
{
set jet:part:ThrustLimit to choose _90 if jet:reheat else 100.
}
}
}
if not _14:Empty
{
for jet in _14
{
if Ship:AirSpeed>=600 and not jet:part:Ignition
{
jet:part:Activate.
}
else if Ship:AirSpeed<580 and jet:part:Ignition
{
jet:part:Shutdown.
}
if jet:maxTemp>0 and jet:part:Ignition
{
local _92 is jet:heatpid:Update(time:seconds,_f8(jet:aje)).
set jet:part:ThrustLimit to min(max(1,jet:part:ThrustLimit+_92),100).
}
}
}
if _78<>_65
{
local _93 is-1e8.
local _94 is _f3.
local _95 is-1.
local _96 is true.
local _97 is 0.
if _78=_66
{
if Ship:GroundSpeed>=_38 or Ship:Status="Flying"
{
set _94 to 8.
if _12 or _18
set _94 to 20.
}
else
{
set _62 to _79:Heading.
if Ship:longitude<_79:lng
set _62 to _62+(Ship:Latitude-_79:Lat)*12000.
else
set _62 to _62-(Ship:Latitude-_79:Lat)*12000.
}
if _94>0 and Ship:Status="Flying"and _63
{
set _63 to false.
set Ship:Control:WheelSteer to 0.
set Ship:Control:Yaw to 0.
}
else if Ship:Status="Landed"
{
set _63 to true.
}
set _95 to _62.
set Ship:Control:PilotMainThrottle to 1.
local _98 is 200*(30/addons:aa:maxclimbangle)^2.25.
if _16
set _98 to 10.
else if _18
set _98 to 400.
if Alt:Radar>_98 and Ship:VerticalSpeed>0 and _f3>5
{
_f9(0).
set _78 to _69.
set _61:Text to"Flight".
set _51["lnd"]:Enabled to true.
}
}
else if _78=_69
{
if _51["fl"]:Pressed or _51["cr"]:Pressed or _51["hdg"]:Pressed
{
if _16
{
set _94 to _37.
if Ship:VerticalSpeed<0
{
set _16 to false.
_f12().
if Ship:Altitude>100000
brakes on.
}
}
else if _51["cr"]:Pressed
{
set _93 to _37.
}
if _51["hdg"]:pressed
{
set _95 to _36.
}
}
else
{
set _96 to false.
}
if _51["spd"]:Pressed
{
set _97 to _35.
}
if _51["lnd"]:TakePress
{
if _58>=0
{
if _55:Distance<_56:Distance
{
set _79 to _55.
set _62 to _58.
set _80 to _55:Lat-_56:Lat.
set _81 to _55:Lng-_56:Lng.
}
else
{
set _79 to _56.
set _62 to mod(_58+180,360).
set _80 to _56:Lat-_55:Lat.
set _81 to _56:Lng-_55:Lng.
}
print"Landing at runway "+_f13(_62).
set _6 to LatLng(_79:lat+_80*(12/2.46),_79:lng+_81*(12/2.46)).
set _7 to _57+500.
if _12
{
set _6 to LatLng(_6:lat+_80,_6:lng+_81).
set _7 to _7+1250.
}
set _78 to _70.
set _61:Text to"Initial Approach".
set _51["lnd"]:Enabled to false.
set _93 to _f6().
}
else
{
set _78 to _75.
set _61:Text to"Manual Landing".
print"Manual landing assistance active".
when alt:radar<200 then{gear on.lights on.}
}
for chute in _19
{
local _99 is chute:GetModule("RealChuteModule").
if _99:HasEvent("arm parachute")
{
_99:DoEvent("arm parachute").
}
}
}
}
else if _78=_70
{
set _93 to _f6().
set _95 to _6:Heading.
set _97 to(1.5+_f5()/25000)*_39.
local _100 is 1.5*_39.
set _97 to max(_100,min(Ship:Airspeed,_97)).
local _101 is 200.
if _12 or abs(_f4(_62,_f0))<=60
set _101 to _101+abs(_f4(_62,_f0))*Ship:Airspeed*0.25.
set _51["dbg"]:Text to round(_95,1)+"° "+round(_f5()*0.001,1)+"/"+round(_101*0.001,1).
if _f5()<_101
{
if _12 or(abs(_f4(_62,_f0))<=60 and Ship:AirSpeed<_97*1.2)
{
set _78 to _72.
set _61:Text to"Approach".
set _6 to LatLng(_79:lat+_80*(4/2.46),_79:lng+_81*(4/2.46)).
set _7 to _57+220.
if _12
set _7 to _7+280.
else
_f9(2).
print"On approach".
}
else
{
set _78 to _71.
set _61:Text to"Turn 1".
if Ship:AirSpeed>=_97*1.2
print"Turning to reduce speed".
else
print"Turning to correct heading".
}
}
else if _12 and Alt:Radar<1000
{
set _78 to _76.
set _61:Text to"Ditching".
set _62 to _f0.
print"Insufficient momentum for landing, ditching aircraft".
}
}
else if _78=_71
{
set _93 to(_7-Ship:Altitude)*0.05.
set _97 to 1.5*_39.
local _102 is 2500*_39*_39/6400.
if _f5()<_102
{
set _95 to mod(_62+135,360).
local _103 is mod(_62+225,360).
if abs(_f4(_103,_f0))<abs(_f4(_95,_f0))
set _95 to _103.
set _51["dbg"]:Text to round(_95,1)+"° "+round(_f5()*0.001,2)+" / "+round(_102*0.001,2).
}
else
{
set _95 to mod(_62+180,360).
set _61:Text to"Turn 2".
set _51["dbg"]:Text to round(_95,1)+"° "+round(_f5()*0.001,2)+" / "+round(_102*0.002,2).
if _f5()>_102*2
{
set _78 to _70.
set _61:Text to"Initial Approach".
}
}
}
else if _78=_72
{
if _f5()<800
{
kUniverse:Timewarp:CancelWarp().
set _95 to(_6:Heading+_79:Heading)/2.
}
else
{
set _95 to _6:Heading.
}
set _93 to _f6().
set _97 to min((1+_f5()/16000),1.5)*_39.
set _51["dbg"]:Text to round(_95,1)+"° "+round(_f5()*0.001,1)+"/0.1".
if _79:Distance<4200
{
set _78 to _73.
set _61:Text to"Final".
set _6 to _79.
if _55:Distance<_56:Distance
set _79 to _56.
else
set _79 to _55.
set _7 to _57+5.
_f9(3).
gear on.
brakes off.
when alt:radar<100 then{lights off.lights on.}
print"Final approach".
}
}
else if _78=_73
{
set _95 to _6:Heading.
set _97 to _39.
set _51["dbg"]:Text to round(_95,1)+"° "+round(_f5()*0.001,2).
local _104 is max(1,min(Alt:Radar,Ship:Altitude-_57)).
if _12 and _104<100
{
set _93 to-(_104/20)^1.7.
set _95 to _79:heading.
}
else if _104<30
{
set _93 to-(_104/10)^1.2.
set _95 to _79:heading.
}
else
{
set _93 to _f6().
}
if Ship:VerticalSpeed<_93
set _93 to _93+(_93-Ship:VerticalSpeed)*0.6.
if _104<20
set _93 to min(_93,-0.5).
if Ship:longitude<_79:lng
set _95 to _95+(Ship:Latitude-_79:Lat)*8000.
else
set _95 to _95-(Ship:Latitude-_79:Lat)*8000.
if Ship:Status="Landed"
{
brakes on.
print"Braking".
set _78 to _77.
set _61:Text to"Brake".
set _6 to _79.
_f12().
}
}
else if _78=_74 or _78=_77
{
set Ship:Control:PilotMainThrottle to 0.
if _78=_77
set _62 to _6:Heading.
set _95 to _62.
set _94 to 0.
if Ship:GroundSpeed<1
{
_f9(0).
set _78 to _65.
set _61:Text to"Landed".
}
else
{
local a is _f4(_f0,_95).
if Ship:GroundSpeed<8
set a to 0.
local _105 is max(100-Ship:GroundSpeed,0)*min(max(3-abs(a),0),1).
if _20:IsType("part")and _21:IsType("part")
{
_20:GetModule("ModuleWheelBrakes"):SetField("brakes",_105*min(max(1.5-a,0.1),1.25)).
_21:GetModule("ModuleWheelBrakes"):SetField("brakes",_105*min(max(1.5+a,0.1),1.25)).
}
}
}
else if _78=_75
{
set _96 to false.
if Ship:Status="Landed"
{
brakes on.
set _62 to _f0.
print"Braking".
set _78 to _74.
set _61:Text to"Brake".
}
else if _51["lnd"]:TakePress
{
print"Landing assistance cancelled".
set _78 to _69.
set _61:Text to"Flight".
}
}
else if _78=_76
{
set _95 to _62.
if Alt:Radar>1
set _93 to-((Alt:Radar/10)^0.8).
if Ship:Status="Landed"
{
brakes on.
print"Braking".
set _78 to _74.
set _61:Text to"Brake".
}
}
else if _78=_67
{
if _f5()<5
{
set _78 to _68.
}
set _62 to _6:Heading.
if Ship:GroundSpeed>16
brakes on.
else if Ship:GroundSpeed<15
brakes off.
}
else if _78=_68
{
local a is _f4(_f0,_85).
if abs(a)<0.5
{
brakes on.
_f12().
set _78 to _65.
set _61:Text to"Landed".
set _51["to"]:Enabled to true.
set _83:Enabled to true.
set _84:Enabled to true.
}
else
{
if abs(a)>100
{
set _62 to mod(_85+90,360).
}
else
{
set _62 to _85.
}
if Ship:GroundSpeed>3
brakes on.
else if Ship:GroundSpeed<2.5
brakes off.
}
}
if not _12 and _78>=_69 and _78<=_73
{
set _18 to false.
if _78=_73
set _18 to(Ship:Altitude<=_57)or(Ship:VerticalSpeed<-8 and Ship:VerticalSpeed*-5>Alt:Radar).
else
set _18 to Ship:VerticalSpeed*-10>Alt:Radar.
if _18
{
print"Aborting landing: vs="+round(Ship:VerticalSpeed,1)+" h="+round(Alt:Radar,1).
set Ship:Control:PilotMainThrottle to 1.
set _97 to 0.
set _93 to-1e8.
set _94 to 20.
set _95 to-1.
set _62 to _f0.
set _78 to _66.
set _51["hdg"]:Pressed to false.
set _61:Text to"Abort".
_f9(2).
when alt:radar>=20 and Ship:VerticalSpeed>0 then{gear off.if _8>1 _f9(1).}
}
}
local _106 is false.
if _12 and _78=_69
{
if _16
{
set addons:aa:maxaoa to 30.
local _107 is list().
list engines in _107.
local _108 is 0.
for eng in _107
{
set _108 to _108+eng:Thrust.
}
if _108<0.1
{
set _94 to max(90-vang(Ship:up:vector,Ship:Velocity:Surface),20).
if _17
{
set _17 to false.
steeringmanager:resettodefault().
}
}
}
else
{
set addons:aa:maxaoa to min(max(5+Ship:altitude/1000,15),75).
if Ship:Altitude>25000 or Ship:VerticalSpeed<-200
{
set _94 to 20.
set _93 to-1e8.
}
}
if(Ship:Altitude>30000 and Ship:VerticalSpeed>0)or Ship:Altitude>40000
set _106 to true.
}
if not _13:Empty and Stage:Number>0 and Stage:Ready
{
local _109 is true.
for e in _13
{
if not e:Flameout
set _109 to false.
}
if _109
{
set _13 to list().
stage.
}
}
if _106 or(_16 and Ship:Altitude>15000)
{
set addons:aa:fbw to false.
set addons:aa:cruise to false.
set addons:aa:director to false.
set _95 to _f1().
set SteeringManager:RollControlAngleRange to 180.
lock steering to heading(_95,_94):Vector.
print"HighAlt "+round(_95,1)+"° p="+round(_94,1)+"/"+round(_f3,1)+"° "at(0,0).
if navmode<>"surface"
set navmode to"surface".
}
else
{
unlock steering.
if _96
{
if _93>-1e6
{
set addons:aa:vertspeed to _93.
set addons:aa:heading to _95.
set addons:aa:cruise to true.
print"Cruise "+round(_95,1)+"° vs="+round(_93,1)+"/"+round(Ship:VerticalSpeed,1)+" "at(0,0).
}
else if not _16 and _78=_69 and _51["fl"]:Pressed
{
set addons:aa:altitude to _34*100.
set addons:aa:heading to _95.
set addons:aa:cruise to true.
print"Cruise "+round(_95,1)+"° alt="+round(_34,0)+" "at(0,0).
}
else
{
set addons:aa:direction to heading(choose _95 if _95>=0 else _f0,_94):Vector.
set addons:aa:director to true.
print"Dir "+round(_95,1)+"° p="+round(_94,1)+"/"+round(_f3,1)+"° MaxAoA="+round(addons:aa:maxaoa,1)+"° "at(0,0).
}
if _63 and _94>_f3
{
set ship:control:pitch to min((_94-_f3)*_86,1).
}
else
{
set Ship:Control:Neutralize to true.
}
}
else
{
set Ship:Control:Neutralize to true.
set addons:aa:cruise to false.
set addons:aa:director to false.
set addons:aa:fbw to true.
print"FBW "at(0,0).
}
}
if _97>0
{
set _43:SetPoint to _97.
local _110 is _43:Update(time:seconds,Ship:AirSpeed)*_44.
local _111 is choose 0.1 if _16 else 0.
if brakes
set Ship:Control:PilotMainThrottle to _111*10.
else
set Ship:Control:PilotMainThrottle to min(max(_111,Ship:Control:PilotMainThrottle+_110),1).
print"Speed "+round(_97,1)+"/"+round(Ship:AirSpeed,1)+" "at(0,1).
if _78>=_70 and _78<=_73
{
if Ship:AirSpeed>_97+10
brakes on.
else if Ship:AirSpeed<=_97+2
brakes off.
}
}
else
{
_43:Reset().
print"No speed "at(0,1).
}
if Ship:Status="Landed"
{
local _112 is _f4(_62,_f0).
set _42:kP to 0.04/max(0.5,Ship:GroundSpeed/18).
set _42:kD to _42:kP*2/3.
if _78=_66
set _42:kP to _42:kP*2.
set Ship:Control:WheelSteer to _42:update(time:seconds,-_112).
set Ship:Control:Yaw to _41:Update(time:seconds,_112).
if _78=_67
set _51["dbg"]:Text to round(_62,1)+"° "+round(_f5(),1)+"m".
else
set _51["dbg"]:Text to round(_62,1)+"° ".
}
else
{
_42:Reset().
}
if _12
{
if Ship:Altitude>15000 or _78=_73 or _78=_76 or _16
rcs on.
else if Ship:Altitude<14500
rcs off.
}
if _96 and(abs(Ship:Control:PilotYaw)>0.8 or abs(Ship:Control:PilotPitch)>0.8 or abs(Ship:Control:PilotRoll)>0.8)
{
set _51["fl"]:Pressed to false.
set _51["cr"]:Pressed to false.
set _51["hdg"]:Pressed to false.
set _51["spd"]:Pressed to false.
set _78 to _69.
set _61:Text to"Flight".
set Ship:Control:PilotMainThrottle to 1.
print"Autopilot disengaged.".
set _51["lnd"]:Enabled to true.
}
}
else if _83:IsType("Button")and(_83:Pressed or _84:Pressed)
{
local _113 is(_55:altitudePosition(_57)-Ship:Body:Position).
local _114 is(_56:altitudePosition(_57)-Ship:Body:Position).
if _83:TakePress
{
set _6 to _55.
set _85 to _58.
}
else if _84:TakePress
{
set _6 to _56.
set _85 to mod(_58+180,360).
}
set _78 to _67.
set _61:Text to"Taxi to "+_f13(_85).
set _51["to"]:Enabled to false.
set _83:Enabled to false.
set _84:Enabled to false.
_f11().
set Ship:Control:PilotMainThrottle to 0.
if _20:IsType("part")and _21:IsType("part")
{
_20:GetModule("ModuleWheelBrakes"):SetField("brakes",25).
_21:GetModule("ModuleWheelBrakes"):SetField("brakes",25).
}
brakes on.
brakes off.
print _61:Text.
}
else if _51["to"]:TakePress
{
set _78 to _66.
set _61:Text to"Takeoff".
set _51["to"]:Enabled to false.
if _83:IsType("Button")
{
set _83:Enabled to false.
set _84:Enabled to false.
}
if _55:Distance<_56:Distance
set _79 to _56.
else
set _79 to _55.
set _62 to _79:Heading.
print"Takeoff from runway "+_f13(_62).
print"Engine start.".
_f10().
for rj in _14
rj:Part:Shutdown.
_f9(2).
if brakes and not _15:empty
{
print"Waiting for engines to spool.".
local _115 is 0.
for eng in _15
{
set _115 to _115+eng:part:PossibleThrust().
}
local _116 is 0.
until _116>_115*0.5
{
set _116 to 0.
for eng in _15
{
set _116 to _116+eng:part:Thrust().
}
wait 0.
}
}
brakes on.
brakes off.
print"Beginning takeoff roll.".
when alt:radar>=30 then{gear off.if _8>1 _f9(1).}
}
else if _78=_65 and Ship:Status="Flying"and Ship:Altitude>5000
{
print"Airlaunch detected".
set _51["to"]:Enabled to false.
set _61:Text to"Airlaunch".
if abs(_f4(_f0,_36))>10
set _51["hdg"]:Pressed to false.
set _62 to _f0.
_f10().
gear off.
brakes off.
set _78 to _66.
}
if _55:Distance<_56:Distance
{
set _51["rwy"]:Text to round(_55:Heading,1)+"° "+round(_55:Distance*0.001,1)+" km".
}
else
{
set _51["rwy"]:Text to round(_56:heading,1)+"° "+round(_56:Distance*0.001,1)+" km".
}
if Time:Seconds-_89>=1
{
local _117 is 0.
for r in Ship:Resources
{
if r:Density>0
set _117 to _117+r:Amount.
}
local _118 is(_88-_117)/(Time:Seconds-_89).
set _54:Text to round(1000*_118/Ship:GroundSpeed,2)+" / km".
set _88 to _117.
set _89 to Time:Seconds.
}
wait 0.
}
ClearGuis().
set Ship:Control:Neutralize to true.
