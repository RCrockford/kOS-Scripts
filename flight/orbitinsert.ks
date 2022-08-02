// Minimal orbital insertion burn from flyby using engines
// Just burns all fuel retrograde at periapsis

@lazyglobal off.

// Wait for unpack
wait until Ship:Unpacked.

// Approximate burn timing
local activeEngines is list().
list engines in activeEngines.

local ResourcesLex is lexicon().
for r in Ship:Resources
    ResourcesLex:Add(r:Name, r:Amount).

local burnTime is 1000.
for eng in activeEngines
{
    for k in eng:ConsumedResources:keys
    {
        local r is eng:ConsumedResources[k].
        if ResourcesLex:HasKey(r:Name)
            set burnTime to min(burnTime, ResourcesLex[r:Name] / r:MaxFuelFlow).
        else
            set burnTime to 0.
    }
}

print "Executing manoeuvre at Pe-" + round(burnTime * 0.5, 1) + " seconds.".
print "  Duration: " + round(burnTime, 1) + " s.".

local burnEta is Eta:Periapsis - burnTime * 0.5.
if burnEta > 240 and Addons:Available("KAC")
{
    // Add a KAC alarm.
    AddAlarm("Raw", burnEta - 180 + Time:Seconds, Ship:Name + " Manoeuvre", Ship:Name + " is nearing its next manoeuvre").
}

local burnParams is lexicon(
    "t", burnTime
).

runpath("0:/flight/SetupBurn", burnParams, list("flight/OrbitInsertBurn.ks")).
