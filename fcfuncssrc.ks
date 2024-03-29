// Generic functions

@lazyglobal off.

global lock LAS_ShipPos to -Ship:Body:Position.

global function LAS_EngineIsUllage
{
    parameter eng.
    
    return eng:Title:Contains("Separation") or eng:Title:Contains("Spin") or eng:Tag:Contains("ullage").
}

global function LAS_GetStageEngines
{
    parameter stageNum is Stage:Number.
    parameter ullage is false.
    
    local stageEngines is list().
    for e in ship:engines
    {
        if e:Stage = stageNum and LAS_EngineIsUllage(e) = ullage and not e:Name:Contains("vernier") and not e:Name:Contains("lr101")
            stageEngines:Add(e).
    }
    
    return stageEngines.
}

global function LAS_Avionics
{
    parameter action.
    
    local evt is action + " avionics".
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
    
    if action = "shutdown"
        set core:bootfilename to "".
}