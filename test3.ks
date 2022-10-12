@lazyglobal off.

// Wait for unpack
wait until Ship:Unpacked.

for eng in ship:engines
{
    if eng:stage >= stage:number-1
        eng:activate.
}

set ship:control:pilotmainthrottle to 1.

wait 5.

until ship:control:pilotmainthrottle <= 0
{
    wait 0.
    local sumThrust is 0.
    for eng in ship:engines
        set sumThrust to sumThrust + eng:thrust.
    print "throttle: " + round(throttle, 2) + " ship:thrust=" + round(ship:thrust, 1) + " sumThrust=" + round(sumThrust, 1).
    
    set ship:control:pilotmainthrottle to ship:control:pilotmainthrottle - 0.2.
    wait 2.
}

for eng in ship:engines
    eng:shutdown.
