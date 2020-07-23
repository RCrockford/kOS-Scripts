@lazyglobal off.

parameter burnParams.
parameter fileList.

// Clear storage
runpath("0:/localpack/InstallPack.ks", list()).

// Write to storage so it can be restored when switching to ship.
writejson(burnParams, "1:/burn.json").

if not exists("1:/burn.json")
{
	print "Unable to setup manoeuvre, insufficient space on local storage".
}
else
{
	runpath("0:/localpack/InstallPack.ks", fileList).

	if exists("1:/" + fileList[fileList:Length-1])
	{
		print "Waiting for manoeuvre in autonomous mode".
		set core:bootfilename to "/" + fileList[0].
		switch to 1.
	}
	else
	{
		print "Waiting for manoeuvre in downlink mode".
		switch to 0.
	}

	runpath(fileList[0]).
}