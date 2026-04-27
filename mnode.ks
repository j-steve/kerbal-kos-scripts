// -------------------------------------------------------------------------------------------------
// This program executes the next maneuver node by aligning the header, then warping to the node,
// then burning for the necessary amount of deltaV, staging as needed in the process.
//
// Its warp is fast and precise on my PC but may overly agressive on less powerful machines.
// -------------------------------------------------------------------------------------------------

RUNONCEPATH("/common/init.ks").

// The minimum deviation between the expected node and the actual node.
// Lower number means that the final course will match the orignal more precisely,
// but it may take longer to achieve.
declare parameter maxFinalDeviation is 0.1, maxFacingDeviation is -1.
if maxFacingDeviation = -1 {
	set maxFacingDeviation to 1.
}
// NOTE: Atomic engines may show an initial acceleration of 0 (they need to warm up),
lock acceleration to SHIP:AVAILABLETHRUST / SHIP:MASS.

local startupData is startup("Executing next maneuver node.").

// Align header.
alignHeaderTo(NEXTNODE:BURNVECTOR, "maneuver node burn vector").

// Calculate burn time.
printLine("Aligned, warping to node start...").
local burnTime is NEXTNODE:DELTAV:MAG / acceleration.
printLine("  Will burn for " + round(burnTime) + " seconds.").
local halfBurnTime is burnTime / 2.

lock warpTime to NEXTNODE:ETA - halfBurnTime.
printLine("  Warping " + round(warpTime) + " seconds.").
set WARP to 0.
set WARPMODE to "RAILS".
wait 0.5. // Ensure throttle is 0 before we warp.
if warpTime > 36000 { // 10 hours
	printLine("    Warping speed 7").
	set WARP to 7.
	wait warpTime - 36000.
}
if warpTime > 7200 { // 120 mins
	printLine("    Warping speed 6").
	set WARP to 6.
	wait warpTime - 7200.
}
if warpTime > 1800 {  // 30 mins
	printLine("    Warping speed 5").
	set WARP to 5.
	wait warpTime - 1800.
}
if warpTime > 600 {
	printLine("    Warping speed 4").
	set WARP to 4.
	wait warpTime - (600 / 2).
}
if warpTime > 120 {
	printLine("    Warping speed 3").
	set WARP to 3.
	wait warpTime - 120 * 1.25. // Prevent warping past it
}
if warpTime > 50 {
	printLine("    Warping speed 2").
	set WARP to 2.
	wait warpTime - 50.
}
if (warpTime > 0) {
	set WARP to 1.
	printLine("    Warping speed 1").
	wait warpTime - 10.
	printLine("    Warping speed 0").
	KUNIVERSE:TIMEWARP:CANCELWARP().
	wait warpTime.
}
if WARP > 0 {
	printLine("    Warping speed 0").
	KUNIVERSE:TIMEWARP:CANCELWARP().
}

// // Align and freeze.
// alignHeaderTo(NEXTNODE:BURNVECTOR, "maneuver node burn vector", 10).
// set WARP to 1.
// WAIT 0.1.
// KUNIVERSE:TIMEWARP:CANCELWARP().


printLine("Starting burn...").

// Max engine thrust percentage during the final few seconds.
local FINE_TUNE_BURN_RATE is 0.2.

local physicsWarper is buildPhysicsWarper(maxFacingDeviation).
local minThrottler is buildMinThrottler(maxFacingDeviation).
local priorSecsToBurn is NEXTNODE:DELTAV:MAG / acceleration.

until NEXTNODE:DELTAV:MAG < maxFinalDeviation { 
	lock STEERING TO LOOKDIRUP(NEXTNODE:BURNVECTOR, SHIP:UP:VECTOR).
	stageIfNeeded().
	
	local secsToBurn is NEXTNODE:DELTAV:MAG / acceleration.
	local facingError is VANG(SHIP:FACING:FOREVECTOR, NEXTNODE:BURNVECTOR).
	local newThrottle is MAX((1 - sqrt(facingError / maxFacingDeviation)) * 2, 0). // Full stop at an error of maxFacingDeviation.

	physicsWarper:adjustWarpSpeed(secsToBurn, facingError).

	// local minThrottle is minThrottler:findMinThrottle(facingError, newThrottle).
	// set newThrottle to MAX(newThrottle, minThrottle).

	if secsToBurn < 1.5 {
		set newThrottle to MIN(newThrottle, FINE_TUNE_BURN_RATE).
	}

	local burnMessage is "  " + ROUND(secsToBurn, 1) + "s | " + ROUND(facingError, 2) + "dev | " + ROUND(newThrottle, 2) + " burn".
	printLine(burnMessage, true).
	lock throttle to newThrottle.
	wait 0.001.
}
lock THROTTLE to 0.


