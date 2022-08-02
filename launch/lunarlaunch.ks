@lazyglobal off.

// Wait for unpack
wait until Ship:Unpacked.

switch to scriptpath():volume.

runoncepath("0:/launch/LASFunctions").

parameter flightTime is LAS_GetPartParam(Core:Part, "ft=", 4) * 24 * 3600.

// 4 day flight time
local flightTarget is Moon.

global function LAS_CalcLunarLaunch
{
    // Form a plane with the launch site, target, and earth centre in, use this as the orbital plane for launch
    local targetVec is (positionat(flightTarget, Time:Seconds + flightTime) - Ship:Body:Position):Normalized.
    local padVec is -Ship:Body:Position:Normalized.

    local orbitNorm is vcrs(targetVec, padVec):Normalized.
    local reqInc is arccos(vdot(orbitNorm, Ship:Body:AngularVel:Normalized)).
    if reqInc > 90
        set reqInc to 180 - reqInc.

    local launchAz is arcsin(max(-1, min(cos(reqInc)/cos(Ship:Latitude),1))).

    local northLaunchNorm is vcrs(heading(launchAz, 0):Vector, padVec):Normalized.
    local southLaunchNorm is vcrs(heading(180 - launchAz, 0):Vector, padVec):Normalized.

    global LAS_TargetInc is reqInc.
    if abs(vdot(northLaunchNorm, orbitNorm)) < abs(vdot(southLaunchNorm, orbitNorm))
        set LAS_TargetInc to -reqInc.
}

LAS_CalcLunarLaunch().
print "Orbit for " + flightTarget:Name + " intercept in " + round(flightTime / 86400, 1) + " days: " + round(abs(LAS_TargetInc), 2) + "° inc, " + (choose "south" if LAS_TargetInc < 0 else "north").

