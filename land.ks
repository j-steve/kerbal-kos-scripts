// -------------------------------------------------------------------------------------------------
// This program lands on a body with no atmosphere by plotting an intercept course
// and firing thrusters in such a way as to set down gently on the surface.
//
// For landing on a body with an atmosphere, see `return.ks`.
//
// TODO: This script may not work well for vessels with a low TWR?  More testing needed to confirm.
// -------------------------------------------------------------------------------------------------

RUNONCEPATH("common.ks").

clearscreen.
SAS off.
printLine("Executing landing.").
printLine("").

// The minimum safe time for a burn; shorter than this and there is the risk of accidentally burning too long,
// so we will lower the max engine output accordingly.
local MIN_BURN_TIME is 1.5.
// Height in m at which to shut off the engines, should be slightly above ground level so we fall the last few meters.
local ENGINE_CUTOFF_ALTITUDE is 1.
// Pretend the terrain is this many meters higher, so that we land with some buffer.
local RADAR_HEIGHT_OFFSET is 0.
// If the jets aren't on and collision is within this many seconds, turn on the jets!!  There might not be time for a correction otherwise.
local MIN_COLLISION_ETA is 5.
// How many seconds ahead of a start time we should come out of warp, to be safe.  Prevents warping past the expected start time.
local WARP_BUFFER_SECONDS is 30.

local shipHeightOffset is calcShipHeight().

lock fallSpeed to -VERTICALSPEED.
lock collisionEta to (ALT:RADAR - shipHeightOffset - RADAR_HEIGHT_OFFSET) / fallSpeed.
lock acceleration to SHIP:AVAILABLETHRUST / SHIP:MASS.
lock surfaceBurnTime to SHIP:VELOCITY:SURFACE:MAG / acceleration.

if PERIAPSIS > 0 {
	local retrogradeSection is printSectionStart("Burning retrograde to intercept planet...").
	alignRetrograde().
	lock THROTTLE to 1.
	wait until PERIAPSIS <= 0.
	lock THROTTLE to 0.
	wait 0.
	retrogradeSection:END().
}

if ALT:RADAR > 25000 {
	printLine("Warping to get close...").
	set WARP to 4.
	wait until ALT:RADAR < 25000.
}

// Burn to 0 so we are falling straight down.
set WARP to 0.
lock lateralMotion to abs(SHIP:VELOCITY:SURFACE:MAG - abs(fallSpeed)).
set closeEnoughTimeout to 0.
lock STEERING to SRFRETROGRADE.
if lateralMotion > 0.11 and (collisionEta < 0 or collisionEta > 60) {
	printLine("Aligning surface retrograde...").
	local alignmentTimeout is TIME:SECONDS + 60.
	wait until isFacingSurfaceRetrograde() or TIME:SECONDS >= alignmentTimeout.
	printLine("Burning retrograde to kill lateral motion...").
	until lateralMotion < 0.01 or (collisionEta > 0 and collisionEta < 60) {
		if isFacingRetrograde() {
			lock orbitBurnTime to SHIP:VELOCITY:ORBIT:MAG / acceleration.
			if orbitBurnTime > MIN_BURN_TIME {
				printLine("  Doing solid burn for <= " + round(orbitBurnTime) + "s", true).
				setThrottle(1).
			}
			if SHIP:VELOCITY:ORBIT:MAG / acceleration  < 2 {
				printLine("  Doing correction burn | lateral speed: " + round(lateralMotion), true).
				setThrottle(0.2).
			}
			// Prevent getting stuck forever making small changes.
			if lateralMotion < 15 {
				if closeEnoughTimeout = 0 {
					set closeEnoughTimeout to time:seconds + 30.
				} else if time:seconds >= closeEnoughTimeout {
					printLine("  Close enough, correction timed out. | lateral speed: " + round(lateralMotion)).
					break.
				}
			}
		} else {
			printLine("  Waiting for alignment | lateral speed: " + round(lateralMotion), true).
			lock THROTTLE to 0.
		}
		wait 0.001.
	}
	lock THROTTLE to 0.
	unlock THROTTLE.
	printLine("  done").
}
if collisionEta < 60 {
	printLine("No time for lateral burn kill, collision in " + round(collisionEta)).
}

// Lock steering to surface retrograde.
printLine("Angling to surface retrograde..."). 
lock STEERING to SRFRETROGRADE.
wait until isFacingSurfaceRetrograde() or collisionEta - surfaceBurnTime < WARP_BUFFER_SECONDS.
printline("  done").

// Wait for final descent burn time start (warp if needed).
printLine("Waiting for final descent burn...").
if collisionEta - surfaceBurnTime > WARP_BUFFER_SECONDS {
	printLine("  Warping to get closer to burn time...").
	wait 1. // Not sure why this is needed, maybe warp cant start because engine is still running?
	set WARP to 2.
	wait until collisionEta - surfaceBurnTime < WARP_BUFFER_SECONDS or collisionEta < MIN_COLLISION_ETA.
	set WARP to 0.
	printLine("    done").
}
until surfaceBurnTime >= collisionEta {
	printLine("  collision: " + round(collisionEta) + "s | burn time: " + round(surfaceBurnTime) + "s", true).
	wait 0.001.
}

// Execute final descent burn.
set WARP to 0.
printLine("Starting final descent burn...").
until ALT:RADAR <= shipHeightOffset + ENGINE_CUTOFF_ALTITUDE or SHIP:STATUS = "LANDED" or SHIP:STATUS = "SPLASHED" {
	printLine("  collision: " + round(collisionEta) + "s | burn time: " + round(surfaceBurnTime) + "s | speed: " + round(fallSpeed), true).
	setThrottle(surfaceBurnTime / collisionEta).
}
printLine("  done").

// Stabalize touchdown.
lock STEERING to UP.
lock THROTTLE to 0.
unlock THROTTLE.
printLine("Landed! (Hopefully!)").
printLine("Stabalizing for 20s...").
wait 20.

// Exit the program.
printLine("Landing sequence complete.").
SAS on.
unlock STEERING.

function setThrottle {
	parameter throttleVal.
	if SHIP:AVAILABLETHRUST = 0 {
		lock THROTTLE to 0.
		stage.
		wait 10. // Wait for new values so acceleration is updated for next stage.
		set shipHeightOffset to calcShipHeight().
	} else {
		lock THROTTLE to throttleVal.
	}
}

// Returns the height of the ship above ground.
// Specifically, the height of the core part (the space capsule or control pod) 
// relative to the height of the lowest-level part (presumably an engine).
// Useful because basic altitutde caluclation is relative to the core of the ship, not its base.
function calcShipHeight {
	local lowestPart is getLowestPart().
	return getPartHeight(SHIP:PARTS[0]) - getPartHeight(lowestPart).
}

function getLowestPart {
    local lowestPartHeight is getPartHeight(SHIP:PARTS[0]).
	local lowestPart is SHIP:PARTS[0].
    for part in SHIP:PARTS {
        local partHeight is getPartHeight(part).
        if partHeight < lowestPartHeight {  // Remember, more negative means further back along -facing vector
            set lowestPartHeight to partHeight.
            set lowestPart to part.
        }
    }
    return lowestPart.
}

// Given a part, returns its vertical height on the ship.
function getPartHeight {
	parameter part.
	return vdot(SHIP:FACING:FOREVECTOR, part:POSITION).
}
