// Orbital manoeuvres using Principia's flight planner

@lazyglobal off.

// Wait for unpack
wait until Ship:Unpacked.

if not HasNode
{
    print "No planned manoeuvres found.".
}
else
{
    local infoGui is GUI(250).
    local mainBox is infoGui:AddVBox().

    local guiHeading is mainBox:AddLabel("Stabilising").
    local guiStats1 is mainBox:AddLabel("").
    local guiStats2 is mainBox:AddLabel("").
    local guiStats3 is mainBox:AddLabel("").
    
    infoGui:Show().
	
	local manoeuvre is NextNode.

    rcs on.
    lock steering to manoeuvre:deltaV:Normalized.
    
    local start is Time:Seconds.
    
    until abs(SteeringManager:AngleError) < 0.1 and (Ship:AngularVel:SqrMagnitude - (vdot(Ship:Facing:Vector, Ship:AngularVel)^2) < 1e-6)
    {
        set guiStats1:Text to "AngErr: " + round(SteeringManager:AngleError, 2).
		set guiStats2:Text to "pyAV:" + sqrt(max(Ship:AngularVel:SqrMagnitude - (vdot(Ship:Facing:Vector, Ship:AngularVel)^2), 1e-12)).
		set guiStats3:Text to "rAV:" + vdot(Ship:Facing:Vector, Ship:AngularVel).
        wait 0.
    }
    
    print "Settle time: " + round(Time:Seconds - start, 1) + " s".
        
    // Maximum roll acceleration
    set Ship:Control:Roll to -1.
    
    set start to Time:Seconds.
    
    set guiHeading:Text to "Spinning up".
    
    until Ship:Control:Roll > 0
    {
        local pitchErr is -vdot(Ship:facing:TopVector, manoeuvre:deltaV:Normalized).
        local yawErr is -vdot(Ship:facing:StarVector, manoeuvre:deltaV:Normalized).
        local rollRate is vdot(Ship:Facing:Vector, Ship:AngularVel).
        
        set guiStats1:Text to "Roll: " + round(rollrate, 2).
		set guiStats2:Text to " pErr: " + round(pitchErr, 6).
		set guiStats3:Text to " yErr: " + round(yawErr, 6).
        
        // Fire thrusters until we're doing at least 6 radians per second
        if abs(rollRate) > 10
        {
			set Ship:Control:Roll to 0.1.
		}
        else if abs(rollRate) > 6 and abs(rollRate) < 9
        {
            set Ship:Control:Roll to -0.1.
        }

        wait 0.
    }

    print "Spin time: " + round(Time:Seconds - start, 1) + " s".
    print "Roll rate: " + round(vdot(Ship:Facing:Vector, Ship:AngularVel), 2).
	
	wait 10.
	
	print "Roll rate: " + round(vdot(Ship:Facing:Vector, Ship:AngularVel), 2).
    
    // release controls
    set ship:control:neutralize to true.
    
    set guiHeading:Text to "Resetting".

    lock steering to "kill".
    
    wait until Ship:AngularVel:SqrMagnitude < 1e-5.
    
    unlock steering.
    rcs off.
    
    infoGui:Hide().
}