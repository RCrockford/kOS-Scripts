@clobberbuiltins on.
@lazyglobal off.

// Wait for unpack
wait until Ship:Unpacked.

parameter minStage is stage:number - 1.

for p in Ship:Parts
{
	if p:DecoupledIn >= minStage
	{
		for r in p:resources
		{
			set r:enabled to true.
		}
	}
}