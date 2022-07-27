@echo off

kOSStrip FCFuncsSrc.ks FCFuncs.ks

kOSStrip flight\EngineManagementSrc.ks flight\EngineMgmt.ks
kOSStrip flight\ExecuteBurnSrc.ks flight\ExecuteBurn.ks
kOSStrip flight\ExecuteBurnEngSrc.ks flight\ExecuteBurnEng.ks
kOSStrip flight\ExecuteBurnRCSSrc.ks flight\ExecuteBurnRCS.ks
kOSStrip flight\RCSCorrectionBurnSrc.ks flight\RCSCorrectionBurn.ks
kOSStrip flight\OrbitInsertBurnSrc.ks flight\OrbitInsertBurn.ks
kOSStrip reentry\ReEntryBurnSrc.ks reentry\ReEntryBurn.ks
kOSStrip reentry\ReEntryRCSSrc.ks reentry\ReEntryRCS.ks
kOSStrip reentry\ReEntryRCSProSrc.ks reentry\ReEntryRCSPro.ks
kOSStrip reentry\ReEntryLandingSrc.ks reentry\ReEntryLanding.ks
kOSStrip flight\TuneSteeringSrc.ks flight\TuneSteering.ks

kOSStrip lander\DirectDescent.ks lander\DDPack.ks
