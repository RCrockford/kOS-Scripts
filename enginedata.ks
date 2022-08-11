@lazyglobal off.

// Wait for unpack
wait until Ship:Unpacked.

if addons:available("tf")
{
	local allEngines is list().
    list engines in allEngines.
    
    local symmetryEngines is list().
	
    for eng in allEngines
    {
        if symmetryEngines:Length = 0 and eng:SymmetryCount > 1
        {
            from {local i is 0.} until i >= eng:SymmetryCount step {set i to i + 1.} do
            {
                symmetryEngines:Add(list(eng:SymmetryPartner(i))).
            }
        }
        
        //print "Thrust: ":PadLeft(20) + eng:PossibleThrustAt(0).
        //print "MTBF: ":PadLeft(20) + Addons:TF:MTBF(eng).
        //print "FailRate: ":PadLeft(20) + Addons:TF:FailRate(eng).
        //print "Reliability: ":PadLeft(20) + Addons:TF:Reliability(eng, Addons:TF:RatedBurnTime(eng)).
        //print "RunTime: ":PadLeft(20) + Addons:TF:RunTime(eng).
        //print "RatedBurnTime: ":PadLeft(20) + Addons:TF:RatedBurnTime(eng).
        //print "IgnitionChance: ":PadLeft(20) + Addons:TF:IgnitionChance(eng).
        //print "Failed: ":PadLeft(20) + Addons:TF:Failed(eng).
    }
    
    for eng in symmetryEngines
    {
        local engPos is vxcl(Facing:Vector, eng[0]:Position).
        from {local i is 0.} until i >= eng[0]:SymmetryCount step {set i to i + 1.} do
        {
            local partnerPos is vxcl(Facing:Vector, eng[0]:SymmetryPartner(i):Position).
            local posTest is vdot(engPos, partnerPos).
            if abs(posTest + engPos:Mag^2) < engPos:Mag^2 * 0.01
            {
                eng:Add(eng[0]:SymmetryPartner(i)).
                break.
            }
        }
    }

    local i is 0.
    for eng in symmetryEngines
    {
        print "#" + i + " Pos: " + round(vdot(eng[0]:position, facing:upvector), 3) + ", " + round(vdot(eng[0]:position, facing:starvector), 3).
        print "  partner Pos: " + round(vdot(eng[1]:position, facing:upvector), 3) + ", " + round(vdot(eng[1]:position, facing:starvector), 3).
        set i to i + 1.
    }
}
