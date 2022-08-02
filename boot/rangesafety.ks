@lazyglobal off.

until false
{
    wait until not core:messages:empty.
    local msg is core:messages:pop.

    // RSO destruction trigger
    if msg:content:IsType("string") and msg:content = "RSO"
    {
        if Core:Part:HasModule("ModuleRangeSafety")
        {
            // Wait for launch safety systems to clear the ship.
            wait 0.5.
            Core:Part:GetModule("ModuleRangeSafety"):DoAction("Range Safety", true).
        }
    }
}