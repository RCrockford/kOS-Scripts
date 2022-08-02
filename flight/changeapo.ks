// Change apoapsis using RCS or engines

@lazyglobal off.

parameter targetAp.
parameter useEngines is false.
parameter timeOffset is 0.

// Wait for unpack
wait until Ship:Unpacked.

runpath("0:/flight/ChangeApsis",
	Ship:Orbit:Periapsis + Ship:Body:Radius,
	targetAp * 1000 + Ship:Body:Radius,
	{ return Eta:Periapsis. },
	useEngines,
	timeOffset).
