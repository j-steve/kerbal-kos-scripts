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

local currentPrintLine is -1.
local priorLineOverwritable is false.
local CLEAR_LINE is "                                                                                                  ".
local isFirstPrint is true.

function printLine {
	parameter text, overwriteLast is false.
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
			set currentPrintLine to currentPrintLine + 1.
		}
		print text.
	}
	set priorLineOverwritable to overwriteLast.
}

// Given two orbit radiuses, calculates the semi-major axis between them, which is the straight-line distance between the them
// (assuming both orbits are circular and on the same plane).
function calcSemiMajorAxis {
	parameter radius1, radius2.
	return (radius1 + radius2) / 2.
}

function calcVisViva {
    parameter rCurrent, aCurrent, rManeuver, aNew.
    // Calculate current orbital speed
    local vCurrent is sqrt(body:mu * (2 / rCurrent - 1 / aCurrent)).
    // Calculate required orbital speed at the point of maneuver
    local vNew is sqrt(body:mu * (2 / rManeuver - 1 / aNew)).
    // Calculate delta-v
    local deltaV is abs(vNew - vCurrent).
    return deltaV.
}

function startup {
	parameter message is "".
	if message <> "" {
		printLine(message).
	}
	local sasWasOn is false.
	if SAS {
		set sasWasOn to true.
	}
	return Lexicon("END", {
		if sasWasOn {
			set SAS to true.
		}
		unlock THROTTLE.
		unlock STEERING.
		SAS on.
	}).
}