lock acceleration to SHIP:AVAILABLETHRUST / SHIP:MASS.

function executeBurn {
	parameter deltaV.
	
	printLine("Starting burn...").
	set burnTime to calcBurnTime(deltaV).
	if (burnTime > 1) {
		lock THROTTLE to 1.0.
		if SHIP:DELTAV:CURRENT < deltaV {
			printLine("Insufficient thrust in this stage, will have to stage mid-burn.").
			set stageBurnTime to SHIP:DELTAV:CURRENT / acceleration.
			wait until SHIP:DELTAV:CURRENT < 0.001.
			printLine("Staging.").
			stage.
			set burnTime to burnTime - stageBurnTime.
		}
		wait until deltaV / acceleration < 2.
	}
	lock THROTTLE to 0.1.
	wait until deltaV < 1.  // TODO: WONT WORK BECAUSE DeltaV is static.
	lock THROTTLE to 0.01.
	wait until deltaV < .1.
	lock THROTTLE to 0.
	unlock THROTTLE.
	printLine("Burn complete.").
}

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

function printLine {
	parameter text, overwriteLast is false.
	if (overwriteLast) {
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
			print CLEAR_LINE at (0, currentPrintLine - 1).
		}
		set currentPrintLine to currentPrintLine + 1.
		print text.
	}
	set priorLineOverwritable to overwriteLast.
}