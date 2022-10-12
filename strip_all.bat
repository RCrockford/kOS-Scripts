@echo off

kOSStrip fcfuncssrc.ks fcfuncs.ks

kOSStrip flight\enginemanagementsrc.ks flight\enginemgmt.ks
kOSStrip flight\executeburnsrc.ks flight\executeburn.ks
kOSStrip flight\executeburnengsrc.ks flight\executeburneng.ks
kOSStrip flight\executeburnrcssrc.ks flight\executeburnrcs.ks
kOSStrip flight\rcscorrectionburnsrc.ks flight\rcscorrectionburn.ks
kOSStrip flight\orbitinsertburnsrc.ks flight\orbitinsertburn.ks

kOSStrip reentry\reentryburnsrc.ks reentry\reentryburn.ks
kOSStrip reentry\reentryrcssrc.ks reentry\reentryrcs.ks
kOSStrip reentry\reentryrcsprosrc.ks reentry\reentryrcspro.ks
kOSStrip reentry\reentrylandingsrc.ks reentry\reentrylanding.ks

kOSStrip lander\directdescent.ks lander\ddpack.ks

kOSStrip mgmt\readoutguisrc.ks mgmt\readoutgui.ks
