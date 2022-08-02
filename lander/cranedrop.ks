@lazyglobal off.

print "Waiting for drop".

wait until Ship:Status = "Landed" or Ship:Status = "Splashed".

print "Touchdown speed: " + round(-Ship:VerticalSpeed, 2) + " m/s".
set Ship:Control:Neutralize to true.
rcs off.
brakes on.

local evt is "shutdown avionics".
for a in Ship:ModulesNamed("ModuleProceduralAvionics")
{
    if a:HasEvent(evt)
        a:DoEvent(evt).
}
for a in Ship:ModulesNamed("ModuleAvionics")
{
    if a:HasEvent(evt)
        a:DoEvent(evt).
}

for panel in Ship:ModulesNamed("ModuleROSolar")
    if panel:HasAction("extend solar panel")
        panel:DoAction("extend solar panel", true).

for panel in Ship:ModulesNamed("ModuleDeployableSolarPanel")
    if panel:HasAction("extend solar panel")
        panel:DoAction("extend solar panel", true).

for antenna in Ship:ModulesNamed("ModuleDeployableAntenna")
    if antenna:HasEvent("extend antenna")
        antenna:DoEvent("extend antenna").

print "Drop completed".
