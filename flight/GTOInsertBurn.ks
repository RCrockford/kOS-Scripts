@lazyglobal off.
wait until Ship:Unpacked.
local p is readjson("1:/burn.json").
runpath("/flight/EngineMgmt",stage:number).
local _0 is EM_IgDelay().
local lock _f0 to mod(360-(Ship:Orbit:ArgumentOfPeriapsis+Ship:Orbit:TrueAnomaly),180).
local _1 is _f0*Ship:Orbit:Period/360.
print"Align in "+round(_1-p:t*0.5-60,1)+"s".
local _2 is(p:t*0.5+60)*180/Ship:Orbit:Period.
local _3 is(p:t*0.5+_0)*180/Ship:Orbit:Period.
wait until _f0<=_2.
print"Aligning ship".
LAS_Avionics("activate").
rcs on.
lock steering to LookDirUp(Retrograde:Vector,Facing:UpVector).
wait until _f0<=_3.
print"Starting burn".
EM_Ignition().
wait until Ship:Obt:Apoapsis>=35786000 or not EM_CheckThrust(0.1).
EM_Shutdown().
