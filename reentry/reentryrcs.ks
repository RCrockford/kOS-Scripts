@lazyglobal off.
wait until Ship:Unpacked.
local p is lexicon(open("1:/burn.csv"):readall:string:split(",")).
for k in p:keys
set p[k]to p[k]:ToScalar(0).
rcs on.
lock steering to LookDirUp(Retrograde:Vector,Facing:UpVector).
wait until vdot(Retrograde:Vector,Facing:Vector)>0.99999.
set Ship:Control:Fore to 1.
local _0 is Ship:mass.
until Ship:Obt:Periapsis<=p:pe
{
wait 0.1.
if _0=Ship:mass
{
print"Out of fuel.".
break.
}
set _0 to Ship:Mass.
}
runpath("/flight/reentrylanding").