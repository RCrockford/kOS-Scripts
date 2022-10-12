@lazyglobal off.

switch to scriptpath():volume.

runoncepath("/mgmt/readoutgui").

local readoutGui is RGUI_Create(800, -180).
readoutGui:SetColumnCount(100, 2).

local Readouts is lexicon().

Readouts:Add("dist", readoutGui:AddReadout("Distance")).
Readouts:Add("relv", readoutGui:AddReadout("Relative V")).
Readouts:Add("tarv", readoutGui:AddReadout("Target V")).
Readouts:Add("ang", readoutGui:AddReadout("Bearing")).
Readouts:Add("status", readoutGui:AddStatus()).

readoutGui:Show().

runoncepath("/fcfuncs").
runoncepath("/flight/rcsperf").
runpath("flight/tunesteering").

local rcsPerf is GetRCSPerf().

local maxAccel is max(0.1, min(rcsPerf:Aft:thrust / Ship:Mass, 4)).
local movePID is pidloop(1 / maxAccel, 0.01 / maxaccel, 0.25 / maxAccel, -1, 1).

local prevTVec is v(0,0,0).
local prevT is Time:Seconds.

global function Rdvz_TargetApproach
{
    parameter targetFunc.
    parameter headingFunc.
    parameter minSpeed is 0.
    parameter maxSpeed is maxAccel * 4.
    parameter stopDist is maxAccel.
    parameter docking is false.
    
    set prevTVec to targetFunc().
    set prevT to Time:Seconds.
    local relV is V(maxAccel * 10, 0, 0).
    
    local startElements is Ship:Elements:Length.
    
    lock steering to lookdirup(headingFunc(), Facing:UpVector).
    
    set minSpeed to max(minSpeed, maxAccel * 0.1).
    
    until (prevTVec:Mag < stopDist and relV:Mag < minSpeed) or (docking and Ship:Elements:Length > startElements)
    {
        wait 0.
        local tVec is targetFunc().
        set relV to (prevTVec - tVec) / (Time:Seconds - prevT).
        set prevT to Time:Seconds.
        set prevTVec to tVec.
        
        local targetSpeed is min(max(minSpeed, sqrt(maxAccel * max(tVec:Mag, 0.001))), maxSpeed).
        local targetVel is tVec:Normalized * targetSpeed.
        
        local correctVel is targetVel - relV.
        local correctSpeed is movePID:Update(Time:Seconds, -correctVel:Mag).
        set ship:control:translation to Facing:Inverse * (correctVel:Normalized * correctSpeed).

        RGUI_SetText(Readouts:dist, round(tVec:Mag, 1) + " m", RGUI_ColourNormal).
        RGUI_SetText(Readouts:relv, round(relV:Mag, 3) + " m/s", RGUI_ColourNormal).
        RGUI_SetText(Readouts:tarv, round(targetSpeed, 3) + " m/s", RGUI_ColourNormal).
        RGUI_SetText(Readouts:ang, round(vang(tVec, relV), 2) + "°", RGUI_ColourNormal).
    }
    
    set ship:control:translation to v(0,0,0).
}

global function Rdvz_UpdateReadouts
{
    parameter targetFunc.
    parameter targetSpeed is 0.

    local tVec is targetFunc().
    local relV is (prevTVec - tVec) / max(Time:Seconds - prevT, 1e-4).
    if prevTVec:SqrMagnitude < 0.01
        set relV to V(0,0,0).
    set prevT to Time:Seconds.
    set prevTVec to tVec.
    
    RGUI_SetText(Readouts:dist, round(tVec:Mag, 1) + " m", RGUI_ColourNormal).
    RGUI_SetText(Readouts:relv, round(relV:Mag, 3) + " m/s", RGUI_ColourNormal).
    RGUI_SetText(Readouts:tarv, round(targetSpeed, 3) + " m/s", RGUI_ColourNormal).
    RGUI_SetText(Readouts:ang, round(vang(tVec, Facing:Vector), 2) + "°", RGUI_ColourNormal).
    
    return relV.
}

global function Rdvz_SetStatus
{
    parameter status.
    RGUI_SetText(Readouts:status, status, RGUI_ColourNormal).
}

global function Rdvz_GetMaxAccel
{
    return maxAccel.
}
