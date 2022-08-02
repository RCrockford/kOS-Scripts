@lazyglobal off.

parameter ascentStage is stage:number.
parameter doLaunch is true.

if not hastarget
{
    print "Waiting for target.".
    wait until hastarget.
}
local targetOrbit is Target:Orbit.

local targetPe is (TargetOrbit:SemiMajorAxis - Body:Radius) * 0.5 + Body:Radius.
// Assume 30km is safe on airless bodies
if Body:Atm:Exists
    set targetPe to max(Body:Radius + Body:Atm:Height, min(targetPe, Body:Radius + Body:Atm:Height * 1.5)).
else
    set targetPe to max(Body:Radius + 30000, min(targetPe, Body:Radius * 1.025)).
local targetAp is max((TargetOrbit:SemiMajorAxis - Body:Radius) + Body:Radius, targetPe).
local a is (targetPe + targetAp) / 2.
local sinInertialAz is max(-1, min(cos(TargetOrbit:Inclination)/cos(Ship:Latitude),1)).
local vOrbit is sqrt(2 * Ship:Body:Mu / targetPe - Ship:Body:Mu / a).
local vEqRot is 2 * Constant:pi * Ship:Body:Radius / Ship:Body:RotationPeriod.
// Using the identity sin2 + cos2 = 1 to avoid inverse trig.
local launchAzimuth to mod(arctan2(vOrbit * sinInertialAz - vEqRot * cos(Ship:Latitude), vOrbit * sqrt(1 - sinInertialAz^2)) + 360, 360).

local orbitNorm is vcrs(targetOrbit:Position - Ship:Body:Position, targetOrbit:Velocity:Orbit):Normalized.
local padVec is -Ship:Body:Position:Normalized.
local northLaunchNorm is vcrs(heading(launchAzimuth, 0):Vector, padVec):Normalized.
local southLaunchNorm is vcrs(heading(mod(360 + 180 - launchAzimuth, 360), 0):Vector, padVec):Normalized.
local south is abs(vdot(northLaunchNorm, orbitNorm)) < abs(vdot(southLaunchNorm, orbitNorm)).
if south
    set launchAzimuth to mod(360 + 180 - launchAzimuth, 360).
    
set targetPe to (targetPe - Ship:Body:Radius) / 1000.
set targetAp to (targetAp - Ship:Body:Radius) / 1000.

switch to scriptpath():volume.

print "Launch azimuth for target: " + round(launchAzimuth, 2) + "°, Inclination: " + round(TargetOrbit:Inclination, 2) + "°".

if doLaunch
    runpath("/lander/landerascent", targetAp, targetPe, launchAzimuth, ascentStage, target).
else
    print "Periapsis: " + round(targetPe, 1) + " km Apoapsis: " + round(targetAp, 1) + " km".
