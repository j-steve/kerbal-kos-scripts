lock acceleration to SHIP:AVAILABLETHRUST / SHIP:MASS.

function calcBurnTime {
	parameter deltaV.

	return deltaV / acceleration.
}

function isFacingRetrograde {
	return VANG(SHIP:FACING:FOREVECTOR, -SHIP:VELOCITY:ORBIT:NORMALIZED) < 2.5.
}

function isFacingSurfaceRetrograde {
	return VANG(SHIP:FACING:FOREVECTOR, -SHIP:VELOCITY:SURFACE:NORMALIZED) < 2.5.
}

function clearNodes {
	if hasnode {
		until not hasnode {
			remove nextnode.
			wait 0.25.
		}
	}
}

// Returns the orbital patch for the given SOI, if possible.
function findOrbitalPatchForSoi {
    parameter orbitPatch, targetSoi.

    until orbitPatch:BODY = targetSoi or not orbitPatch:HASNEXTPATCH {
        set orbitPatch to orbitPatch:NEXTPATCH.
    }
    return orbitPatch.
}

// Given an orbit and a target, returns the closest distance that will be reached to the target.
// Returned object contains ":DISTANCE" and ":SECONDS" fields.
function findClosestApproach {
	parameter _orbit, _target, _startTime is -1, _endTime is -1, _orbitSteps is -1, _earlyReturnOnDistIncrease is false.

	if _startTime = -1 {set _startTime to TIME:SECONDS.}
	if _endTime = -1 {set _endTime to choose TIME:SECONDS + _orbit:NEXTPATCHETA if _orbit:HASNEXTPATCH else (_startTime + _orbit:PERIOD).}
	if _orbitSteps = -1 {set _orbitSteps to 1000.}
	if _orbit:PERIAPSIS < 0 {
		// If this "orbit" involves crashing into the body, ignore any positions after the collision time.
		set _endTime to MIN(_endTime, TIME:SECONDS + _orbit:ETA:PERIAPSIS).
	}
	local minDist is distanceBetween(SHIP:POSITION, _target:POSITION).
	local minTime is TIME:SECONDS.
	local stepAmount is (_endTime - _startTime) / _orbitSteps.
	local stepsCompleted is 0.
	//printLine("Finding closest approach from " + round(_startTime) + " to " + round(_endTime)).
	from {local t is _startTime.} until t >= _endTime step {set t to t + stepAmount.} do {
		//printLine("Calculating closest approach...  " + round(stepsCompleted / _orbitSteps * 100, 1) + "%", true).
		local shipPos is POSITIONAT(SHIP,   t).
		local targetPos is POSITIONAT(_target,   t).
        local dist is distanceBetween(shipPos, targetPos).
        IF dist <= minDist {
            SET minDist TO dist.
            SET minTime TO t.
		} else if _earlyReturnOnDistIncrease {
			return Lexicon("distance", minDist, "seconds", minTime, "eta", {return minTime - TIME:SECONDS.}).
		}
		set stepsCompleted to stepsCompleted + 1.
    }
	return Lexicon("distance", minDist, "seconds", minTime, "eta", {return minTime - TIME:SECONDS.}).
}

// Returns the distance between the two positions, in meters.
function distanceBetween {
    parameter pos1, pos2.

	if pos1:HASSUFFIX("Position") {set pos1 to pos1:POSITION.}
	if pos2:HASSUFFIX("Position") {set pos2 to pos2:POSITION.}
    return ABS((pos1 - pos2):MAG).
}

// Adds a navigation node with the given ETA (seconds in the future).
function addNodeAtEta {
	parameter _eta is 0, _prograde is 0, _normal is 0, _radialIn is 0.

	return addNodeAtTime(TIME:SECONDS + _eta, _prograde, _normal, _radialIn).
}
	
// Adds a navigation node with the given Time.
function addNodeAtTime {
	parameter _timeSeconds is 0, _prograde is 0, _normal is 0, _radialIn is 0.

	printLine("Adding nav node with ETA of " + round((_timeSeconds - TIME:SECONDS) / 60) + " minutes.").
	local _node is NODE(_timeSeconds, _prograde, _normal, _radialIn).
    ADD _node.
	return _node.
}

function stageIfNeeded {
	parameter throttleWhileStaging is 0.

	local didStage is false.
	if SHIP:AVAILABLETHRUST = 0 {
		if _shouldStage() {
			local priorThrottle is THROTTLE.
			lock THROTTLE to throttleWhileStaging.
			stage.
			set didStage to true.
			if throttleWhileStaging > 0 {
				// If we are full-throttle staging, continue straight for a few secs to clear the depres.
				wait 5.
			}
			wait until stage:ready.
			lock THROTTLE to priorThrottle.
		}
		else {
			printLine("WARNING: No thrust available.").
			wait 5.
		}
	}
	return didStage.
}

function _shouldStage {
	local hasAnyActiveEngines is false.
	for eng in SHIP:ENGINES {
		if not eng:FLAMEOUT {
			if eng:STAGE = STAGE:NUMBER {
				// Don't stage if there are any engines in this stage that haven't flamed out.
				return false.
			} else {
				set hasAnyActiveEngines to true.
			}
		}
	}
	return hasAnyActiveEngines.
}

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
