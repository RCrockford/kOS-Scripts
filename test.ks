@lazyglobal off.

// Wait for unpack
wait until Ship:Unpacked.

local alleng is list().
list engines in alleng.

lock throttle to 0.

for eng in alleng
{
    print eng:title + "[" + eng:Config + "] residuals: " + eng:residuals.

    eng:Activate.

    local wm is ship:mass.
    local dm is wm.
    local dmr is wm.

    for k in eng:consumedResources:keys
    {
        local r is eng:ConsumedResources[k].
        set dm to dm - r:Amount * r:Density.
        set dmr to dmr - (r:Amount - r:capacity * eng:residuals) * r:Density.
    }

    print "Naive Δv: " + round(eng:IspAt(0) * Constant:g0 * ln(wm / dm), 1).
    print "Residual Δv: " + round(eng:IspAt(0) * Constant:g0 * ln(wm / dmr), 1).

    eng:shutdown.
}

unlock throttle.
