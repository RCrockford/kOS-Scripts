// Docking active side
@lazyglobal off.

if not HasTarget
{
    print "Waiting for target.".
    wait until hastarget.
}

local tShip is target.
local tPort is target.

if tShip:IsType("DockingPort")
{
    set tShip to tShip:Ship.
}

// Wait for unpack
wait until Ship:Unpacked.

local port is choose Ship:DockingPorts[0] if Ship:DockingPorts:Length > 0 else 0.

if port:IsType("DockingPort")
{
    print "Controlling from " + port:Title.
    port:ControlFrom().
}
else
{
    set port to Ship:rootpart.
}

local portDist is port:Position:Mag + 1.

runpath("/rdvz/rdvzfuncs").

LAS_Avionics("activate").
rcs on.

Rdvz_SetStatus("Approaching").
Rdvz_TargetApproach({ return tPort:Position - tPort:Position:Normalized * (5 + portDist). }, { return tPort:Position. }, 1, max(1.2, min(Rdvz_GetMaxAccel() * 8, 4))).

local lock TargetPos to tPort:Position + tPort:Facing:Vector * portDist.

Rdvz_SetStatus("Lining up").
until vdot(tPort:Position:Normalized, tPort:Facing:Vector) < -0.99 and vdot(tPort:Position:Normalized, Facing:Vector) > 0.99
{
    Rdvz_UpdateReadouts(TargetPos@).
}

local startElements is Ship:Elements:Length.

Rdvz_SetStatus("Docking").
Rdvz_TargetApproach(TargetPos@, { return tPort:Position. }, 0.25, 1, 0.5, true).

until Ship:Elements:Length > startElements
{
    wait 0.
    local relV is Rdvz_UpdateReadouts(TargetPos@).
    if vdot(relV:Normalized, tPort:Position:Normalized) < 0
        break.
}

unlock steering.
set Ship:Control:Neutralize to true.
rcs off.
LAS_Avionics("shutdown").

clearguis().