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
    // Start at a point 10 minutes in the future, 
    // mainly to enusre that the position is STILL in the future
    // once we've finished these calculations.
    // TODO: We should be able to use a hoffman transfer here instead.
    local revNode is NODE(TIME:SECONDS + 10 * 60, 0,0,0).
    ADD revNode.
    local minApproach is -1.
    local orbitCountI is 1.
    until minApproach <> -1 and minApproach:DISTANCE < 5000 {
        if orbitCountI > 1 {
            // Reset node and increment to next orbit.
            set revNode:ETA to revNode:ETA + SHIP:ORBIT:PERIOD.
            set revNode:radialout to 0.
            set revNode:PROGRADE to 0.
            set revNode:NORMAL to 0.
        }
        printLine("Finding closest approach in orbit #" + orbitCountI + "...").
        local fineCloseApproachNode is findClosestApproach@:BIND(revNode:ORBIT, _target, TIME:SECONDS + revNode:ETA, -1, 100).
        tuneNode(revNode, {return abs(fineCloseApproachNode:CALL():DISTANCE).}, .01, .1).
        set minApproach to fineCloseApproachNode:CALL().
        printLine("  Min approach: " + round(minApproach: DISTANCE)).
        set orbitCountI to orbitCountI + 1.
    }
    RUNPATH("mnode.ks").

    printLine("Warping to close approach...").
    local closeApproachTime is minApproach:SECONDS - 120.
    WARPTO(closeApproachTime).
    WAIT UNTIL TIME:SECONDS >= closeApproachTime.
    printLine("  done").
}

// if closestApproach:ETA > 15 {
//     printLine("Warping to closest approach...").
//     WARPTO(TIME:SECONDS + closestApproach:ETA - 15).
// }

printLine("Closing in on target...").
until distanceBetween(SHIP:POSITION, _target:POSITION) < 500 {
    if SHIP:availablethrust = 0 {
        STAGE.
        wait until STAGE:READY.
    }
    printLine("   Aligning header to target...").
    lock STEERING to _target:POSITION.
    wait until  VANG(SHIP:FACING:FOREVECTOR, _target:POSITION) < 1.5.
    printLine("   Engaging throggle...").
    LOCK THROTTLE TO 0.1.
    wait until (SHIP:VELOCITY:ORBIT - _target:VELOCITY:ORBIT):MAG > 1.
    LOCK THROTTLE TO 0.
    printLine("   Waiting to close in...").
    local newClosestApproach is findClosestApproach(SHIP:ORBIT, _target).
    if newClosestApproach:SECONDS - TIME:SECONDS > 10 {
        WARPTO(newClosestApproach:SECONDS - 10).
        WAIT 10.
    } else {
        WAIT 2.
    }
}
printLine("  done").

// until distanceBetween(SHIP:POSITION, _target:POSITION) < 500  {
//     killRelativeVelocity().
//     if distanceBetween(SHIP:POSITION, _target:POSITION) >= 500 {
//         printLine("Closing in on target.").
//         lock STEERING to _target:POSITION.
//         printLine("Aligning header to target...").
//         wait until VANG(SHIP:FACING:FOREVECTOR, _target:POSITION) <= 1.
//         lock THROTTLE to 0.1.
//         wait until (SHIP:VELOCITY:ORBIT - _target:VELOCITY:ORBIT):MAG > 0.5.
//         lock THROTTLE to 0.
//         local newApproach is findClosestApproach(SHIP:ORBIT, _target).
//         lock STEERING to RETROGRADE.
//         wait 5. // TODO: Instead, wait until heading alings with retrograde?
//         WARPTO(newApproach:SECONDS - 20).
//         wait until TIME:SECONDS >= newApproach:SECONDS - 15.
//     }
// }

// Come to a final stop.
killRelativeVelocity(0.002).

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