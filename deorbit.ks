@lazyglobal off.

// Wait for unpack
wait until Ship:Unpacked.

lock throttle to 0.

print "Waiting for separation".

local startParts is Ship:Parts:Length.
wait until Ship:Parts:Length < startParts.

print "Deorbiting stage".

wait 5.

rcs on.
lock steering to retrograde.

wait until vdot(Facing:Vector, Retrograde:Vector) > 0.999.

set ship:control:fore to 1.
wait 5.

lock throttle to 1.
for eng in ship:engines
    eng:Activate.

wait until false.