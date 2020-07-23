@lazyglobal off.
local _0 is list().
list rcs in _0.
local _1 is 0.
local _2 is Ship:ControlPart:Facing:TopVector.
for r in _0
{
local _3 is 0.
for t in r:ThrustVectors
{
set _3 to _3+max(vdot(t,_2),0).
}
if _3>0.01
{
set _1 to _1+r:AvailableThrust*min(_3,1)*r:position:mag.
}
}
steeringmanager:resettodefault().
set steeringmanager:pitchtorqueadjust to _1*0.25.
set steeringmanager:yawtorqueadjust to _1*0.25.
set steeringmanager:pitchtorquefactor to 0.8.
set steeringmanager:yawtorquefactor to 0.8.
