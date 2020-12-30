@lazyglobal off.

// Wait for unpack
wait until Ship:Unpacked.

switch to scriptpath():volume.

parameter flightTime is 0.
set flightTime to flightTime * 86400.

local lock LunarPos to positionat(Moon, Time:Seconds + flightTime).
local lock EarthPos to Body:Position.
local lock LunarOrbitNorm to Body:AngularVel:Normalized * AngleAxis(-Moon:Orbit:Inclination, (SolarPrimeVector * AngleAxis(Moon:Orbit:LAN, Body:AngularVel:Normalized)):Normalized).

local lock flightTargetL4 to (LunarPos - EarthPos) * AngleAxis(60, LunarOrbitNorm) + EarthPos.
local lock flightTargetL5 to (LunarPos - EarthPos) * AngleAxis(-60, LunarOrbitNorm) + EarthPos.

clearvecdraws().

global eL4Arrow is vecdraw({ return EarthPos. }, { return flightTargetL4 - EarthPos. }, RGB(1,0,0), "EL4", 1, true, 0.04, true, true).
global eL5Arrow is vecdraw({ return EarthPos. }, { return flightTargetL5 - EarthPos. }, RGB(1,0.5,0), "EL5", 1, true, 0.04, true, true).

global mL4Arrow is vecdraw({ return LunarPos. }, { return flightTargetL4 - LunarPos. }, RGB(0,1,0), "EL4", 1, true, 0.04, true, true).
global mL5Arrow is vecdraw({ return LunarPos. }, { return flightTargetL5 - LunarPos. }, RGB(0,1,0.5), "EL5", 1, true, 0.04, true, true).

wait until false.