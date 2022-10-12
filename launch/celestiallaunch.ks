@lazyglobal off.

// Wait for unpack
wait until Ship:Unpacked.

switch to scriptpath():volume.

Core:DoEvent("Open Terminal").

clearguis().

runoncepath("0:/launch/lasfunctions").
runoncepath("0:/launch/lambert").

runpath("0:/launch/launchgui").

set Terminal:Height to max(Terminal:Height, 50).

local calcButton is LGUI_GetButton().
set calcButton:Text to "Calculate".
set calcButton:Enabled to false.

local launchButton is LGUI_CreateButton("Confirm").
set launchButton:Enabled to false.

local targetBody is 0.
local minFlightTime is 0.
local maxFlightTime is 0.
local maxEjectionΔV is 0.
local planningSMA is Body:Radius + 200000.

local bodyText is LGUI_CreateTextEdit("Target Body", "", {}).
local minFlightTimeText is LGUI_CreateTextEdit("Min Flight Time (days)", minFlightTime:ToString, { parameter str. set minFlightTime to str:ToNumber(minFlightTime). }).
local maxFlightTimeText is LGUI_CreateTextEdit("Max Flight Time (days)", maxFlightTime:ToString, { parameter str. set maxFlightTime to str:ToNumber(maxFlightTime). }).
local maxEjectionΔVText is LGUI_CreateTextEdit("Max Ejection ΔV", maxEjectionΔV:ToString, { parameter str. set maxEjectionΔV to str:ToNumber(maxEjectionΔV). }).
local minimiseEjection is LGUI_CreateCheckbox("Minimal ejection cost"). set minimiseEjection:Exclusive to true.
local minimiseInsertion is LGUI_CreateCheckbox("Minimal insertion cost"). set minimiseInsertion:Exclusive to true.
local minimiseTime is LGUI_CreateCheckbox("Minimal flight time"). set minimiseTime:Exclusive to true.

local function SelectNewTarget
{
    parameter str.

    if BodyExists(str)
    {
        if targetBody <> Body(str)
        {
            set targetBody to Body(str).

            local transferA is (Body:Orbit:SemiMajorAxis + targetBody:Orbit:SemiMajorAxis) / 2.
            local hohmannTransferTime is Constant:PI * sqrt(transferA^3 / Sun:Mu).
            local minTime is Max(hohmannTransferTime - targetBody:Orbit:Period, hohmannTransferTime / 2).
            set minFlightTimeText:Text to round(minTime / 86400, 1):ToString.
            minFlightTimeText:OnConfirm(minFlightTimeText:Text).
            set maxFlightTimeText:Text to round((minTime + Min(2 * targetBody:Orbit:Period, hohmannTransferTime * 1.5)) / 86400, 1):ToString.
            maxFlightTimeText:OnConfirm(maxFlightTimeText:Text).
        }

        set calcButton:Enabled to true.
    }
    else
    {
        set calcButton:Enabled to false.
    }
    set launchButton:Enabled to false.
}

set bodyText:OnConfirm to SelectNewTarget@.



local function GetLaunchAngleRendezvous
{
    parameter targetOrbit.

	// From KER / MJ2
	local bodyAngVel is Ship:Body:AngularVel:Normalized.
	local lanVec is (SolarPrimeVector * AngleAxis(TargetOrbit:LAN, bodyAngVel)):Normalized.
	local orbitNormal is bodyAngVel * AngleAxis(-TargetOrbit:Inclination, lanVec).

	local inc is abs(vang(orbitNormal, bodyAngVel)).
	local bVec is vxcl(bodyAngVel, orbitNormal):Normalized.
	set bVec to bVec * Ship:Body:Radius * sin(Ship:Latitude) / tan(inc).

	local cVec is vcrs(orbitNormal, bodyAngVel):Normalized.
	local cMagSq is (Ship:Body:Radius * cos(Ship:Latitude)) ^ 2 - bVec:SqrMagnitude.
	set cMagSq to choose 0 if cMagSq <= 0 else sqrt(cMagSq).
	set cVec to cVec * cMagSq.

	local aVec1 is bVec + cVec.
	local aVec2 is bVec - cVec.

	local longVec is (LatLng(0,Ship:Longitude):Position - Ship:Body:Position):Normalized.

	local angle1 is abs(vang(longVec, aVec1)).
	if vdot(vcrs(longVec, aVec1), bodyAngVel) < 0
		set angle1 to 360 - angle1.

	local angle2 is abs(vang(longVec, aVec2)).
	if vdot(vcrs(longVec, aVec2), bodyAngVel) < 0
		set angle2 to 360 - angle2.

	return min(angle1, angle2).
}

