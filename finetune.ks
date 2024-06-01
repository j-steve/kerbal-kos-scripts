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
        printLine("End time is " + (findClosestApproachCalcEndTime(SHIP:ORBIT, burnTime) - TIME:SECONDS) / 60/60). 
        tuneNode(burnNode, {
                local calcEndTime is findClosestApproachCalcEndTime(burnNode:ORBIT, burnTime).
                local closestApproach is findClosestApproach(burnNode:ORBIT, _target, burnTime, calcEndTime, 100).
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

// Returns the latest, in seconds, at which we should stop checking, during "closest approach" calculation
// to try to enter the target SOI.  
// 1. If the orbit is a standard (non-parabolic) orbit, then we can just take the node burn time + half the orbit period, since we will presumably hit the target at some point during that loop.
//      In other words this presumes the target is roughly "in front" of us, not "behind" us, since we wouldn't fine tune after flying past an entity but before hitting it.
// 2. If it ends in an escape, e.g. kerbin > kerbol, it'll be the time until we hit that next patch.
// 3. If it ends in a child orbit and doesn't return, e.g. kerbin > mun orbit, it'll be the time until we hit that next patch.
// 4. If it involves temporarily entering another SOI and then returning, e.g. kerbin > mun > kerbin, then it'll be the end time of the SECOND kerbit patch (third patch total).
// 5. If the orbit crashes, it'll be the time we crash. (This logic is already included in the `findClosestApproach` function itself.)
function findClosestApproachCalcEndTime {
    parameter _orbit, _nodeBurnTime.
    if not _orbit:HASNEXTPATCH {
        return _nodeBurnTime + _orbit:PERIOD * 0.5.
    } else if _orbit:TRANSITION = "ESCAPE" { // e.g. Kerbin > Kerbol
        return TIME:SECONDS + _orbit:NEXTPATCHETA.
    } else if _orbit:TRANSITION = "ENCOUNTER" { // e.g., Kerbin > Mun
        if _orbit:NEXTPATCH:TRANSITION = "ESCAPE" { // e.g. Kerbin > Mun > Kerbin
            return findClosestApproachCalcEndTime(_orbit:NEXTPATCH:NEXTPATCH, _nodeBurnTime).
        } else { // e.g. Kerbin > Munar orbit
            return TIME:SECONDS + _orbit:NEXTPATCHETA.
        }
    }
}