RUNONCEPATH("common.ks").
RUNONCEPATH("nodeTuner.ks").

parameter targetApproachDistance is 100000.

executeFineTune().

function executeFineTune { 
    local startupData is startup("Fine-tuning approach for " + targetApproachDistance + "m of " + TARGET:NAME + "...").

    // Find the patch where we enter the target's SOI.
    local orbitPatch is findOrbitalPatchForSoi(SHIP:ORBIT, TARGET).
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
            local targetPatch is findOrbitalPatchForSoi(burnNode:ORBIT, TARGET).
            
            if targetPatch:BODY <> TARGET {
                // After this adjustment we no longer even enter the SOI of the target.
                // This is worse than the inial deviation, whatever value that was.
                // Return some arbitrary larger value to ensure we do not use this result.
                return initialDeviation * 2.
            }
            local newDeviation is abs(targetApproachDistance -  targetPatch:PERIAPSIS).
            return  newDeviation.
        }).

    //Run the node.
    RUNPATH("mnode.ks.").

    startupData:END().
}