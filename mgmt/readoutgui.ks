@lazyglobal off.
local _0 is 100.
local _1 is 22.
local function _f0
{
parameter _p0.
parameter _p1.
parameter _p2.
local _2 is lexicon("lbl",_p0:box:AddVBox(),"ctrl",_p0:box:AddVBox()).
set _2:lbl:style:width to _p1.
set _2:ctrl:style:width to _p2.
_p0:cols:Add(_2).
}
local function _f1
{
parameter _p0.
parameter _p1.
parameter _p2.
local _3 is _p0:box:AddVBox().
set _3:style:width to(_p1+_p2)+_3:Style:Margin:Left.
_p0:cols:Add(_3).
}
local function _f2
{
parameter _p0.
_p0:gui:Show().
}
local function _f3
{
parameter _p0.
_p0:gui:Hide().
}
local function _f4
{
parameter _p0.
parameter _p1.
parameter _p2.
if _p2:IsType("Scalar")
{
local _4 is _p2.
set _p2 to list().
until _p2:length=_4
_p2:Add(_0).
}
set _p0:labelWidth to _p1.
_p0:readouts:cols:Clear().
if not _p0:toggles:box:IsType("Scalar")
_p0:toggles:cols:Clear().
until _p2:empty
{
_f0(_p0:readouts,_p0:labelWidth,_p2[0]).
if not _p0:toggles:box:IsType("Scalar")
_f1(_p0:toggles,_p0:labelWidth,_p2[0]).
_p2:remove(0).
}
}
local function _f5
{
parameter _p0.
for col in _p0:readouts:cols
{
col:lbl:Clear().
col:ctrl:Clear().
}
for col in _p0:toggles:cols
{
col:Clear().
}
}
local function _f6
{
parameter _p0.
parameter _p1.
local _5 is _p0:readouts:cols[_p0:readouts:next]:lbl:AddLabel(_p1).
set _5:Style:Height to _1.
local _6 is _p0:readouts:cols[_p0:readouts:next]:ctrl:AddTextField("").
set _6:Style:Height to _1.
set _6:Enabled to false.
set _p0:readouts:next to mod(_p0:readouts:next+1,_p0:readouts:cols:Length).
return _6.
}
local function _f7
{
parameter _p0.
if _p0:toggles:box:IsType("Scalar")
{
set _p0:toggles:box to _p0:gui:AddHBox().
until _p0:toggles:cols:Length>=_p0:readouts:cols:Length
_f1(_p0:toggles,_p0:labelWidth,_0).
}
}
local function _f8
{
parameter _p0.
parameter _p1.
_f7(_p0).
local _7 is _p0:toggles:cols[_p0:toggles:next]:AddCheckBox(_p1,false).
set _7:Style:Height to _1.
set _p0:toggles:next to mod(_p0:toggles:next+1,_p0:toggles:cols:Length).
return _7.
}
local function _f9
{
parameter _p0.
parameter _p1.
_f7(_p0).
local _8 is _p0:toggles:cols[_p0:toggles:next]:AddButton(_p1).
set _8:Style:Height to _1.
set _p0:toggles:next to mod(_p0:toggles:next+1,_p0:toggles:cols:Length).
return _8.
}
local function _f10
{
parameter _p0.
_f7(_p0).
local _9 is _p0:toggles:cols[_p0:toggles:next]:AddTextField("").
set _9:Style:Height to _1.
set _p0:toggles:next to mod(_p0:toggles:next+1,_p0:toggles:cols:Length).
return _9.
}
global RGUI_ColourGood is"#00ff00".
global RGUI_ColourNormal is"#ffd000".
global RGUI_ColourFault is"#ff4000".
global function RGUI_Create
{
parameter x is 160.
parameter y is 240.
local _10 is lexicon("gui",Gui(200)).
set _10:gui:X to x.
set _10:gui:Y to _10:gui:Y+y.
_10:Add("Show",_f2@:Bind(_10)).
_10:Add("Hide",_f3@:Bind(_10)).
_10:Add("SetColumnCount",_f4@:Bind(_10)).
_10:Add("ClearAll",_f5@:Bind(_10)).
_10:Add("AddReadout",_f6@:Bind(_10)).
_10:Add("AddToggle",_f8@:Bind(_10)).
_10:Add("AddButton",_f9@:Bind(_10)).
_10:Add("AddStatus",_f10@:Bind(_10)).
_10:Add("labelWidth",80).
_10:Add("readouts",lexicon("box",_10:gui:AddHBox(),"cols",list(),"next",0)).
_10:Add("toggles",lexicon("box",0,"cols",list(),"next",0)).
return _10.
}
global function RGUI_SetText
{
parameter _p0.
parameter _p1.
parameter _p2 is RGUI_ColourNormal.
set _p0:Text to"<color="+_p2+">"+_p1+"</color>".
}
