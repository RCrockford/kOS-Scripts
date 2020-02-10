@lazyglobal off.
wait until Ship:Unpacked.
local p is readjson("1:/burn.json").
runpath("/flight/EngineMgmt",stage:number).
local _0 is EM_IgDelay().
print"Align in "+round(Eta:Apoapsis-p:t*0.5-60,1)+"s".
wait until Eta:Apoapsis-p:t*0.5<60.
print"Aligning ship".
LAS_Avionics("activate").
rcs on.
lock steering to LookDirUp(p:dV,Facing:UpVector).
wait until Eta:Apoapsis<=p:t*0.5+_0.
print"Starting burn".
EM_Ignition().
wait until Ship:Obt:SemiMajorAxis>=35786000 or not EM_CheckThrust(0.1).
EM_Shutdown().
