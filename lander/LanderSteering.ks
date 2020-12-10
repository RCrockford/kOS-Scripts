@lazyglobal off.

// Wait for unpack
wait until Ship:Unpacked.

local targetPos is 0.
local minDist is Body:Radius / 2 + Ship:Altitude.
local targetName is 0.

global function LanderSelectWP
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

	if targetPos:IsType("GeoCoordinates")
		print "Landing Target: " + targetName.
}

global function LanderSteering
{
	parameter pCurrent is -Body:Position.
	parameter vCurrent is Ship:Velocity:Surface.
    parameter steerMul is 0.1.
    
	local horizVec is -vxcl(Up:Vector, vCurrent):Normalized.
	
    // Steer to target
    if targetPos:IsType("GeoCoordinates")
    {
        local targetVec is vxcl(Up:Vector, (targetPos:Position - Ship:Body:Position) - pCurrent).
        local steerVec is (targetVec:Normalized + horizVec):Normalized.
        
        set horizVec to (horizVec + steerVec * min(abs(vang(targetVec:Normalized, -horizVec)) * steerMul, 0.08)):Normalized.
    }
    
    return horizVec.
}

global function LanderTargetPos
{
    return targetPos.
}
