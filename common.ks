@lazyGlobal OFF.
RUNONCEPATH("orbitalMechanics.ks").

lock acceleration to SHIP:AVAILABLETHRUST / SHIP:MASS.

function calcBurnTime {
	parameter deltaV.
	return deltaV / acceleration.
}

function alignRetrograde {
	printLine("Aligning heading to retrograde...").
	set WARP to 0.
	SAS off.
	lock STEERING to RETROGRADE.
	wait until isFacingRetrograde().
	printLine("  OK").
}

function isFacingRetrograde {
	return VANG(SHIP:FACING:FOREVECTOR, -SHIP:VELOCITY:ORBIT:NORMALIZED) < 1.
}

function isFacingSurfaceRetrograde {
	return VANG(SHIP:FACING:FOREVECTOR, -SHIP:VELOCITY:ORBIT:NORMALIZED) < 1.
}

function clearNodes {
	if hasnode {
		until not hasnode {
			remove nextnode.
			wait 0.25.
		}
	}
}

local currentPrintLine is 0.
local priorLineOverwritable is false.
local CLEAR_LINE is "                                                                                                  ".
local isFirstPrint is true.
local printPrefix is "".

function printLine {
	parameter text, overwriteLast is false.
	set text to printPrefix + text.
	if not overwriteLast {log (round(TIME:SECONDS) + ": " + text) to "log.txt".}
	set text to text:SUBSTRING(0, MIN(text:LENGTH, Terminal:WIDTH)).
	if isFirstPrint {
		CLEARSCREEN.
		set isFirstPrint to false.
	}
	if overwriteLast {
		if not priorLineOverwritable {
			// Add a "real" line for this overwritable line to use, to prevent it from overwriting non-overwritable text
			// and so that subsequent "print" statements show up on the subsequent line rather than on this line.
			print "".
		}
		set text to text + CLEAR_LINE.
		print text at (0, currentPrintLine).
	} else {
		if priorLineOverwritable {
			// Clear the text from the prior line.
			//print CLEAR_LINE at (0, currentPrintLine).
		} else {
		}
		print text.
		set currentPrintLine to currentPrintLine + 1.
	}
	set priorLineOverwritable to overwriteLast.
}

function printSectionStart {
	parameter text.
	printLine(text).
	set printPrefix to printPrefix + "  ".
	return Lexicon("END", {
		parameter endText is "".
		if endText <> "" {printLine(endText).}
		set printPrefix to printPrefix:REMOVE(0,2).
	}).
}

// Returns the orbital patch for the given SOI, if possible.
function findOrbitalPatchForSoi {
    parameter orbitPatch, targetSoi.
    until orbitPatch:BODY = targetSoi or not orbitPatch:HASNEXTPATCH {
        set orbitPatch to orbitPatch:NEXTPATCH.
    }
    return orbitPatch.
}

function startup {
	parameter message is "".
	local printSection is -1.
	if message <> "" {
		set printSection to printSectionStart(message).
	}
	local sasWasOn is false.
	if SAS {
		set sasWasOn to true.
		set SAS to false.
	}
	return Lexicon("END", {
		parameter _endMessage is "".
		if sasWasOn {
			set SAS to true.
		}
		unlock THROTTLE.
		unlock STEERING.
		if printSection <> -1 {
			printSection:END(_endMessage).
		}
	}).
}

// Given an orbit and a target, returns the closest distance that will be reached to the target.
// Returned object contains ":DISTANCE" and ":SECONDS" fields.
function findClosestApproach {
	parameter _orbit, _target, _startTime is TIME:SECONDS, _endTime is -1, _orbitSteps is 1000.
	if _endTime = -1 {
		set _endTime to choose TIME:SECONDS + _orbit:NEXTPATCHETA if _orbit:HASNEXTPATCH else (_startTime + _orbit:PERIOD).
	}
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
		}
		set stepsCompleted to stepsCompleted + 1.
    }
	return Lexicon("distance", minDist, "seconds", minTime).
}

// Returns the distance between the two positions, in meters.
function distanceBetween {
    parameter pos1, pos2.
    return ABS((pos1 - pos2):MAG).
}

// Executes a warp to the given ETA, and waits until we are there.
function warpToEta {
	parameter _warpToEta.
	warpToTime(TIME:SECONDS + _warpToEta).
}

// Executes a warp to the given Time, and waits until we are there.
function warpToTime {
	parameter _warpToTime.
	printLine("Warping " + round(_warpToTime - TIME:SECONDS / 60) + "minutes.").
	wait 0. // Wait 1 frame just in case we recently set the throttle to 0.
	WARPTO(_warpToTime).
	wait until TIME:SECONDS >= _warpToTime.
	KUNIVERSE:TIMEWARP:CANCELWARP(). // Ensure warp is set to 0.
}