unlock THROTTLE.
if HASNODE {
	printLine("Burn complete (dev: " + ROUND(NEXTNODE:DELTAV:MAG, 2) + ").").
	remove NEXTNODE.
} else {
	printLine("Burn complete.").
}

startupData:END().

// A "Class" designed to be called in a burn loop, to adjust the physics warp speed as appropriate.
// Initialize with `local physicsWarper to buildPhysicsWarper().` before the loop,
// then invoke its `adjustWarpSpeed` method each iteration.
// This will check the amount of time remaining in the burn and adjust the physics warp accordingly.
function buildPhysicsWarper {
	parameter _maxFacingDeviation.

	// Some ships are too large to safely warp under thurst.
	// Check for angular velocity which should be close to 0 once aligned and under burn.
	// High angular velocity = high "wobble" which can indicate Krackening and pending ship explosion.
	local MAX_WOBBLE_DURING_BURN_WARP is 0.0075.

	// Initialize max safe physics speed to the max possible speed.
	// It'll be reduced when burn time decreases or if warping causes too much wobble.
	local _maxSafePhysicsSpeed is 3.

	return Lexicon("adjustWarpSpeed", {
		parameter _secsToBurn, _facingError.

		if _secsToBurn < 10 {
			set _maxSafePhysicsSpeed to MIN(_maxSafePhysicsSpeed, 0).
		} else if _secsToBurn < 20 {
			set _maxSafePhysicsSpeed to MIN(_maxSafePhysicsSpeed, 1).
		} else if _secsToBurn < 120 {
			set _maxSafePhysicsSpeed to MIN(_maxSafePhysicsSpeed, 2).
		} else {
			set _maxSafePhysicsSpeed to MIN(_maxSafePhysicsSpeed, 3).
		}

		if _secsToBurn > 10 {
			// Use angular velocity to detect the Krackening.
			if SHIP:ANGULARVEL:MAG > MAX_WOBBLE_DURING_BURN_WARP and _maxSafePhysicsSpeed > 0 {
				set _maxSafePhysicsSpeed to WARP - 1.
				printLine("WARNING: Oscilations, slowing warp to " + _maxSafePhysicsSpeed).
				setPhysicsWarpTo(_maxSafePhysicsSpeed).
				wait 2.
			} else if _facingError < _maxFacingDeviation * .5 { // If we are perfectly aligned, increase warp.
				setPhysicsWarpTo(_maxSafePhysicsSpeed).
			} else {
				KUNIVERSE:TIMEWARP:CANCELWARP().
			}
		} else {
			KUNIVERSE:TIMEWARP:CANCELWARP().
		}
	}).
}


// Checks if we've stopped burning completely due to misalignment.  
// If so let's make sure we actually are getting to be MORE aligned while waiting,
// Otherwise it's possible that our ship alignment is not correctable without the engine,
// (meaning SAS is weak or absent and can't keep up with the changing vector of the nav node).
// In that situation it may be better to just force the burn even if we are very misaligned,
// since angling the engine wil help course-correct.
function buildMinThrottler {
	parameter _maxFacingDeviation.

	// Check every X seconds to see if we need to increase our min burn;
	// i.e., wait X seconds after adjustments to allow a chance to course correct.
	local STOP_BURN_CHECK_SECS is 3.

	// If we have an uncorrectable facing error of this amount of degrees or higher,
	// the system will terminate in an error state, because we cannot complete the objective.
	// Less than X degrees implies we're still ROUGHLY on target.
	local HARD_MAX_FACING_DEVIATION is 90.

	local minThrottle is 0.
	local stoppedBurningTime is -1.
	local stoppedBurningFacingError is -1.

	return Lexicon("findMinThrottle", {
		parameter _facingError, _currentThrottle.

		if _currentThrottle = 0 and _facingError > _maxFacingDeviation / 2 {
			if stoppedBurningTime = -1 {
				set stoppedBurningTime to TIME:SECONDS.
				set stoppedBurningFacingError to _facingError.
			} else if _facingError < stoppedBurningFacingError {
				// We are more aligned than when we (basically) stopped burning,
				// so things are improving.  Reset the counter and take no action for now.
				set stoppedBurningTime to -1.
				set stoppedBurningFacingError to -1.
			} else if TIME:SECONDS - stoppedBurningTime > STOP_BURN_CHECK_SECS and _facingError < HARD_MAX_FACING_DEVIATION {
				if minThrottle < 1  {
					set minThrottle to minThrottle + 0.1.
					set stoppedBurningTime to -1.
					set stoppedBurningFacingError to -1.
					printLine("WARNING: Unaligned, up min. burn to " + minThrottle).
				} else if minThrottle >= 1 and _facingError > MAX_FACING_ERROR {
					throwError("Cannot correct facing deviation.").
				}
			}
		} else {
			set stoppedBurningTime to -1.
			set stoppedBurningFacingError to -1.
		}
		return minThrottle.
	}).
}