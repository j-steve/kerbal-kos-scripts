RUNONCEPATH("common.ks").

executeFineTune().

function executeFineTune { 
    local startupData is startup("Fine-tuning approach.").

    // Find the patch where we enter the target's SOI.
    local orbitPatch is SHIP:ORBIT.
    until orbitPatch:BODY = TARGET or not orbitPatch:HASNEXTPATCH {
        set orbitPatch to orbitPatch:NEXTPATCH.
    }
    if orbitPatch:BODY <> TARGET{
        // TODO: We could still fine-tune such situations by finding the closest approach.
		printLine("--------------------------------------------").
		printLine("ERROR: Not entering SOI of target, cannot fine tune.").
		printLine("--------------------------------------------").
        return startupData:END().
    }

    // Do a fine-tune burn when 25% of the orbit period remains til periapsis.
    local burnStartTime = orbitPatch:ETA:PERIAPSIS - (SHIP:ORBIT:PERIOD * 0.25).


    startupData:END().
}