local function FindBestLaunchLAN
{
    parameter launchInc.
    parameter ejectV.

    local yDir is vdot(ejectV:Normalized, -Body:AngularVel:Normalized).
    local ejectAngle is arccos(min(max(-1, yDir / sin(launchInc)), 1)).

    local radial is sin(ejectAngle) * sin(LaunchInc) * Body:AngularVel:Normalized.
    set radial to radial + sqrt(1 - radial:SqrMagnitude) * vxcl(Body:AngularVel:Normalized, ejectV:Normalized) * angleaxis(90, Body:AngularVel:Normalized).
    local orbitNorm is -vcrs(ejectV:Normalized, radial:Normalized):Normalized.

    local lanVec is vcrs(Body:AngularVel:Normalized, orbitNorm).
    local launchLAN is vang(SolarPrimeVector, lanVec).
    if vdot(vcrs(lanVec, SolarPrimeVector), Body:AngularVel:Normalized) > 0
        set launchLAN to 360 - launchLAN.

    local parkingOrbit is CreateOrbit(launchInc, 0, planningSMA, launchLAN, ejectAngle, 0, Time:Seconds, Body).
    local ejectΔV is ejectV - parkingOrbit:Velocity:Orbit.

    local ejectAngle2 is 360 - ejectAngle.
    set radial to sin(ejectAngle2) * sin(LaunchInc) * Body:AngularVel:Normalized.
    set radial to radial + sqrt(1 - radial:SqrMagnitude) * vxcl(Body:AngularVel:Normalized, ejectV:Normalized) * angleaxis(90, Body:AngularVel:Normalized).
    set orbitNorm to -vcrs(ejectV:Normalized, radial:Normalized):Normalized.

    set lanVec to vcrs(Body:AngularVel:Normalized, orbitNorm).
    local launchLAN2 to vang(SolarPrimeVector, lanVec).
    if vdot(vcrs(lanVec, SolarPrimeVector), Body:AngularVel:Normalized) > 0
        set launchLAN2 to 360 - launchLAN2.

    local parkingOrbit2 is CreateOrbit(launchInc, 0, planningSMA, launchLAN2, ejectAngle2, 0, Time:Seconds, Body).
    local ejectΔV2 is ejectV - parkingOrbit:Velocity:Orbit.

    if GetLaunchAngleRendezvous(parkingOrbit) < GetLaunchAngleRendezvous(parkingOrbit2)
        return list(launchLAN, ejectΔV:Mag, ejectAngle).
    else
        return list(launchLAN2, ejectΔV2:Mag, ejectAngle2).
}

