// Change periapsis using RCS or engines

@lazyglobal off.

parameter targetPe.
parameter useEngines is false.
parameter timeOffset is 0.

// Wait for unpack
wait until Ship:Unpacked.

runpath("0:/flight/changeapsis",
	Ship:Orbit:Apoapsis + Ship:Body:Radius,
	targetPe * 1000 + Ship:Body:Radius,
	{ return Eta:Apoapsis. },
	useEngines,
	timeOffset).
