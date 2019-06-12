switch to 1.
if volume():FreeSpace > Volume(0):Open("/aero/APstripped.ks"):Size
{
copypath("0:/aero/APstripped.ks", path()).
runpath("APstripped").
}
else
{
runpath("0:/aero/Autopilot").
}