local function FindBestFlightTime
{
    local minTime is minFlightTime.
    local maxTime is maxFlightTime.

    local bestSolveVInf is 1e6.
    local bestSolveVIns is 1e6.
    local bestSolveEjΔV is 1e6.
    local bestSolveFT is 0.

    from { local timeStep to max((maxFlightTime - minFlightTime) / 10, 0.1). } until timeStep < 0.1 step { set timeStep to timeStep / 2. } do
    {
        set bestSolveVInf to V(1e6,0,0).
        set bestSolveVIns to 1e6.
        set bestSolveFT to maxTime.
        from { local ft to minTime. } until ft > maxTime step { set ft to ft + timeStep. } do
        {
            from { local invert to 0. } until invert > 1 step { set invert to invert + 1. } do
            {
                local solvedV is lambert(Body:Position - Sun:Position, positionat(targetBody, Time:Seconds + ft * 86400) - Sun:Position, ft * 86400, Sun:Mu, invert > 0).
                local reqV is solvedV:v1 - Body:Orbit:Velocity:Orbit.
                local vIns is (solvedV:v2 - velocityat(targetBody, Time:Seconds + ft * 86400):Orbit):Mag.

                local newSolution is false.
                if minimiseEjection:Pressed
                {
                    set newSolution to reqV:Mag < bestSolveVInf:Mag.
                }
                else if minimiseInsertion:Pressed or minimiseTime:Pressed
                {
                    if minimiseInsertion:Pressed
                        set newSolution to vIns < bestSolveVIns.
                    else
                        set newSolution to ft < bestSolveFT.

                    if maxEjectionΔV > 0
                    {
                        local ejectV is reqV:Normalized * sqrt(reqV:SqrMagnitude + (2 * Body:Mu / planningSMA)).
                        local ejectInc is (90 - vang(ejectV:Normalized, Body:AngularVel:Normalized)).
                        if ejectInc < 0
                            set ejectInc to -ejectInc.

                        local BestLAN is FindBestLaunchLAN(max(ejectInc, abs(Ship:Latitude)), ejectV).
                        
                        if bestSolveEjΔV > maxEjectionΔV and BestLAN[1] < bestSolveEjΔV
                        {
                            set newSolution to true.
                        }
                        else if newSolution
                        {
                            if BestLAN[1] > maxEjectionΔV and bestSolveEjΔV <= maxEjectionΔV
                                set newSolution to false.
                        }
                        if newSolution
                            set bestSolveEjΔV to BestLAN[1].
                    }
                }
                else
                {
                    set newSolution to vIns + reqV:Mag < bestSolveVIns + bestSolveVInf:Mag.
                }

                if newSolution
                {
                    //print "Accept solution: eV=" + round(reqV:Mag, 1) + " iV=" + round(vIns, 1) + " ft=" + round(ft, 2).
                    set bestSolveVInf to reqV.
                    set bestSolveVIns to vIns.
                    set bestSolveFT to ft.
                }
                else
                {
                    //print "Reject solution: eV=" + round(reqV:Mag, 1) + " iV=" + round(vIns, 1) + " ft=" + round(ft, 2).
                }
            }
        }

        set minTime to max(BestSolveFT - timeStep, minFlightTime).
        set maxTime to min(BestSolveFT + timeStep, maxFlightTime).
    }

    return list(BestSolveFT, BestSolveVInf, bestSolveVIns).
}

local function FormatFlightTime
{
    parameter flightTime.
    
    if flightTime > 400
    {
        return floor(flightTime / 365) + " years, " + round(mod(flightTime, 365) / 30, 0) + " months".
    }
    return round(mod(flightTime, 365) / 30, 1) + " months".
}

LGUI_Show().

from {local s is stage:number.} until s < 0 step {set s to s - 1.} do
{
    local stagePerf is LAS_GetStagePerformance(s, false).
    if stagePerf:eV > 0
        print "S" + s + " ΔV: " + round(stagePerf:eV * ln(stagePerf:WetMass / stagePerf:DryMass), 1) + " m/s".
}

local launchLAN is 0.
local launchInc is 0.

if BodyExists(Ship:Name:Split(" ")[0])
{
    set bodyText:Text to Ship:Name:Split(" ")[0].
    bodyText:OnConfirm(bodyText:Text).
    set calcButton:Pressed to calcButton:Enabled.
}

until false
{
    wait until calcButton:Pressed or LaunchButton:Pressed.

    if LaunchButton:Pressed
        break.
    set calcButton:Pressed to false.

    print "Calculating optimum flight time to " + targetBody:Name.

    local flightTime is FindBestFlightTime().
    print "Optimum flight time: " + round(flightTime[0], 2) + " days (" + FormatFlightTime(flightTime[0]) + ")".
    print "Flyby velocity: " + round(flightTime[2], 1) + " m/s".

    local ejectV is flightTime[1]:Normalized * sqrt(flightTime[1]:SqrMagnitude + (2 * Body:Mu / planningSMA)).
    local ejectInc is 90 - vang(ejectV:Normalized, Body:AngularVel:Normalized).
    set ejectInc to max(abs(ejectInc), abs(Ship:Latitude)).

    print "Launch inclination: " + round(ejectInc, 2) + "°".

    local BestLAN is FindBestLaunchLAN(ejectInc, ejectV).
    print "Launch LAN: " + round(BestLAN[0], 2) + "°, Ejection ΔV: " + round(BestLAN[1], 1) + " m/s, Angle: " + round(BestLAN[2], 2) + "°".

    set launchLAN to BestLAN[0].
    set launchInc to ejectInc.

    set launchButton:Enabled to true.
    set launchButton:Pressed to false.
}

LGUI_Hide().

global LAS_TargetInc is launchInc.
global LAS_TargetLAN is launchLAN.

runpath("0:/launch/launchascentsystem.ks", -1, 0).
