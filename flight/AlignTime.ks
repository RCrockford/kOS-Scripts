@lazyglobal off.

// Wait for unpack
wait until Ship:Unpacked.

switch to scriptpath():volume.

// Calc moment of inertia in each axis
local pitchMoI is 0.
local yawMoI is 0.
for p in ship:parts
{
    set pitchMoI to pitchMoI + p:Mass * vxcl(Ship:ControlPart:Facing:StarVector, p:Position):SqrMagnitude.
    set yawMoI to yawMoI + p:Mass * vxcl(Ship:ControlPart:Facing:UpVector, p:Position):SqrMagnitude.
}

runoncepath("/flight/RCSPerf.ks").
local RCSPerf is GetRCSPerf().

local minAccel is min(RCSPerf:Star:Torque / pitchMoI, RCSPerf:Up:Torque / yawMoI).
local SteerTime is Constant:pi / (2 * minAccel).

global function GetAlignTime
{
    // Round to nearest 5 seconds, 20 second margin for time warp and settling.
    return round(SteerTime / 5 + 4, 0) * 5 + 20.
}
