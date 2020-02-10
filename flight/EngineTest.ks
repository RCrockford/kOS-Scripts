// Minimal insertion burn - target <= 880 bytes
wait until Ship:Unpacked.

local n is list().
list engines in n.

local avionics is Ship:ModulesNamed("ModuleProceduralAvionics").

// Align
for a in avionics
    if a:HasEvent("activate avionics")
        a:DoEvent("activate avionics").

rcs on.
lock steering to LookDirUp(Retrograde:Vector, Facing:UpVector).

wait until abs(SteeringManager:AngleError) < 0.2 and (Ship:AngularVel:SqrMagnitude - (vdot(Ship:Facing:Vector, Ship:AngularVel)^2) < 1e-4).

// Ullage
set Ship:Control:Fore to 1.

print n[0]:config + " " + round(n[0]:FuelStability * 100, 1) + "%".

wait 0.

print n[0]:config + " " + round(n[0]:FuelStability * 100, 1) + "%".

for e in n
    wait until e:FuelStability >= 0.99.

print n[0]:config + " " + round(n[0]:FuelStability * 100, 1) + "%".

set Ship:Control:MainThrottle to 1.

// Ignition
for e in n
    e:Activate.
	
until n[0]:Thrust > n[0]:PossibleThrust * 0.5
{
	print n[0]:config + " " + round(n[0]:FuelStability * 100, 1) + "% thr=" + round(100 * n[0]:Thrust / n[0]:PossibleThrust, 1) + "%".
	wait 0.
}

set Ship:Control:Fore to 0.

wait until n[0]:Flameout.

// Cutoff engines
for e in n
    e:Shutdown.

unlock steering.
set Ship:Control:Neutralize to true.
rcs off.

for a in avionics
    if a:HasEvent("shutdown avionics")
        a:DoEvent("shutdown avionics").

