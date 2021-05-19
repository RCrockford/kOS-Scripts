@lazyglobal off.

// Wait for unpack
wait until Ship:Unpacked.

if addons:available("tf")
{
	local allEngines is list().
    list engines in allEngines.
	
    for eng in allEngines
    {
        print eng:config.
        print "Thrust: ":PadLeft(20) + eng:PossibleThrustAt(0).
        print "MTBF: ":PadLeft(20) + Addons:TF:MTBF(eng).
        print "FailRate: ":PadLeft(20) + Addons:TF:FailRate(eng).
        print "Reliability: ":PadLeft(20) + Addons:TF:Reliability(eng, Addons:TF:RatedBurnTime(eng)).
        print "RunTime: ":PadLeft(20) + Addons:TF:RunTime(eng).
        print "RatedBurnTime: ":PadLeft(20) + Addons:TF:RatedBurnTime(eng).
        print "IgnitionChance: ":PadLeft(20) + Addons:TF:IgnitionChance(eng).
        print "Failed: ":PadLeft(20) + Addons:TF:Failed(eng).
    }
}
