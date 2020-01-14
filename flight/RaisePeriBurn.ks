@lazyglobal off.
wait until Ship:Unpacked.
local p is readjson("1:/burn.json").
runpath("/flight/EngineMgmt",stage:number).
local _0 is EM_GetEngines().
local _1 is EM_IgDelay().
print"Align in "+round(Eta:Apoapsis-p:t*0.5-60,1)+"s".
wait until Eta:Apoapsis-p:t*0.5<60.
print"Aligning ship".
LAS_Avionics("activate").
rcs on.
lock steering to Ship:Prograde.
wait until Eta:Apoapsis<=p:t*0.5+_1.
print"Starting burn".
EM_Ignition().
wait until Ship:Obt:Periapsis>=p:pe or _0[0]:Thrust<_0[0]:PossibleThrust*0.1.
set Ship:Control:PilotMainThrottle to 0.
for eng in _0
{
eng:Shutdown.
}
print"MECO".
unlock steering.
set Ship:Control:Neutralize to true.
rcs off.
LAS_Avionics("shutdown").
