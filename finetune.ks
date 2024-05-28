RUNONCEPATH("common.ks").
RUNONCEPATH("nodeTuner.ks").

parameter targetApproachDistance is 100000.

executeFineTune().

function executeFineTune { 
    local startupData is startup("Fine-tuning approach for " + targetApproachDistance + "m of " + TARGET:NAME + "...").
    clearNodes().

    // Find the patch where we enter the target's SOI.
    local orbitPatch is findOrbitalPatchForSoi(SHIP:ORBIT, TARGET).
    if orbitPatch:BODY <> TARGET  {
		printLine("--------------------------------------------").
		printLine("WARNING: Not entering SOI of target,").
        printLine("  fine-tune calc will be more expensive.").
		printLine("--------------------------------------------").
        set orbitPatch to SHIP:ORBIT. // Reset to the current orbit by default.

        // Create burn node, positioned where 25% of the way through this orbit
        // (because ~50% is probably where we will roughly hit the target).
        local burnTime is choose TIME:SECONDS + 10*60 if SHIP:ORBIT:HASNEXTPATCH else TIME:SECONDS + SHIP:ORBIT:PERIOD * 0.25.
        local burnNode is NODE(burnTime, 0, 0, 0).
        add burnNode.
        
        // Execute fine tuning.
        // Check half the orbit, starting from burnNode:
        local findClosestApprachEndTime is choose TIME:SECONDS +SHIP:ORBIT:NEXTPATCHETA if SHIP:ORBIT:HASNEXTPATCH else burnTime + SHIP:ORBIT:PERIOD * 0.5.
        tuneNode(burnNode, {
                local closestApproach is findClosestApproach(burnNode:ORBIT, TARGET, burnTime, findClosestApprachEndTime).
                return abs(targetApproachDistance - closestApproach:DISTANCE).
            }).
        
    } else {
        // Create burn node, positioned where 10% of the orbit period remains til closest approach to target.
        local burnStartTime is choose SHIP:ORBIT:NEXTPATCHETA/2 if orbitPatch:HASNEXTPATCH else orbitPatch:ETA:PERIAPSIS - (SHIP:ORBIT:PERIOD * 0.25).
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
                return newDeviation.
            }).
    }

    //Run the node.
    RUNPATH("mnode.ks.").

    startupData:END().
    
}