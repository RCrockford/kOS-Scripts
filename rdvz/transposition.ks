// Docking active side
@lazyglobal off.

// Wait for unpack
if not Ship:Unpacked
{
    print "Wait for Unpack".
    wait until Ship:Unpacked.
}

parameter stageToDecouple is true.

local tPort is 0.
local portList is Ship:DockingPorts.

if Ship:PartsTagged("transpos"):Length > 0
{
    local decoupler is Ship:PartsTagged("transpos")[0].
    print "Decoupling " + decoupler:title.

    if stageToDecouple
    {
        stage.
    }
    else if decoupler:HasModule("ModuleDecouple")
    {
        decoupler:GetModule("ModuleDecouple"):DoEvent("decouple").
        wait 0.
    }
}

for p in portList
{
    if p:Ship <> ship
    {
        set tPort to p.
        break.
    }
}

local port is choose Ship:DockingPorts[0] if Ship:DockingPorts:Length > 0 else Ship:rootpart.

if port:IsType("DockingPort")
{
    print "Controlling from " + port:Title.
    port:ControlFrom().
}

local portDist is port:Position:Mag + 1.

if not (tPort:IsType("Part") or tPort:IsType("Vessel"))
{
    if not HasTarget
    {
        print "Waiting for target.".
        wait until hastarget.
    }
    set tPort to target.
}
else
{
    set target to tPort.
}

local tShip is tPort.
if tShip:IsType("Part")
{
    set tShip to tPort:Ship.
}

print "Detached from LV".

switch to scriptpath():volume.

runpath("/rdvz/RdvzFuncs").

LAS_Avionics("activate").
rcs on.

local clearDist is ship:Bounds:Size:Mag * 2.

if vdot(Facing:Vector, tPort:Position:Normalized) < 0.99
{
    Rdvz_SetStatus("Thrusting clear").
    Rdvz_TargetApproach({ return tPort:Position + tPort:Facing:Vector * clearDist * 0.6. }, { return -tPort:Position. }).
}

Rdvz_SetStatus("Lining up").
Rdvz_TargetApproach({ return tPort:Position + tPort:Facing:Vector * clearDist. }, { return tPort:Position. }).

local lock TargetPos to tPort:Position + tPort:Facing:Vector * portDist.

until vdot(tPort:Position:Normalized, tPort:Facing:Vector) < -0.99 and vdot(tPort:Position:Normalized, Facing:Vector) > 0.99
{
    Rdvz_UpdateReadouts(TargetPos@).
}

local startElements is Ship:Elements:Length.

until Ship:Elements:Length > startElements
{
    Rdvz_SetStatus("Docking").
    Rdvz_TargetApproach(TargetPos@, { return tPort:Position. }, 0.25, 1, 0.5).
    
    until Ship:Elements:Length > startElements
    {
        wait 0.
        local relV is Rdvz_UpdateReadouts(TargetPos@).
        if vdot(relV:Normalized, tPort:Position:Normalized) < 0
            break.
    }
}

unlock steering.
set Ship:Control:Neutralize to true.
rcs off.
LAS_Avionics("shutdown").

clearguis().