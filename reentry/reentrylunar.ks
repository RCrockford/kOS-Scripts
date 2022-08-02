// ReEntry burn
@lazyglobal off.

// Wait for unpack
wait until Ship:Unpacked.

parameter targetStage is 0.

if Ship:Status = "Sub_Orbital" or Ship:Status = "Flying" or Ship:Status = "Escaping"
{
    local fileList is list().
    local burnParams is lexicon().
    
	fileList:Add("reentry/ReEntryLanding.ks").

    runpath("0:/flight/SetupBurn", burnParams, fileList, "re-entry").
}
else
{
	print "Need to be in sub-orbital trajectory".
}
