@echo off

kOSStrip FCFuncsSrc.ks FCFuncs.ks
kOSStrip aero\Autopilot.ks aero\APStripped.ks

kOSStrip flight\EngineManagementSrc.ks flight\EngineMgmt.ks

kOSStrip flight\ExecuteManoeuvreBurnSrc.ks flight\ExecuteManoeuvreBurn.ks
kOSStrip flight\OrbitInsertBurnSrc.ks flight\OrbitInsertBurn.ks
kOSStrip flight\LowerApoBurnSrc.ks flight\LowerApoBurn.ks
kOSStrip flight\LowerApoRCSSrc.ks flight\LowerApoRCS.ks
kOSStrip flight\RaisePeriBurnSrc.ks flight\RaisePeriBurn.ks
kOSStrip flight\RaisePeriRCSSrc.ks flight\RaisePeriRCS.ks
kOSStrip flight\ReEntryBurnSrc.ks flight\ReEntryBurn.ks
kOSStrip flight\ReEntryRCSSrc.ks flight\ReEntryRCS.ks
kOSStrip flight\ReEntryRCSProSrc.ks flight\ReEntryRCSPro.ks
kOSStrip flight\GTOInsertBurnSrc.ks flight\GTOInsertBurn.ks
kOSStrip flight\GSOCircBurnSrc.ks flight\GSOCircBurn.ks
