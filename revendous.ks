// -------------------------------------------------------------------------------------------------
// This program will try to bring the ship very close to a target and then come to a complete stop.
// It assumes the target is within the same SOI already.
//
// The program will first plot a node that gets somewhat close to the target, then add additional 
// fine-tuning burns as needed to get within a KM or so.
//
// Once within a KM or so, it'll get REALLY close by killing relative momentum, pointing at the target, 
// burning slowly, and waiting until we drift as close as possible, then repeating as neccessary.
//
// It may have trouble matching orbits with very different inclinations, so consider running `inc.ks`
// first before this script.  If docking, run this program prior to `dock.ks` to ensure we are
// close by and stopped so docking can proceed from that state.
// -------------------------------------------------------------------------------------------------

RUNONCEPATH("common.ks").
RUNONCEPATH("nodeTuner.ks").

local CLOSE_APPROACH_CALC_STEPS is 500.

parameter _targetFinalDistance is 75.

local _target is TARGET.  // In case taget becomes unset.
if _target:ISTYPE("Part") {set _target to _target:SHIP.}
local startupData is startup("Rendezvousing with " + _target:NAME + ".").
clearNodes().
execRendezvous().
startupData:END().

function execRendezvous {
    local updatedMinApproach to findClosestApproach(SHIP:ORBIT, _target, TIME:SECONDS, -1, CLOSE_APPROACH_CALC_STEPS).
    printLine("Min approach " + round(updatedMinApproach:DISTANCE) + "m in " + round(updatedMinApproach:ETA() / 60) + " minutes.").
    if updatedMinApproach:DISTANCE > 5000 and distanceBetween(SHIP, _target) > 10000 {
        local obtainInterceptSection is printSectionStart("Plotting an initial intercept...").
        // Start at a point 10 minutes in the future, 
        // mainly to enusre that the position is STILL in the future
        // once we've finished these calculations.
        // TODO: We should be able to use a hoffman transfer here instead.
        //local burnStartTime is 10 * 60.
        local revNode is addNodeAtEta(choose ETA:PERIAPSIS if _target:APOAPSIS > SHIP:APOAPSIS else ETA:APOAPSIS).
        local orbitCountI is 1.
        local minApproach is -1.
        until minApproach <> -1 and minApproach:DISTANCE < 5000 {
            if orbitCountI > 1 {
                // Reset node and increment to next orbit.
                set revNode:ETA to revNode:ETA + SHIP:ORBIT:PERIOD.
                set revNode:radialout to 0.
                set revNode:PROGRADE to 0.
                set revNode:NORMAL to 0.
            }
            printLine("Finding closest approach in orbit #" + orbitCountI + "...").
            tuneNode(revNode, {
                    local closeApproach is findClosestApproach(revNode:ORBIT, _target, revNode:TIME, -1, CLOSE_APPROACH_CALC_STEPS).
                        return choose 0 if closeApproach:DISTANCE < 250 else closeApproach:DISTANCE.
                }, .01, .5).
            set minApproach to findClosestApproach(revNode:ORBIT, _target, revNode:TIME, -1, 250).
            printLine("  Min approach: " + round(minApproach:DISTANCE)).
            set orbitCountI to orbitCountI + 1.
        }
        RUNPATH("mnode.ks").

        printLine("  done").
        set updatedMinApproach to findClosestApproach(SHIP:ORBIT, _target, TIME:SECONDS, -1, CLOSE_APPROACH_CALC_STEPS).
        obtainInterceptSection:END().
    }

    until updatedMinApproach:DISTANCE < 1000 {
        set updatedMinApproach to _execFineTuneAdjustment(updatedMinApproach).
    }

    if TIME:SECONDS < updatedMinApproach:SECONDS and not _isWithin(1000) {
        printLine("Warping to close approach time...").
        warpToTime(updatedMinApproach:SECONDS - 120).
    }
        
    local within1kmSection is printSectionStart("Waiting to get within 1km...").
    lock STEERING to -_target:POSITION.
    if not _isWithin(1000) {
        wait until ABS(VANG(SHIP:FACING:FOREVECTOR, -_target:POSITION)) < 1.5 or _isWithin(1000).
        if not _isWithin(1000) {
            set WARP to 2.
            wait until _isWithin(1000).
            kuniverse:timewarp:cancelwarp().
        }
    }
    within1kmSection:END("done").

    // Close in real close.
    _closeInOnTarget(_targetFinalDistance).

    // Come to a final stop.
    local finalStopSection is printSectionStart("Coming to a final stop...").
    _killRelativeVelocity(0.002).
    finalStopSection:END().

    // This section assumes we are coasting along our orbit getting progressively closer to the target.  We'll keep making fine adjustments as needed to intercept.
    // Because of this, we can use the cheaper "returnOnIncrease=true" param for findClosestApproach, because our expected trajectory now is basically a straight
    // line towards the target.
    function _execFineTuneAdjustment {
        parameter initialMinApproach.
        local closeApproachSection is printSectionStart("Tuning node to get close approach...").
        // Fine-tune at 75% of the way to the target, but make sure it's at least 2 minutes out.
        local fineTuneNode is addNodeAtEta(MAX(initialMinApproach:ETA() * .75, 2 * 60)). 
        local searchEndTime is -1.
        tuneNode(fineTuneNode, {
                        local closeApproach is findClosestApproach(SHIP:ORBIT, _target, fineTuneNode:TIME, searchEndTime, CLOSE_APPROACH_CALC_STEPS).
                        return choose 0 if closeApproach:DISTANCE < 250 else closeApproach:DISTANCE.
                    }, .001, .01).
        local plannedNewMinApproach is findClosestApproach(SHIP:ORBIT, _target, TIME:SECONDS, -1, CLOSE_APPROACH_CALC_STEPS).
        printLine("Min approach: " + round(plannedNewMinApproach:DISTANCE) + "m in " + round(plannedNewMinApproach:ETA() / 60) + " minutes.").
        RUNPATH("mnode.ks").
        local newMinApproach is findClosestApproach(SHIP:ORBIT, _target, TIME:SECONDS, -1, CLOSE_APPROACH_CALC_STEPS).
        closeApproachSection:END().
        return newMinApproach.
    }
    // Gets very close to target, by progressively coming to a complete stop, pointing at target, and thrusting slightly,
    // then coasting until reaching maximum closeness and repeating.  
    function _closeInOnTarget {
        parameter _distance.
        local closingInSection is printSectionStart("Closing in to within " + _distance + " of target.").

        until _isWithin(_distance) {
            _killRelativeVelocity(0.1).
            
            if SHIP:availablethrust = 0 {
                printLine("Staging").
                STAGE.
                wait until STAGE:READY.
            }

            printLine("Aligning header to target...").
            lock STEERING to _target:POSITION.
            wait until ABS(VANG(SHIP:FACING:FOREVECTOR, _target:POSITION)) < .5 or _isWithin(_distance).

            printLine("Engaging throggle...").
            LOCK THROTTLE TO 0.1.
            wait until (SHIP:VELOCITY:ORBIT - _target:VELOCITY:ORBIT):MAG > 1 or _isWithin(_distance).
            LOCK THROTTLE TO 0.
            local newClosestApproach is findClosestApproach(SHIP:ORBIT, _target, -1, -1, -1, true).

            printLine("Aligning ship for counterthrust...").
            lock STEERING to -_target:POSITION.
            wait until ABS(VANG(SHIP:FACING:FOREVECTOR, -_target:POSITION)) < 1.5 or _isWithin(_distance).

            printLine("Waiting get within " + _distance + "...").
            local ratherCloseApproachSeconds is newClosestApproach:SECONDS - 90.
            if TIME:SECONDS < ratherCloseApproachSeconds or _isWithin(_distance) {
                // If it's a long wait, use WARPTO to get close.
                warpToTime(ratherCloseApproachSeconds).
            }
            if TIME:SECONDS >= newClosestApproach:SECONDS - 10 and _isWithin(_distance) {
                set WARP to 2.
                wait until TIME:SECONDS >= newClosestApproach:SECONDS - 10 or _isWithin(_distance).
                kuniverse:timewarp:cancelwarp().
            }
        }
        closingInSection:END("done").
    }

    function _killRelativeVelocity {
        parameter maxRelativeVelocity is 0.05, timeoutSeconds is 120.
        lock relativeVelocity to SHIP:VELOCITY:ORBIT - _target:VELOCITY:ORBIT.
        lock retrogradeDirection to -relativeVelocity:NORMALIZED.
        lock STEERING to retrogradeDirection.
        local maxEndTime is TIME:SECONDS + timeoutSeconds.
        local killVeloSection is printSectionStart("Killing relative velocity...").
        // TODO: until the very end of the burn, set physics warp to 4.
        set WARPMODE to "PHYSICS".
        set WARP to 1.
        until relativeVelocity:MAG < maxRelativeVelocity or (relativeVelocity:MAG < maxRelativeVelocity * 2 and TIME:SECONDS >= maxEndTime) {
            if SHIP:AVAILABLETHRUST = 0 {
                lock THROTTLE to 0.
                stage.
                wait until stage:ready.
            }
            // Decrease max throttle as needed so we'll have >= 10 seconds of burn time.
            local burnTime is calcBurnTime(relativeVelocity:MAG).
            local maxThrottle is burnTime / 10.
            // Only throttle when we're aligned to target.
            local facingDeviation is ABS(VANG(SHIP:FACING:FOREVECTOR, retrogradeDirection)).
            local facingAccuracyPercent is 1 - facingDeviation / 360.
            local throttleVal is choose MIN(maxThrottle, SQRT(facingAccuracyPercent)) if facingAccuracyPercent > 0.99 else 0.
            lock THROTTLE to throttleVal.
            //printLine("Heading: " + round(facingAccuracyPercent * 100, 1) + "%  | Throttle: " + round(throttleVal, 5) + "%", true).
            printLine("Relative vel: " + round(relativeVelocity:MAG, 5) + " | Throttle: " + round(throttleVal, 5) + "%", true).
            //printLine("facingDeviation " + (1 - facingDeviation / 360), true).
            //printLine("Relative velocity is " + round(relativeVelocity:MAG), true).
            //lock throttle to (1 - facingDeviation / 360).
            wait 0.0001.
        }
        if (relativeVelocity:MAG > maxRelativeVelocity) {
            printLine("Timed out, pretty close though: " + round(relativeVelocity:MAG, 5)).
        }
        set WARP to 0.
        unlock STEERING.
        killVeloSection:END("done").
    }
    
    // Returns true if the distance between ship and target is less than the specified distance.
    function _isWithin {
        parameter _distance.
        return distanceBetween(SHIP:POSITION, _target:POSITION) < _distance.
    }

}