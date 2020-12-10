@lazyglobal off.

// Wait for unpack
wait until Ship:Unpacked.

parameter scanType.
parameter minAlt.
parameter maxAlt.


local scanning is false.
until false
{
    if Ship:altitude <= maxAlt * 1000 and Ship:altitude >= minAlt * 1000
    {
        if not scanning
        {
            for ss in Ship:ModulesNamed("ScanSat")
            {
                if ss:HasEvent("start scan: " + scanType)
                    ss:DoEvent("start scan: " + scanType).
            }
            set scanning to true.
        }
    }
    else
    {
        if scanning
        {
            for ss in Ship:ModulesNamed("ScanSat")
            {
                if ss:HasEvent("stop scan: " + scanType)
                    ss:DoEvent("stop scan: " + scanType).
            }
            set scanning to false.
        }
    }
    
    wait 1.
}
