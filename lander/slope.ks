@lazyglobal on.

local shipBounds is Ship:Bounds.

local starVec is Body:GeoPositionOf(shipBounds:Extents:Mag * Facing:StarVector):Position - Body:GeoPositionOf(-shipBounds:Extents:Mag * Facing:StarVector):Position.
local foreVec is Body:GeoPositionOf(shipBounds:Extents:Mag * Facing:ForeVector):Position - Body:GeoPositionOf(-shipBounds:Extents:Mag * Facing:ForeVector):Position.
local slopeVec is vcrs(foreVec, starVec):Normalized.
if vdot(slopeVec, Up:Vector) < 0
    set slopeVec to -slopeVec.

print vang(facing:vector, slopeVec).

local foreArrow is vecdraw(V(0,0,0), foreVec, RGB(1,0,0), "fore", 1.0, true, 0.05, true, true).
local starArrow is vecdraw(V(0,0,0), starVec, RGB(0,0,1), "star", 1.0, true, 0.05, true, true).
local slopeArrow is vecdraw(V(0,0,0), slopeVec * 4, RGB(0,1,0), "Slope", 1.0, true, 0.05, true, true).

wait until false.