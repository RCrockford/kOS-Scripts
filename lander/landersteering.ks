@lazyglobal off.

// Wait for unpack
wait until Ship:Unpacked.

local targetPos is 0.
local minDist is Body:Radius / 2 + Ship:Altitude.
local targetName is 0.
local steerPID is PIDLoop(0.1, 0, 0.04, -0.1, 0.1).

global function LanderSelectWP
{
    parameter manualTarget is 0.

    if manualTarget:IsType("Vessel")
    {
        local offsetVec is vcrs(manualTarget:Position, manualTarget:Position - Body:Position):Normalized.
        set targetPos to Body:GeoPositionOf(manualTarget:Position + offsetVec * 20).
        set targetName to manualTarget:Name.
    }
    if manualTarget:IsType("GeoCoordinates")
    {
        set targetPos to manualTarget.
        set targetName to "Lat/Lng".
    }
    else
    {
        for wp in AllWayPoints()
        {
            if wp:Body = Body
            {
                if wp:IsSelected
                {
                    set targetPos to wp:GeoPosition.
                    set targetName to wp:Name.
                    break.
                }
                local wpBearing is vang(wp:GeoPosition:Position, Ship:Velocity:Surface).
                if wpBearing < 10 and wp:geoPosition:Distance < minDist
                {
                    set targetName to wp:Name.
                    set targetPos to wp:GeoPosition.
                    set minDist to wp:geoPosition:Distance.
                }
            }
        }
    }

	if targetPos:IsType("GeoCoordinates")
		print "Landing Target: " + targetName + " @ " + round(targetPos:Lat, 2) + ", " + round(targetPos:Lng, 2) + "; " + round(targetPos:TerrainHeight, 1) + "m".
}

global function LanderSteering
{
	parameter pCurrent is -Body:Position.
	parameter vCurrent is Ship:Velocity:Surface.
    parameter steerMul is 0.1.
    
	local horizVec is -vxcl(Up:Vector, vCurrent):Normalized.
    local dataLex is lexicon().
	
    // Steer to target
    if targetPos:IsType("GeoCoordinates")
    {
        local targetVec is vxcl(Up:Vector, (targetPos:Position - Ship:Body:Position) - pCurrent).
        local steerVec is (targetVec:Normalized + horizVec):Normalized.
        
        set steerPID:kP to steerMul.
        set steerPID:kD to steerMul * 0.2.
        
        local ang is abs(vang(targetVec:Normalized, -horizVec)).
        local f is -steerPID:Update(Time:Seconds, ang).
        
        dataLex:Add("mul", steerMul).
        dataLex:Add("ang", ang).
        dataLex:Add("f", f).
        
        set horizVec to (horizVec + steerVec * f):Normalized.
    }
    dataLex:Add("vec", horizVec).
    
    return dataLex.
}

global function LanderTargetPos
{
    return targetPos.
}
