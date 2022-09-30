@lazyglobal off.

parameter initialTarget.

local stepSize is 0.1.
local currentTarget is initialTarget.

until stepSize < 0.0001
{
    local p0 is currentTarget.
    
    local p1 is latlng(currentTarget:Lat, currentTarget:Lng + stepSize).
    local p2 is latlng(currentTarget:Lat, currentTarget:Lng - stepSize).
    local p3 is latlng(currentTarget:Lat + stepSize, currentTarget:Lng).
    local p4 is latlng(currentTarget:Lat - stepSize, currentTarget:Lng).
    
    if p1:TerrainHeight > p0:TerrainHeight
        set p0 to p1.
    if p2:TerrainHeight > p0:TerrainHeight
        set p0 to p2.
    if p3:TerrainHeight > p0:TerrainHeight
        set p0 to p3.
    if p4:TerrainHeight > p0:TerrainHeight
        set p0 to p4.
        
    if p0 = currentTarget
        set stepSize to stepSize / 10.
    else
        set currentTarget to p0.
}

print "Initial Position: " + round(initialTarget:Lat, 4) + ", " + round(initialTarget:Lng, 4) + " h=" + round(initialTarget:TerrainHeight, 1).
print "Highest Position: " + round(currentTarget:Lat, 4) + ", " + round(currentTarget:Lng, 4) + " h=" + round(currentTarget:TerrainHeight, 1).
