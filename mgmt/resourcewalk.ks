@clobberbuiltins on.
@lazyglobal off.

local ResourceAliases is lexicon("LqdHydrogen", list("LH2")).

local function ConnectedResourceWalk
{
    parameter p.
    parameter res.
    parameter seen.
	parameter eng.

    if p:FuelCrossfeed or seen:Length = 1	// ignore crossfeed if directly connected
    {
		for r in p:resources
		{
			if r:Enabled
			{
				local nameList is list(r:Name).
				if ResourceAliases:HasKey(r:Name)
				{
					for a in ResourceAliases[r:Name]
						nameList:Add(a).
				}
				
				for name in nameList
				{
					if res:HasKey(name)
                    {
						set res[name]:amount to res[name]:amount + r:amount.
						set res[name]:capacity to res[name]:capacity + r:capacity.
                    }
					else
                    {
						res:Add(name, lexicon("amount", r:amount, "capacity", r:capacity)).
                    }
				}
			}
		}
	}	
	
    seen:Add(p).
	
	// Connected engines
	if p:IsType("Engine")
	{
		if res:HasKey("eng")
			res["eng"]:add(p).
		else
			res:Add("eng", list(p)).
	}	
	
    // Don't consider crossfeed for solid fuel engines
	if p:FuelCrossfeed and eng:AllowShutdown
	{
        if p:HasParent and not seen:contains(p:parent)
        {
            set res to ConnectedResourceWalk(p:parent, res, seen, eng).
        }
        for c in p:children
        {
            if not seen:contains(c)
                set res to ConnectedResourceWalk(c, res, seen, eng).
        }
    }
    
    return res.
}

global function GetConnectedResources
{
    parameter eng.
    
    return ConnectedResourceWalk(eng, lexicon(), uniqueset(), eng).
}


local function ConnectedPartWalk
{
    parameter p.
    parameter partList.
    parameter seen.
    parameter partType.

    seen:Add(p).
	
	if p:IsType(partType)
        partList:Add(p).
	
    if p:HasParent and not seen:contains(p:parent)
    {
        set partList to ConnectedPartWalk(p:parent, partList, seen, partType).
    }
    for c in p:children
    {
        if not seen:contains(c)
            set partList to ConnectedPartWalk(c, partList, seen, partType).
    }
    
    return partList.
}

global function GetConnectedParts
{
    parameter root.
    parameter partType.
    
    return ConnectedPartWalk(root, list(), uniqueset(), partType).
}
