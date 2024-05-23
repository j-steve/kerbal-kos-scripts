RUNONCEPATH("common.ks").
RUNONCEPATH("nodeTuner.ks").

executeFineTune().

function executeFineTune { 
    parameter targetApproachDistance is 100000.
    local startupData is startup("Fine-tuning approach.").

    // Find the patch where we enter the target's SOI.
    local orbitPatch is findTargetPatch(SHIP:ORBIT).
    if orbitPatch:BODY <> TARGET{
        // TODO: We could still fine-tune such situations by finding the closest approach.
		printLine("--------------------------------------------").
		printLine("ERROR: Not entering SOI of target, cannot fine tune.").
		printLine("--------------------------------------------").
        return startupData:END().
    }

    // Create burn node, positioned where 10% of the orbit period remains til closest approach to target.
    clearNodes().
    local burnStartTime is orbitPatch:ETA:PERIAPSIS - (SHIP:ORBIT:PERIOD * 0.25).
	local burnNode is NODE(TIME:SECONDS + MAX(burnStartTime, 0), 0, 0, 0).
	add burnNode.

    // Execute fine tuning.
    local initialDeviation is abs(targetApproachDistance -  orbitPatch:PERIAPSIS).
    printLine("Intial deviation is " + round(initialDeviation)).
    tuneNode(burnNode, {
            local targetPatch is findTargetPatch(burnNode:ORBIT).
            
            if targetPatch:BODY <> TARGET {
                // After this adjustment we no longer even enter the SOI of the target.
                // This is worse than the inial deviation, whatever value that was.
                // Return some arbitrary larger value to ensure we do not use this result.
                return initialDeviation * 2.
            }
            local newDeviation is abs(targetApproachDistance -  targetPatch:PERIAPSIS).
            return  newDeviation.
        }).

    startupData:END().
}

function findTargetPatch {
    parameter orbitPatch.
    until orbitPatch:BODY = TARGET or not orbitPatch:HASNEXTPATCH {
        set orbitPatch to orbitPatch:NEXTPATCH.
    }
    return orbitPatch.
}