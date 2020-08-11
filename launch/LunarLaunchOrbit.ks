@lazyglobal off.

// Wait for unpack
wait until Ship:Unpacked.

// 4 day flight time
parameter flightTime is 4 * 24 * 3600.

// Form a plane with the launch site, moon and earth centre in, use this as the orbital plane for launch
local MoonVec is (positionat(Moon, Time:Seconds + flightTime) - Ship:Body:Position):Normalized.
local padVec is -Ship:Body:Position:Normalized.

local orbitNorm is vcrs(MoonVec, padVec):Normalized.
local reqInc is arccos(vdot(orbitNorm, Ship:Body:AngularVel:Normalized)).
if reqInc > 90
	set reqInc to 180 - reqInc.

local launchAz is arcsin(max(-1, min(cos(reqInc)/cos(Ship:Latitude),1))).

local northLaunchNorm is vcrs(heading(launchAz, 0):Vector, padVec):Normalized.
local southLaunchNorm is vcrs(heading(180 - launchAz, 0):Vector, padVec):Normalized.

local south is abs(vdot(northLaunchNorm, orbitNorm)) < abs(vdot(southLaunchNorm, orbitNorm)).

print "Orbit for Moon intercept in " + round(flightTime / 86400, 1) + " days: " + round(reqInc, 2) + "° inc, " + (choose "south" if south else "north").