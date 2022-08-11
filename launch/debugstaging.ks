@lazyglobal off.

// Wait for unpack
wait until Ship:Unpacked.

runoncepath("0:/launch/lasfunctions").

local liftoffStage is choose stage:number - 1 if Ship:Status <> "Flying" else Stage:number.

from {local s is liftoffStage.} until s < 0 step {set s to s - 1.} do
{
    LAS_GetStagePerformance(s, true, true).
}
