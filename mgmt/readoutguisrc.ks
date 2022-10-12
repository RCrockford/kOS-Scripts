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
    section:cols:Add(newcol).
}

local function CreateSingleColumn
{
    parameter section.
    parameter labelWidth.
    parameter colWidth.

    local newCol is section:box:AddVBox().
    set newCol:style:width to (labelWidth + colWidth) + newCol:Style:Margin:Left.
    section:cols:Add(newcol).
}

local function RGUI_Show
{
    parameter readoutGui.

    readoutGui:gui:Show().
}

local function RGUI_Hide
{
    parameter readoutGui.

    readoutGui:gui:Hide().
}

local function RGUI_SetColumnCount
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
    
    readoutGui:readouts:cols:Clear().
    if not readoutGui:toggles:box:IsType("Scalar")
        readoutGui:toggles:cols:Clear().

    until widths:empty
    {
        CreateDoubleColumn(readoutGui:readouts, readoutGui:labelWidth, widths[0]).
        if not readoutGui:toggles:box:IsType("Scalar")
            CreateSingleColumn(readoutGui:toggles, readoutGui:labelWidth, widths[0]).
        widths:remove(0).
    }
}

local function RGUI_ClearAll
{
    parameter readoutGui.

    for col in readoutGui:readouts:cols
    {
        col:lbl:Clear().
        col:ctrl:Clear().
    }
    for col in readoutGui:toggles:cols
    {
        col:Clear().
    }
}

local function RGUI_AddReadout
{
    parameter readoutGui.
    parameter lbl.

    local newLabel is readoutGui:readouts:cols[readoutGui:readouts:next]:lbl:AddLabel(lbl).
    set newLabel:Style:Height to rowHeight.
    
    local newControl is readoutGui:readouts:cols[readoutGui:readouts:next]:ctrl:AddTextField("").
    set newControl:Style:Height to rowHeight.
    set newControl:Enabled to false.
    
    set readoutGui:readouts:next to mod(readoutGui:readouts:next + 1, readoutGui:readouts:cols:Length).
    
    return newControl.
}

local function SetupToggles
{
    parameter readoutGui.
    if readoutGui:toggles:box:IsType("Scalar")
    {
        set readoutGui:toggles:box to readoutGui:gui:AddHBox().
        until readoutGui:toggles:cols:Length >= readoutGui:readouts:cols:Length
            CreateSingleColumn(readoutGui:toggles, readoutGui:labelWidth, defColWidth).
    }
}

local function RGUI_AddToggle
{
    parameter readoutGui.
    parameter lbl.
    
    SetupToggles(readoutGui).
    
    local newControl is readoutGui:toggles:cols[readoutGui:toggles:next]:AddCheckBox(lbl, false).
    set newControl:Style:Height to rowHeight.
    
    set readoutGui:toggles:next to mod(readoutGui:toggles:next + 1, readoutGui:toggles:cols:Length).
    
    return newControl.
}

local function RGUI_AddButton
{
    parameter readoutGui.
    parameter lbl.
    
    SetupToggles(readoutGui).

    local newControl is readoutGui:toggles:cols[readoutGui:toggles:next]:AddButton(lbl).
    set newControl:Style:Height to rowHeight.
    
    set readoutGui:toggles:next to mod(readoutGui:toggles:next + 1, readoutGui:toggles:cols:Length).
    
    return newControl.
}

local function RGUI_AddStatus
{
    parameter readoutGui.
    
    SetupToggles(readoutGui).

    local newControl is readoutGui:toggles:cols[readoutGui:toggles:next]:AddTextField("").
    set newControl:Style:Height to rowHeight.
    
    set readoutGui:toggles:next to mod(readoutGui:toggles:next + 1, readoutGui:toggles:cols:Length).
    
    return newControl.
}

global RGUI_ColourGood is "#00ff00".
global RGUI_ColourNormal is "#ffd000".
global RGUI_ColourFault is "#ff4000".

global function RGUI_Create
{
    parameter x is 160.
    parameter y is 240.

    local readoutGui is lexicon("gui", Gui(200)).
    set readoutGui:gui:X to x.
    set readoutGui:gui:Y to readoutGui:gui:Y + y.
    
    readoutGui:Add("Show", RGUI_Show@:Bind(readoutGui)).
    readoutGui:Add("Hide", RGUI_Hide@:Bind(readoutGui)).
    readoutGui:Add("SetColumnCount", RGUI_SetColumnCount@:Bind(readoutGui)).
    readoutGui:Add("ClearAll", RGUI_ClearAll@:Bind(readoutGui)).
    readoutGui:Add("AddReadout", RGUI_AddReadout@:Bind(readoutGui)).
    readoutGui:Add("AddToggle", RGUI_AddToggle@:Bind(readoutGui)).
    readoutGui:Add("AddButton", RGUI_AddButton@:Bind(readoutGui)).
    readoutGui:Add("AddStatus", RGUI_AddStatus@:Bind(readoutGui)).

    readoutGui:Add("labelWidth", 80).
    readoutGui:Add("readouts", lexicon("box", readoutGui:gui:AddHBox(), "cols", list(), "next", 0)).
    readoutGui:Add("toggles", lexicon("box", 0, "cols", list(), "next", 0)).
    
    return readoutGui.
}

global function RGUI_SetText
{
    parameter ctrl.
    parameter str.
    parameter colour is RGUI_ColourNormal.
    
    set ctrl:Text to "<color="+colour+">" + str + "</color>".
}
