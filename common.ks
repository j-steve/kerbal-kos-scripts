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
	}).
}