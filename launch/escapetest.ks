global function dummy_func {}

global LAS_CrewEscape is dummy_func@.
global LAS_EscapeJetisson is dummy_func@.
global LAS_HasEscapeSystem is false.
    
runpath("0:/launch/Staging").
runpath("0:/launch/LaunchEscape").

LAS_CrewEscape().
