RUNONCEPATH("common.ks").
RUNONCEPATH("nodeTuner.ks").

parameter targetApproachDistance is 100000, _target is -1.
if _target = -1 {set _target to TARGET.}
local targetBody is choose _target if _target:ISTYPE("Body") else _target:BODY.

executeFineTune().

function executeFineTune { 
    local startupData is startup("Fine-tuning approach for " + targetApproachDistance + "m of " + _target:NAME + "...").
    clearNodes().

    // Find the patch where we enter the target's SOI.
    // If we don't, execute a preliminary correction burn to do so.
    local orbitPatch is findOrbitalPatchForSoi(SHIP:ORBIT, _target).
    if orbitPatch:BODY <> _target  {
		printLine("--------------------------------------------").
		printLine("WARNING: Not entering SOI of target,").
        printLine("  fine-tune calc will be more expensive.").
		printLine("--------------------------------------------").
        set orbitPatch to SHIP:ORBIT. // Reset to the current orbit by default.

        // Create burn node for the near future (but far enough in the future that the tuneNode calcs will have completed).
        local burnTime is TIME:SECONDS + 2*60.
        local burnNode is NODE(burnTime, 0, 0, 0).
        add burnNode.
        
        // Execute fine tuning.
        // Check half the orbit, starting from burnNode:
        local findClosestApprachEndTime is choose TIME:SECONDS +SHIP:ORBIT:NEXTPATCHETA if SHIP:ORBIT:HASNEXTPATCH else burnTime + SHIP:ORBIT:PERIOD * 0.5.
        tuneNode(burnNode, {
                local closestApproach is findClosestApproach(burnNode:ORBIT, _target, burnTime, findClosestApprachEndTime).
                return choose 0 if closestApproach:DISTANCE < _target:SOIRADIUS else abs(targetApproachDistance - closestApproach:DISTANCE).
            }).

        // Execute the burn, then find the updated current orbital patch.
        RUNPATH("mnode.ks.").
        set orbitPatch to findOrbitalPatchForSoi(SHIP:ORBIT, _target).
    }

    // Create burn node, positioned where 10% of the orbit period remains til closest approach to target.
    local burnStartTime is -1.
    if not orbitPatch:HASNEXTPATCH {
        // We're in a stable orbit around the target.
        set burnStartTime to orbitPatch:ETA:PERIAPSIS - (SHIP:ORBIT:PERIOD * 0.25).
    } else if SHIP:ORBIT:BODY = _target  {
        // We're in an escape orbit that is already around the target.  Burn NOW.
        set burnStartTime to 60.
    } else {
        // We're in an escape orbit that will hit the target.  Burn halfway until we hit the next transition.
        
        set burnStartTime to SHIP:ORBIT:NEXTPATCHETA / 2.
    }
    local burnNode is NODE(TIME:SECONDS + MAX(burnStartTime, 0), 0, 0, 0).
    add burnNode.

    // Execute fine tuning.
    local initialDeviation is abs(targetApproachDistance -  orbitPatch:PERIAPSIS).
    printLine("Intial deviation is " + round(initialDeviation)).
    tuneNode(burnNode, {
            local targetPatch is findOrbitalPatchForSoi(burnNode:ORBIT, _target).
            
            if targetPatch:BODY <> _target {
                // After this adjustment we no longer even enter the SOI of the target.
                // This is worse than the inial deviation, whatever value that was.
                // Return some arbitrary larger value to ensure we do not use this result.
                return initialDeviation * 2.
            }
            local newDeviation is abs(targetApproachDistance -  targetPatch:PERIAPSIS).
            return newDeviation.
        }).

    //Run the node.
    RUNPATH("mnode.ks.").

    startupData:END().
    
}