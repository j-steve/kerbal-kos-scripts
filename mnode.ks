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
	set maxFacingDeviation to maxFinalDeviation * 10.
}

local startupData is startup("Executing next maneuver node.").

// Align header.
alignHeaderTo(NEXTNODE:BURNVECTOR, "maneuver node burn vector").

// Pre-stage, if needed
// until SHIP:AVAILABLETHRUST > 0 {
// 	print "No thrust, staging.".
// 	stage.
// 	wait until STAGE:READY.
// }

// Calculate burn time.
printLine("Aligned, warping to node start...").
// Atomic engines may show an initial acceleration of 0 (they need to warm up), change to a small number instead.
lock acceleration to MAX(SHIP:AVAILABLETHRUST / SHIP:MASS, 0.001). 
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
	set warpTime to NEXTNODE:ETA - halfBurnTime.
}
if warpTime > 600 { 
	printLine("    Warping speed 4").
	set WARP to 4.
	wait warpTime - (600 / 2).
	set warpTime to NEXTNODE:ETA - halfBurnTime.
}
if warpTime > 120 {
	printLine("    Warping speed 3").
	set WARP to 3.
	wait warpTime - 120 * 2. // Prevent warping past it
	set warpTime to NEXTNODE:ETA - halfBurnTime.
}
if warpTime > 50 {
	printLine("    Warping speed 2").
	set WARP to 2.
	wait warpTime - 50.
	set warpTime to NEXTNODE:ETA - halfBurnTime.
}
if (warpTime > 0) {
	set WARP to 1.
	printLine("    Warping speed 1").
	wait warpTime - 10.
	printLine("    Warping speed 0").
	KUNIVERSE:TIMEWARP:CANCELWARP().
	set warpTime to NEXTNODE:ETA - halfBurnTime.
	wait warpTime.
}
if WARP > 0 {
	printLine("    Warping speed 0").
	KUNIVERSE:TIMEWARP:CANCELWARP().
}

printLine("Starting burn...").

// Some ships are too large to safely warp under thurst.
// Check for angular velocity which should be close to 0 once aligned and under burn.
// High angular velocity = high "wobble" which can indicate Krackening and pending ship explosion.
local MAX_WOBBLE is 0.0075.
// Max engine thrust
local FINE_TUNE_BURN_RATE is 0.2.
lock facingError to ABS(VANG(SHIP:FACING:FOREVECTOR, NEXTNODE:BURNVECTOR)).
lock safeThrottle to 1 - sqrt(facingError / maxFacingDeviation). // Full stop at an error of maxFacingDeviation.
lock secsToBurn to NEXTNODE:DELTAV:MAG / acceleration.
lock burnMessage to "  " + ROUND(secsToBurn, 1) + "s | " + ROUND(facingError, 2) + " facing error.".
local burnType is "normal".
local maxSafePhysicsSpeed is 3.

printLine("Starting burn sequence...").

until NEXTNODE:DELTAV:MAG < maxFinalDeviation {
	local newThrottle is safeThrottle.
	if secsToBurn > 10 {
		// Use angular velocity to detect the Krackening.
		if SHIP:ANGULARVEL:MAG > MAX_WOBBLE and WARP > 0 and maxSafePhysicsSpeed > 0 {
			printLine("WARNING: Oscilations, slowing warp to " + maxSafePhysicsSpeed).
			set maxSafePhysicsSpeed to WARP - 1.
			setPhysicsWarpTo(maxSafePhysicsSpeed).
			wait 2.
		} else if facingError < maxFacingDeviation * .5 { // If we are perfectly aligned, increase warp.
			setPhysicsWarpTo(maxSafePhysicsSpeed).
		} else {
			KUNIVERSE:TIMEWARP:CANCELWARP().
		}
	} else {
		KUNIVERSE:TIMEWARP:CANCELWARP().
		if secsToBurn < 1.5 {
			set newThrottle to MIN(newThrottle, FINE_TUNE_BURN_RATE).
		}
	}
	printLine(burnMessage, true).
	lock throttle to newThrottle.
	wait 0.001.
}
lock THROTTLE to 0.


unlock THROTTLE.
if HASNODE {
	printLine("Burn complete (deviation: " + ROUND(NEXTNODE:DELTAV:MAG, 2) + "%).").
	remove NEXTNODE.
} else {
	printLine("Burn complete.").
}

startupData:END().