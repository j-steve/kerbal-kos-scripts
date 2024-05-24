RUNONCEPATH("common.ks").
RUNONCEPATH("nodeTuner.ks").

local _target is TARGET.  // In case taget becomes unset.

local startupData is startup("Revendousing with " + _target:NAME + ".").
// local closestApproach is findClosestApproach(SHIP:ORBIT).
// printLine("Current dist is " + round(distanceBetween(SHIP:POSITION, _target:POSITION), 2)).
// printLine("Closest dist is " + round(closestApproach:DISTANCE, 2)).
// printLine("Closest dist eta is " + round(closestApproach:ETA, 2)).

if distanceBetween(SHIP:POSITION, _target:POSITION) > 5000 {
    local revNode is NODE(TIME:SECONDS + 60 * 10, 0,0,0).
    ADD revNode.
    printLine("Tuning node...").
    tuneNode(revNode, {return findClosestApproach(revNode:ORBIT):DISTANCE.}, .001, .1).
    printLine("  done").
    RUNPATH("mnode.ks").

    printLine("Warping to close approach...").
    local closeApproachTime is findClosestApproach(SHIP:ORBIT):SECONDS - 120.
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
//     local newClosestApproach is findClosestApproach(SHIP:ORBIT).
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
        local newApproach is findClosestApproach(SHIP:ORBIT).
        WARPTO(newApproach:SECONDS - 20).
        WAIT 15.
    }
}
killRelativeVelocity(0.001).

// Returns the distance between the two positions, in M.
function distanceBetween {
    parameter pos1, pos2.
    return ABS((pos1 - pos2):MAG).
}


function findClosestApproach {
	parameter _orbit.
    printLine("Calculating closest approach... ").
	local minDist is distanceBetween(SHIP:POSITION, _target:POSITION).
	local minTime is TIME:SECONDS.
    local maxPeriod is choose _orbit:NEXTPATCHETA if _orbit:HASNEXTPATCH else _orbit:PERIOD.
	from {local t is TIME:SECONDS.} until t >=  TIME:SECONDS + maxPeriod step {set t to t + 20.} do {
		local shipPos is POSITIONAT(SHIP,   t).
		local targetPos is POSITIONAT(_target,   t).
        local dist is distanceBetween(shipPos, targetPos).
        IF dist <= minDist {
            SET minDist TO dist.
            SET minTime TO t.
		}
    }
    printLine("  done").
	return Lexicon("distance", minDist, "seconds", minTime).
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
        //printLine("facingDeviation " + (1 - facingDeviation / 360), true).
        //printLine("Relative velocity is " + round(relativeVelocity:MAG), true).
        //lock throttle to (1 - facingDeviation / 360).
        wait 0.0001.
    }
    unlock STEERING.
    printLine("  done").
}


startupData:END().