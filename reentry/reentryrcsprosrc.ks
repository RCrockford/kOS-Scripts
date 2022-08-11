@lazyglobal off.

wait until Ship:Unpacked.

local p is lexicon(open("1:/burn.csv"):readall:string:split(",")).
for k in p:keys
    set p[k] to p[k]:ToScalar(0).

rcs on.
lock steering to LookDirUp(Prograde:Vector, Facing:UpVector).

wait until vdot(Prograde:Vector, Facing:Vector) > 0.99999.

set Ship:Control:Fore to -1.

local shipMass is Ship:mass.
until Ship:Obt:Periapsis <= p:pe
{
	wait 0.1.
	if shipMass = Ship:mass
	{
		print "Out of fuel.".
		break.
	}
	set shipMass to Ship:Mass.
}

runpath("/flight/reentrylanding").
