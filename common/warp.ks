
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

// Executes a warp to the given ETA, and waits until we are there.
function warpToEta {
	parameter _warpToEta.
	warpToTime(TIME:SECONDS + _warpToEta).
}

// Executes a warp to the given Time, and waits until we are there.
function warpToTime {
	parameter _warpToTime.
	printLine("Warping " + round((_warpToTime - TIME:SECONDS) / 60) + " minutes.").
	wait 1. // Wait 1 sec just in case we recently set the throttle to 0.
	SET WARPMODE to "RAILS".
	WARPTO(_warpToTime).
	wait until TIME:SECONDS >= _warpToTime.
	KUNIVERSE:TIMEWARP:CANCELWARP(). // Ensure warp is set to 0.
}