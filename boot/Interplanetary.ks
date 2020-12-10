@lazyglobal off.

// 200 km circular orbit.
global LAS_TargetPe is 200.
global LAS_TargetAp is 200.

runpath("0:/launch/LaunchGUI").

local launchButton is LGUI_GetButton().
set launchButton:Text to "Confirm".
set launchButton:Enabled to false.

local targetBody is 0.
local flightTime is 100.

local bodyText is LGUI_CreateTextEdit("Target Body", "", { parameter str. set targetBody to (choose Body(str) if BodyExists(str) else 0). set launchButton:Enabled to targetBody:IsType("Body"). }).
local flightTimeText is LGUI_CreateTextEdit("Flight Time (days)", flightTime:ToString, { parameter str. set flightTime to str:ToNumber(flightTime). }).

LGUI_Show().

wait until launchButton:TakePress.
LGUI_Hide().

// Calc required inclination
runpath("0:/launch/CelestialLaunch", flightTime * 24 * 3600, targetBody).

runpath("0:/launch/LaunchAscentSystem.ks", -1, 0).
