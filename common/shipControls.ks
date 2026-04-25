RUNONCEPATH("common.ks").

// Aligns the ship's header to retrograde orbit vector.
// Optional parameters:
//   timeoutSeconds: Maximum time to wait for alignment (default 6000s).
//   maxDeviation: Maximum acceptable angle deviation in degrees (default 0.25).
function alignHeaderToRetrograde {
	parameter timeoutSeconds is 6000, maxDeviation is 0.25.

	alignHeaderTo(-SHIP:VELOCITY:ORBIT, "retrograde", timeoutSeconds, maxDeviation).
}

// Aligns the ship's header to a specific target vector.
// Parameters:
//   targetVector: The vector to align to.
//   vectorDescription: A string describing the vector (used for logging).
//   timeoutSeconds: Maximum time to wait for alignment (default 6000s).
//   maxDeviation: Maximum acceptable angle deviation in degrees (default 0.25).
function alignHeaderTo {
	parameter targetVector, vectorDescription, timeoutSeconds is 6000, maxDeviation is 0.25.

	local alignmentTimeout is TIME:SECONDS + timeoutSeconds.
	printLine("Aligning header to " + vectorDescription + "...").
	KUNIVERSE:TIMEWARP:CANCELWARP().
	SAS off.
	lock STEERING TO LOOKDIRUP(targetVector, SHIP:UP:VECTOR).
	setPhysicsWarpTo(4).
	wait until VANG(SHIP:FACING:FOREVECTOR, targetVector) < (maxDeviation * 10000) or TIME:SECONDS > alignmentTimeout.
	setPhysicsWarpTo(3).
	wait until VANG(SHIP:FACING:FOREVECTOR, targetVector) < (maxDeviation * 1000) or TIME:SECONDS > alignmentTimeout.
	setPhysicsWarpTo(2).
	wait until VANG(SHIP:FACING:FOREVECTOR, targetVector) < (maxDeviation * 100) or TIME:SECONDS > alignmentTimeout.
	setPhysicsWarpTo(1).
	wait until VANG(SHIP:FACING:FOREVECTOR, targetVector) < (maxDeviation * 10) or TIME:SECONDS > alignmentTimeout.
	setPhysicsWarpTo(0).
	wait until VANG(SHIP:FACING:FOREVECTOR, targetVector) < (maxDeviation) or TIME:SECONDS > alignmentTimeout.
	if TIME:SECONDS > alignmentTimeout {
		printLine("WARNING: Failed to align after " + timeoutSeconds + " seconds, aborting.").
	} else {
		printLine("    Aligned.").
	}
	KUNIVERSE:TIMEWARP:CANCELWARP().
}

// Increases the physics warp to the target warp, up to a maximum.
// Does not decrease the warp if it is already higher.
// Parameters:
//   _targetWarp: The desired physics warp level (e.g., 2, 3, 4).
function increasePhysicsWarpTo {
	parameter _targetWarp.

	set WARPMODE to "PHYSICS".
	set WARP to MAX(_targetWarp, WARP).
}
// Sets the physics warp to the target warp, unconditionally.
// Parameters:
//   _targetWarp: The exact physics warp level to set.
function setPhysicsWarpTo {
	parameter _targetWarp.

	set WARPMODE to "PHYSICS".
	set WARP to _targetWarp.
}