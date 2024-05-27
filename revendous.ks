RUNONCEPATH("common.ks").
RUNONCEPATH("nodeTuner.ks").

local _target is TARGET.  // In case taget becomes unset.

local startupData is startup("Revendousing with " + _target:NAME + ".").
// local closestApproach is findClosestApproach(SHIP:ORBIT, _target).
// printLine("Current dist is " + round(distanceBetween(SHIP:POSITION, _target:POSITION), 2)).
// printLine("Closest dist is " + round(closestApproach:DISTANCE, 2)).
// printLine("Closest dist eta is " + round(closestApproach:ETA, 2)).

if _target:ISTYPE("Part") {set _target to _target:SHIP.}

if distanceBetween(SHIP:POSITION, _target:POSITION) > 5000 {
    local revNode is NODE(TIME:SECONDS + 60 * 10, 0,0,0).
    ADD revNode.
    printLine("Tuning node...").
    tuneNode(revNode, {return findClosestApproach(revNode:ORBIT, _target):DISTANCE.}, .001, .1).
    printLine("  done").
    RUNPATH("mnode.ks").

    printLine("Warping to close approach...").
    local closeApproachTime is findClosestApproach(SHIP:ORBIT, _target):SECONDS - 120.
    WARPTO(closeApproachTime).
    WAIT UNTIL TIME:SECONDS >= closeApproachTime.
    printLine("  done").
}

// if closestApproach:ETA > 15 {
//     printLine("Warping to closest approach...").
//     WARPTO(TIME:SECONDS + closestApproach:ETA - 15).
// }

// printLine("Steeing to target...").
// until distanceBetween(SHIP:POSITION, _target:POSITION) < 500 {
//     if SHIP:availablethrust = 0 {
//         STAGE.
//         wait until STAGE:READY.
//     }
//     lock STEERING to _target:POSITION.
//     wait until  VANG(SHIP:FACING:FOREVECTOR, _target:POSITION) < 1.5.
//     LOCK THROTTLE TO 1.
//     //wait until VANG(PROGRADE:VECTOR, _target:POSITION) < 180.
//     wait 2.
//     LOCK THROTTLE TO 0.
//     local newClosestApproach is findClosestApproach(SHIP:ORBIT, _target).
//     if newClosestApproach:ETA > 10 {
//         WARPTO(TIME:SECONDS + newClosestApproach:ETA - 10).
//         WAIT 10.
//     } else {
//         WAIT 2.
//     }
// }
// printLine("  done").

until distanceBetween(SHIP:POSITION, _target:POSITION) < 500  {
    killRelativeVelocity().
    if distanceBetween(SHIP:POSITION, _target:POSITION) >= 500 {
        printLine("Closing in on target.").
        lock STEERING to _target:POSITION.
        printLine("Aligning header to target...").
        wait until VANG(SHIP:FACING:FOREVECTOR, _target:POSITION) <= 1.
        lock THROTTLE to 0.1.
        wait 2.
        lock THROTTLE to 0.
        local newApproach is findClosestApproach(SHIP:ORBIT, _target).
        lock STEERING to RETROGRADE.
        wait 5. // TODO: Instead, wait until heading alings with retrograde?
        WARPTO(newApproach:SECONDS - 20).
        wait until TIME:SECONDS >= newApproach:SECONDS - 15.
    }
}

// Come to a final stop.
killRelativeVelocity(0.002).

// Returns the distance between the two positions, in M.
function distanceBetween {
    parameter pos1, pos2.
    return ABS((pos1 - pos2):MAG).
}

function killRelativeVelocity {
    parameter maxRelativeVelocity is 0.05.
    lock relativeVelocity to SHIP:VELOCITY:ORBIT - _target:VELOCITY:ORBIT.
    lock retrogradeDirection to -relativeVelocity:NORMALIZED.
    lock STEERING to retrogradeDirection.
    printLine("Killing relative velocity...").
    until relativeVelocity:MAG < maxRelativeVelocity {
        if SHIP:AVAILABLETHRUST = 0 {
            lock THROTTLE to 0.
            stage.
            wait until stage:ready.
        }
        // Decrease max throttle as needed so we'll have >= 10 seconds of burn time.
        local burnTime is calcBurnTime(relativeVelocity:MAG).
        local maxThrottle is burnTime / 10.
        // Only throttle when we're aligned to target.
        local facingDeviation is VANG(SHIP:FACING:FOREVECTOR, retrogradeDirection).
        local facingAccuracyPercent is 1 - facingDeviation / 360.
        local throttleVal is choose MIN(maxThrottle, SQRT(facingAccuracyPercent)) if facingAccuracyPercent > 0.95 else 0.
        lock THROTTLE to throttleVal.
        printLine("Heading: " + round(facingAccuracyPercent * 100, 2) + "%  | Throttle: " + round(throttleVal, 5) + "%", true).
        //printLine("facingDeviation " + (1 - facingDeviation / 360), true).
        //printLine("Relative velocity is " + round(relativeVelocity:MAG), true).
        //lock throttle to (1 - facingDeviation / 360).
        wait 0.0001.
    }
    unlock STEERING.
    printLine("  done").
}

UNLOCK STEERING.
startupData:END().