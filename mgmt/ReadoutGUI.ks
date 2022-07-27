@lazyglobal off.

local defColWidth is 100.
local rowHeight is 22.

local function CreateDoubleColumn
{
    parameter section.
    parameter labelWidth.
    parameter colWidth.

    local newCol is lexicon("lbl", section:box:AddVBox(), "ctrl", section:box:AddVBox()).
    set newCol:lbl:style:width to labelWidth.
    set newCol:ctrl:style:width to colWidth.
    section:columns:Add(newcol).
}

local function CreateSingleColumn
{
    parameter section.
    parameter labelWidth.
    parameter colWidth.

    local newCol is section:box:AddVBox().
    set newCol:style:width to (labelWidth + colWidth) + newCol:Style:Margin:Left.
    section:columns:Add(newcol).
}

local function ReadoutGUI_Show
{
    parameter readoutGui.

    readoutGui:gui:Show().
}

local function ReadoutGUI_Hide
{
    parameter readoutGui.

    readoutGui:gui:Hide().
}

local function ReadoutGUI_SetColumnCount
{
    parameter readoutGui.
    parameter labelWidth.
    parameter widths.
    
    if widths:IsType("Scalar")
    {
        local count is widths.
        set widths to list().
        until widths:length = count
            widths:Add(defColWidth).
    }

    set readoutGui:labelWidth to labelWidth.
    
    readoutGui:readouts:columns:Clear().
    if not readoutGui:toggles:box:IsType("Scalar")
        readoutGui:toggles:columns:Clear().

    until widths:empty
    {
        CreateDoubleColumn(readoutGui:readouts, readoutGui:labelWidth, widths[0]).
        if not readoutGui:toggles:box:IsType("Scalar")
            CreateSingleColumn(readoutGui:toggles, readoutGui:labelWidth, widths[0]).
        widths:remove(0).
    }
}

local function ReadoutGUI_ClearAll
{
    parameter readoutGui.

    for col in readoutGui:readouts:columns
    {
        col:lbl:Clear().
        col:ctrl:Clear().
    }
    for col in readoutGui:toggles:columns
    {
        col:Clear().
    }
}

local function ReadoutGUI_AddReadout
{
    parameter readoutGui.
    parameter lbl.

    local newLabel is readoutGui:readouts:columns[readoutGui:readouts:nextCol]:lbl:AddLabel(lbl).
    set newLabel:Style:Height to rowHeight.
    
    local newControl is readoutGui:readouts:columns[readoutGui:readouts:nextCol]:ctrl:AddTextField("").
    set newControl:Style:Height to rowHeight.
    set newControl:Enabled to false.
    
    set readoutGui:readouts:nextCol to mod(readoutGui:readouts:nextCol + 1, readoutGui:readouts:columns:Length).
    
    return newControl.
}

local function SetupToggles
{
    parameter readoutGui.
    if readoutGui:toggles:box:IsType("Scalar")
    {
        set readoutGui:toggles:box to readoutGui:gui:AddHBox().
        until readoutGui:toggles:columns:Length >= readoutGui:readouts:columns:Length
            CreateSingleColumn(readoutGui:toggles, readoutGui:labelWidth, defColWidth).
    }
}

local function ReadoutGUI_AddToggle
{
    parameter readoutGui.
    parameter lbl.
    
    SetupToggles(readoutGui).
    
    local newControl is readoutGui:toggles:columns[readoutGui:toggles:nextCol]:AddCheckBox(lbl, false).
    set newControl:Style:Height to rowHeight.
    
    set readoutGui:toggles:nextCol to mod(readoutGui:toggles:nextCol + 1, readoutGui:toggles:columns:Length).
    
    return newControl.
}

local function ReadoutGUI_AddButton
{
    parameter readoutGui.
    parameter lbl.
    
    SetupToggles(readoutGui).

    local newControl is readoutGui:toggles:columns[readoutGui:toggles:nextCol]:AddButton(lbl).
    set newControl:Style:Height to rowHeight.
    
    set readoutGui:toggles:nextCol to mod(readoutGui:toggles:nextCol + 1, readoutGui:toggles:columns:Length).
    
    return newControl.
}

local function ReadoutGUI_AddStatus
{
    parameter readoutGui.
    
    SetupToggles(readoutGui).

    local newControl is readoutGui:toggles:columns[readoutGui:toggles:nextCol]:AddTextField("").
    set newControl:Style:Height to rowHeight.
    
    set readoutGui:toggles:nextCol to mod(readoutGui:toggles:nextCol + 1, readoutGui:toggles:columns:Length).
    
    return newControl.
}

global ReadoutGUI_ColourGood is "#00ff00".
global ReadoutGUI_ColourNormal is "#ffd000".
global ReadoutGUI_ColourFault is "#ff4000".

global function ReadoutGUI_Create
{
    parameter x is 160.
    parameter y is 240.

    local readoutGui is lexicon("gui", Gui(200)).
    set readoutGui:gui:X to x.
    set readoutGui:gui:Y to readoutGui:gui:Y + y.
    
    readoutGui:Add("Show", ReadoutGUI_Show@:Bind(readoutGui)).
    readoutGui:Add("Hide", ReadoutGUI_Hide@:Bind(readoutGui)).
    readoutGui:Add("SetColumnCount", ReadoutGUI_SetColumnCount@:Bind(readoutGui)).
    readoutGui:Add("ClearAll", ReadoutGUI_ClearAll@:Bind(readoutGui)).
    readoutGui:Add("AddReadout", ReadoutGUI_AddReadout@:Bind(readoutGui)).
    readoutGui:Add("AddToggle", ReadoutGUI_AddToggle@:Bind(readoutGui)).
    readoutGui:Add("AddButton", ReadoutGUI_AddButton@:Bind(readoutGui)).
    readoutGui:Add("AddStatus", ReadoutGUI_AddStatus@:Bind(readoutGui)).

    readoutGui:Add("labelWidth", 80).
    readoutGui:Add("readouts", lexicon("box", readoutGui:gui:AddHBox(), "columns", list(), "nextCol", 0)).
    readoutGui:Add("toggles", lexicon("box", 0, "columns", list(), "nextCol", 0)).
    
    return readoutGui.
}

global function ReadoutGUI_SetText
{
    parameter ctrl.
    parameter str.
    parameter colour.
    
    set ctrl:Text to "<color="+colour+">" + str + "</color>".
}
