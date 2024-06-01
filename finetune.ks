// This script is a bit complex because it tries to do 2 things:
// fine-tune a SOI encounter from the current SOI to a new child SOI, e.g. Kerbin>Minmus,
// and (kinda) to allow fine-tuning an encounter with a vessel etc within the current SOI.
// This involves executing 2 maneuvers: first, maneuver NOW to find an intercept with the target SOI 
// (unless we're already on an intercept course with it); second, maneuver later when we get near the SOI transition,
// to adjust the close approach distance.
//
// TODO: Seperate this into 2 scripts (or at least 2-3 different public functions),
// one for hitting a target periapsis around a body,
// and another for reaching a target distance around a vessel.

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
    local orbitPatch is findOrbitalPatchForSoi(SHIP:ORBIT, targetBody).
    if orbitPatch:BODY <> targetBody  {

        // If we have a transitional encounter, e.g. Kerbin > Mun > Kerbin > patch, we need to warp past it, because we can't see the next encounter.
        // Sometimes (?) only 3 patches are visible, so if the last patch ends in a transition (e.g. is not "FINAL", yet has no "NEXTPATCH",
        // then run this logic to skip through the intermediary patches so we can see futher ahead.
        if orbitPatch:TRANSITION <> "FINAL" {    
            printLine("Warping past transitional encounter.").
            local penultimatePatch is SHIP:ORBIT.
            until not penultimatePatch:NEXTPATCH:HASNEXTPATCH {
                set penultimatePatch to penultimatePatch:NEXTPATCH.
            }
            WARPTO(TIME:SECONDS + penultimatePatch:NEXTPATCHETA + 10).
            wait until TIME:SECONDS >= TIME:SECONDS + penultimatePatch:NEXTPATCHETA + 10.
        }

        if _target:ISTYPE("BODY") {
            // For a body, ideally we'd fine-tune using periapsis, after using hoffman transfer to enter the SOI.
            // This is more efficient.
            printLine("--------------------------------------------").
            printLine("WARNING: Not entering SOI of target,").
            printLine("  fine-tune calc will be more expensive.").
            printLine("--------------------------------------------").
        }
        _fineTuneForSoiEncounter().
        set orbitPatch to findOrbitalPatchForSoi(SHIP:ORBIT, _target).
    }

    if _target:ISTYPE("BODY") {
        _fineTunePeriapsis(orbitPatch).
    } 

    startupData:END().


    // Executes a fine-tuning based on the closest approach relative to target entity,
    // Assumes that we are not necessarily on track to enter the target body's SOI,
    // so uses costlier "findClosestApproach" technique if needed.
    function _fineTuneForSoiEncounter {
        // Create burn node for the near future (but far enough in the future that the tuneNode calcs will have completed).
        local burnTime is TIME:SECONDS + 2*60.
        local soiBurnNode is NODE(burnTime, 0, 0, 0).
        add soiBurnNode.
        
        // Execute fine tuning.
        // Check half the orbit, starting from burnNode:
        tuneNode(soiBurnNode, {
                local soiPatch is findOrbitalPatchForSoi(soiBurnNode:ORBIT, targetBody).
                if soiPatch:BODY = targetBody {
                    // Great, we now intercept the target! We can switch to the cheaper periapsis technique.
                    return abs(targetApproachDistance - soiPatch:PERIAPSIS).
                }
                local calcEndTime is findClosestApproachCalcEndTime(soiBurnNode:ORBIT, burnTime).
                local closestApproach is findClosestApproach(soiBurnNode:ORBIT, _target, burnTime, calcEndTime, 100).
                return abs(targetApproachDistance - closestApproach:DISTANCE).
            }).

        // Execute the burn, then find the updated current orbital patch.
        RUNPATH("mnode.ks.").

    }

    // Executes a fine-tuning based on adjusting to hit a target periapsis around a target body,
    // assuming we are already on track to enter that body's SOI.
    function _fineTunePeriapsis {
        parameter _orbit.
        // Create burn node, positioned where 10% of the orbit period remains til closest approach to target.
        local burnStartTime is -1.
        if not _orbit:HASNEXTPATCH {
            // We're in a stable orbit around the target.
            set burnStartTime to _orbit:ETA:PERIAPSIS - (SHIP:ORBIT:PERIOD * 0.25).
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
        local initialDeviation is abs(targetApproachDistance -  _orbit:PERIAPSIS).
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
    
}