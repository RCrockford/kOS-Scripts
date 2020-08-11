local function shipRoll
{
	local raw is vang(Ship:up:vector, -Ship:facing:starvector).
	if vang(Ship:up:vector, Ship:facing:topvector) > 90 {
		if raw > 90 {
			return raw - 270.
		} else {
			return raw + 90.
		}
	} else {
		return 90 - raw.
	}
}

local rollPid is PIDloop(0.01, 0.0005, 0.02, -1, 1).
set rollPid:SetPoint to 0.

until false
{
	wait 0.1.

	set ship:control:roll to rollPid:Update(time:seconds, shipRoll()).
}