RUNONCEPATH("common.ks").
RUNONCEPATH("nodeTuner.ks").

local _target is TARGET.  // In case taget becomes unset.

local startupData is startup("Revendousing with " + _target:NAME + ".").

if _target:ISTYPE("Part") {set _target to _target:SHIP.}

local updatedMinApproach to findClosestApproach(SHIP:ORBIT, _target, TIME:SECONDS, -1, 500).
if updatedMinApproach:DISTANCE > 5000 {
    // Start at a point 10 minutes in the future, 
    // mainly to enusre that the position is STILL in the future
    // once we've finished these calculations.
    // TODO: We should be able to use a hoffman transfer here instead.
    //local burnStartTime is 10 * 60.
    local burnStartTime is choose ETA:PERIAPSIS if _target:APOAPSIS > SHIP:APOAPSIS else ETA:APOAPSIS.
    local revNode is NODE(TIME:SECONDS + burnStartTime, 0,0,0).
    ADD revNode.
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
                local closeApproach is findClosestApproach(revNode:ORBIT, _target, revNode:TIME, -1, 500).
                    return choose 0 if closeApproach:DISTANCE < 250 else closeApproach:DISTANCE.
            }, .01, .5).
        set minApproach to findClosestApproach(revNode:ORBIT, _target, revNode:TIME, -1, 500).
        printLine("  Min approach: " + round(minApproach: DISTANCE)).
        set orbitCountI to orbitCountI + 1.
    }
    RUNPATH("mnode.ks").

    printLine("  done").
    set updatedMinApproach to findClosestApproach(SHIP:ORBIT, _target, TIME:SECONDS, -1, 500).
}

until updatedMinApproach:DISTANCE < 1000 {
    printLine("Fine-tuning approach").
    local fineTuneBurnTime is MAX((TIME:SECONDS + updatedMinApproach:SECONDS) / 2, TIME:SECONDS + 2 * 60).
    local fineTuneNode is NODE(fineTuneBurnTime, 0, 0, 0).
    //local searchEndTime is (fineTuneNode:ETA) * 2.
    local searchEndTime is -1.
    ADD fineTuneNode.
    tuneNode(fineTuneNode, {
                    local closeApproach is findClosestApproach(SHIP:ORBIT, _target, fineTuneNode:TIME, searchEndTime, 500).
                    return choose 0 if closeApproach:DISTANCE < 250 else closeApproach:DISTANCE.
                }, .001, .01).
    RUNPATH("mnode.ks").
    set updatedMinApproach to findClosestApproach(SHIP:ORBIT, _target, TIME:SECONDS, -1, 500).
}

local closeApproachTime is findClosestApproach(SHIP:ORBIT, _target, TIME:SECONDS, -1, 500):SECONDS - 120.
if TIME:SECONDS < closeApproachTime and not _isWithin(1000) {
    printLine("Warping to close approach time...").
    WARPTO(closeApproachTime).
    WAIT UNTIL TIME:SECONDS >= closeApproachTime.
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
closeInOnTarget(150).

// Come to a final stop.
local finalStopSection is printSectionStart("Coming to a final stop...").
killRelativeVelocity(0.002).
finalStopSection:END().

// Exit program.
UNLOCK STEERING.
startupData:END().

function _isWithin {
    parameter _distance.
    return distanceBetween(SHIP:POSITION, _target:POSITION) < _distance.
}

// Gets very close to target, by progressively coming to a complete stop, pointing at target, and thrusting slightly,
// then coasting until reaching maximum closeness and repeating.  
function closeInOnTarget {
    parameter _distance.
    local closingInSection is printSectionStart("Closing in to within " + _distance + " of target.").

    until _isWithin(_distance) {
        killRelativeVelocity(0.1).
        
        if SHIP:availablethrust = 0 {
            printLine("Staging").
            STAGE.
            wait until STAGE:READY.
        }

        printLine("Aligning header to target...").
        lock STEERING to _target:POSITION.
        wait until ABS(VANG(SHIP:FACING:FOREVECTOR, _target:POSITION)) < 1.5 or _isWithin(_distance).

        printLine("Engaging throggle...").
        LOCK THROTTLE TO 0.1.
        wait until (SHIP:VELOCITY:ORBIT - _target:VELOCITY:ORBIT):MAG > 1 or _isWithin(_distance).
        LOCK THROTTLE TO 0.
        local newClosestApproach is findClosestApproach(SHIP:ORBIT, _target).

        printLine("Aligning ship for counterthrust...").
        lock STEERING to -_target:POSITION.
        wait until ABS(VANG(SHIP:FACING:FOREVECTOR, -_target:POSITION)) < 1.5 or _isWithin(_distance).

        printLine("Waiting get within " + _distance + "...").
        local ratherCloseApproachSeconds is newClosestApproach:SECONDS - 90.
        if TIME:SECONDS < ratherCloseApproachSeconds or _isWithin(_distance) {
            // If it's a long wait, use WARPTO to get close.
            WARPTO(ratherCloseApproachSeconds).
            wait until TIME:SECONDS >= ratherCloseApproachSeconds.
        }
        if TIME:SECONDS >= newClosestApproach:SECONDS - 10 and _isWithin(_distance) {
            set WARP to 2.
            wait until TIME:SECONDS >= newClosestApproach:SECONDS - 10 or _isWithin(_distance).
            kuniverse:timewarp:cancelwarp().
        }
    }
    closingInSection:END("done").
}

function killRelativeVelocity {
    parameter maxRelativeVelocity is 0.05, timeoutSeconds is 120.
    lock relativeVelocity to SHIP:VELOCITY:ORBIT - _target:VELOCITY:ORBIT.
    lock retrogradeDirection to -relativeVelocity:NORMALIZED.
    lock STEERING to retrogradeDirection.
    local maxEndTime is TIME:SECONDS + timeoutSeconds.
    local killVeloSection is printSectionStart("Killing relative velocity...").
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
        local facingDeviation is VANG(SHIP:FACING:FOREVECTOR, retrogradeDirection).
        local facingAccuracyPercent is 1 - facingDeviation / 360.
        local throttleVal is choose MIN(maxThrottle, SQRT(facingAccuracyPercent)) if facingAccuracyPercent > 0.95 else 0.
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
    unlock STEERING.
    killVeloSection:END("done").
}