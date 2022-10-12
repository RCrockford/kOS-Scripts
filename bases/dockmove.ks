@lazyglobal off.

parameter liftoffHeight.
parameter steerSpeed is 1.

runoncepath("/fcfuncs").
runoncepath("/flight/tunesteering").
runpath("/flight/enginemgmt", Stage:Number).
set steeringmanager:maxstoppingtime to 2.

local heightKp is 0.5.
local heightKi is 0.01.
local heightKd is 0.25.

local speedKp is 2.
local speedKi is 0.1.
local speedKd is 0.2.

local heightPID is PIDLoop(heightKp, heightKi, heightKd, -4, 4).
local vSpeedPID is PIDLoop(speedKp, speedKi, speedKd, -1, 1).
local hSpeedPID is PIDLoop(0.25, 0.01, 0.25, -2, 2).
local steerPID is PIDLoop(1, 0.05, 0.6, -1, 1).

local LiftEngines is EM_GetEngines().
runpath("/lander/landerthrottle", LiftEngines, false, true).

runoncepath("/mgmt/readoutgui").
local readoutGui is RGUI_Create().
readoutGui:SetColumnCount(80, 3).

global Readouts is lexicon().

Readouts:Add("dist", readoutGui:AddReadout("Distance")).
Readouts:Add("hspeed", readoutGui:AddReadout("HSpeed")).
Readouts:Add("haccel", readoutGui:AddReadout("HAccel")).

Readouts:Add("throt", readoutGui:AddReadout("Throttle")).
Readouts:Add("vspeed", readoutGui:AddReadout("VSpeed")).
Readouts:Add("vaccel", readoutGui:AddReadout("VAccel")).

Readouts:Add("status", readoutGui:AddReadout("Status")).
Readouts:Add("alt", readoutGui:AddReadout("Target")).
Readouts:Add("height", readoutGui:AddReadout("Height")).

ReadoutGui:Show().

lock steering to lookdirup(Up:Vector, Facing:UpVector).

local dockTarget is target.

global TargetHeight is liftoffHeight.
global TargetOffs is V(0,0,0).
global FlyTarget is false.
global engineFailure is false.
global JitterPos is false.

local liftedOff is false.

global function ControlUpdate
{
    set HeightPID:SetPoint to TargetHeight.
    local localGrav is (Body:Mu / Body:Position:SqrMagnitude).
    local maxAccel is LanderMaxThrust() / Ship:Mass.
    
    set vSpeedPID:MinOutput to min(localGrav - maxAccel, -0.5).
    set vSpeedPID:MaxOutput to max(maxAccel - localGrav, 0.5).
    set HeightPID:MinOutput to vSpeedPID:MinOutput * 4.
    set HeightPID:MaxOutput to vSpeedPID:MaxOutput * 4.
    
    set vSpeedPID:SetPoint to heightPID:Update(Time:Seconds, -vdot(Up:Vector, dockTarget:Position)).
    local vAccel is vSpeedPID:Update(Time:Seconds, Ship:VerticalSpeed).
    
    local targetVec is choose vxcl(Up:Vector, dockTarget:Position + TargetOffs) if flyTarget else V(0,0,0).
    local targetSpeed is -hSpeedPID:Update(Time:Seconds, targetVec:Mag) * steerSpeed.
    
    local horizVel is vxcl(Up:Vector, Ship:Velocity:Surface).
    local targetVel is targetVec:Normalized * targetSpeed.
    local hAccel is steerPID:Update(Time:Seconds, (horizVel - targetVel):Mag).
    
    LanderSetThrottle((vAccel + localGrav) / maxAccel).
    
    set hAccel to hAccel * (horizVel - targetVel):Normalized.
    if vdot(horizVel, targetVel) < 0
        set hAccel to hAccel * 2.
    if JitterPos
    {
        set hAccel to hAccel + Facing:StarVector * (random() - 0.5) * 0.2.
        set hAccel to hAccel + Facing:TopVector * (random() - 0.5) * 0.2.
    }
    set ship:control:starboard to vdot(Facing:StarVector, hAccel).
    set ship:control:top to vdot(Facing:TopVector, hAccel).

    RGUI_SetText(Readouts:vspeed, round(vSpeedPID:SetPoint, 2) + " m/s", RGUI_ColourNormal).
    RGUI_SetText(Readouts:vaccel, round(vAccel, 2) + " m/s²", RGUI_ColourNormal).
    RGUI_SetText(Readouts:throt, round(100 * (vAccel + localGrav) / maxAccel, 1) + "%", RGUI_ColourNormal).

    RGUI_SetText(Readouts:hspeed, round(horizVel:Mag, 2) + " / " + round(targetSpeed, 2) + " m/s", RGUI_ColourNormal).
    RGUI_SetText(Readouts:haccel, round(100 * hAccel:Mag, 2) + "%", RGUI_ColourNormal).

    RGUI_SetText(Readouts:dist, round(targetVec:Mag, 2) + " m", RGUI_ColourNormal).
    RGUI_SetText(Readouts:alt, round(HeightPID:SetPoint, 2) + " m", RGUI_ColourNormal).
    RGUI_SetText(Readouts:height, round(-vdot(Up:Vector, dockTarget:Position), 2) + " m", RGUI_ColourNormal).
    
    if liftedOff
    {
        for eng in LiftEngines
        {
            if eng:Thrust < eng:MinThrottle * eng:PossibleThrust * 0.8
            {
                print "Engine " + eng:Title + " failed: " + round(eng:Thrust, 4) + " < " + round(eng:MinThrottle * eng:PossibleThrust, 4).
                set engineFailure to true.
            }
        }
    }

    return targetVec:Mag.
}

RGUI_SetText(Readouts:status, "Lift Off", RGUI_ColourNormal).

LAS_Avionics("activate").
rcs on.
LanderEnginesOn().

local liftoffTime is Time:Seconds + EM_IgDelay().

until engineFailure or vdot(Up:Vector, dockTarget:Position) < -liftoffHeight * 0.95
{
    if Time:Seconds > liftoffTime
        set liftedOff to true.
    ControlUpdate().
    wait 0.
}

if not engineFailure
{
    gear off.
    ladders off.
}

global function DockShutdown
{
    if engineFailure
    {
        print "Engine failure, aborting.".
    }

    LanderEnginesOff().
    unlock steering.
    set Ship:Control:Neutralize to true.
    rcs off.
    LAS_Avionics("shutdown").
    ClearGUIs().
}