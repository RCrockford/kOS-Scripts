@lazyglobal off.

local flightGui is Gui(250).
set flightGui:X to 100.
set flightGui:Y to flightGui:Y + 50.
local mainBox is flightGui:AddHBox().
local labelBox is mainBox:AddVBox().
set labelBox:style:width to 150.
local controlBox is mainBox:AddVBox().
set controlBox:style:width to 100.
local launchButton is flightGui:AddButton("Launch").

global function LGUI_GetButton
{
    return launchButton.
}

global function LGUI_Show
{
    flightGui:Show().
}

global function LGUI_Hide
{
    flightGui:Hide().
}

global function LGUI_CreateTextEdit
{
    parameter lbl.
    parameter str.
    parameter dlg.
    parameter valid is true.

    local newLabel is labelBox:AddLabel(lbl).
    set newLabel:Style:Height to 25.
    
    local newControl is controlBox:AddTextField(str).
    set newControl:Style:Height to 25.
    set newControl:OnConfirm to dlg.
    set newControl:Enabled to valid.
    return newControl.
}

global function LGUI_CreateCheckbox
{
    parameter lbl.
    
    local newLabel is labelBox:AddLabel(lbl).
    set newLabel:Style:Height to 25.
    
    local newControl is controlBox:AddCheckBox("").
    set newControl:Style:Height to 25.
    return newControl.
}