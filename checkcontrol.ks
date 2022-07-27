@lazyglobal off.

// Wait for unpack
wait until Ship:Unpacked.

local totalControlled is 0.
for a in Ship:ModulesNamed("ModuleProceduralAvionics")
{
    local controllable is choose a:GetField("controllable") if a:HasField("Controllable") else 0.
    set totalControlled to totalControlled + controllable.
}
for a in Ship:ModulesNamed("ModuleAvionics")
{
    local controllable is choose a:GetField("controllable") if a:HasField("Controllable") else 0.
    set totalControlled to totalControlled + controllable.
}

if Ship:Mass < totalControlled
    print "Have avionics for control.".
else 
    print "Insufficient avionics for control.".
print "   M=" + round(Ship:Mass, 3) + " C=" + round(totalControlled, 3).