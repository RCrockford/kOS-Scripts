@lazyglobal off.

Core:DoEvent("Open Terminal").

// Wait for target to be set
print "Waiting for target.".
wait until hastarget.
local targetOrbit is Target:Orbit.

// Orbital matching with target.
global LAS_TargetPe is (targetOrbit:SemiMajorAxis - Ship:Body:Radius) / 1000.
if vdot(vcrs(Body:AngularVel:Normalized, -Body:Position:Normalized), (Target:Position - Body:Position):Normalized) > 0
    set LAS_TargetPe to LAS_TargetPe * 0.8.
else
    set LAS_TargetPe to LAS_TargetPe * 1.1.

set LAS_TargetPe to max(LAS_TargetPe, 150).
global LAS_TargetAp is LAS_TargetPe.

// If target orbit is unrealistically high, insert into an elliptic orbit.
if LAS_TargetPe > 280
{
	set LAS_TargetPe to 250.
	set LAS_TargetAP to targetOrbit:Apoapsis / 1000.
}

runpath("0:/launch/LaunchAscentSystem.ks", -1, targetOrbit).
