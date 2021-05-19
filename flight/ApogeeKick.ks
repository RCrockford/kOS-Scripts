@lazyglobal off.

wait until Ship:Unpacked.

parameter margin is 2.

local lock burnEta to eta:Apoapsis.

runoncepath("/FCFuncs").

runpath("/flight/AlignTime").
local alignMargin is GetAlignTime().

print "Align in " + round(burnEta - margin - alignMargin, 1) + "s (T-" + round(alignMargin, 1) + ")".

wait until burnEta <= alignMargin + margin.

kUniverse:Timewarp:CancelWarp().
print "Aligning ship".

LAS_Avionics("activate").

rcs on.
lock steering to LookDirUp(Prograde:Vector, Facing:UpVector).

until burnEta <= margin
{
    if vdot(Prograde:Vector, Facing:Vector) > 0.99
    {
        // spin up
        local rollRate is vdot(Facing:Vector, Ship:AngularVel).
        local cmdroll is -1.
        if abs(rollRate) > 2.5
        {
            set cmdroll to 0.1.
        }
        else if abs(rollRate) > 2
        {
            set cmdroll to -0.1.
        }
        set ship:control:roll to cmdroll.
    }
    wait 0.
}

print "Starting burn".
set Ship:Control:Neutralize to true.
rcs off.
stage.

LAS_Avionics("shutdown").