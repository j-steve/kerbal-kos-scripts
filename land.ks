RUNPATH("0:/common.ks").

clearscreen.
printLine("Executing landing.").
printLine("").

// The minimum safe time for a burn; shorter than this and there is the risk of accidentally burning too long,
// so we will lower the max engine output accordingly.
local MIN_BURN_TIME is 1.5.
// Height in m above actual ground level at which we will target coming to a complete stop.
local TARGET_STOP_ALTITUDE is 10.
// Height in m at which to shut off the engines, should be slightly above ground level so we fall the last few meters.
local ENGINE_CUTOFF_ALTITUDE is 1.
// If the jets aren't on and collision is within this many seconds, turn on the jets!!  There might not be time for a correction otherwise.
local MIN_COLLISION_ETA is 5.
// How many seconds ahead of a start time we should come out of warp, to be safe.  Prevents warping past the expected start time.
local WARP_BUFFER_SECONDS is 30.

local shipHeightOffset = calcShipHeightOffset().

lock fallSpeed to -VERTICALSPEED.
lock collisionEta to (ALT:RADAR + TARGET_STOP_ALTITUDE) / fallSpeed.


if ALT:RADAR > 50000 {
	printLine("Warping to get close...").
	set WARP to 4.
	wait until ALT:RADAR < 50000.
}

set WARP to 0.

// Burn to 0 so we are falling straight down.
lock lateralMotion to abs(SHIP:VELOCITY:SURFACE:MAG - abs(fallSpeed)).
if lateralMotion > 0.11 and collisionEta > 60 {
	alignRetrograde().
	printLine("Burning retrograde to kill lateral motion...").
	until lateralMotion < 0.1 or collisionEta < 60 {
		if isFacingRetrograde() {
			lock acceleration to SHIP:AVAILABLETHRUST / SHIP:MASS.
			lock orbitBurnTime to SHIP:VELOCITY:ORBIT:MAG / acceleration.
			if orbitBurnTime > MIN_BURN_TIME {
				printLine("  Doing solid burn for <= " + round(orbitBurnTime) + "s", true).
				lock THROTTLE to 1.
			}
			if SHIP:VELOCITY:ORBIT:MAG  < 10 {
				printLine("  Doing correction burn | lateral speed: " + round(lateralMotion), true).
				lock THROTTLE to 0.2.
			}
		} else {
			printLine("  Waiting for alignment | lateral speed: " + round(lateralMotion), true).
			lock THROTTLE to 0.
		}
	}
	lock THROTTLE to 0.
	unlock THROTTLE.
	printLine("  done").
}
if collisionEta < 60 {
	printLine("No time for lateral burn kill, collision in " + collisionEta).
}

// Lock steering to surface retrograde.
printLine("Locking steering to surface retrograde."). 
lock STEERING to SRFRETROGRADE..

// Wait for final descent burn time start (warp if needed).
printLine("Waiting for final descent burn...").
lock surfaceBurnTime to SHIP:VELOCITY:SURFACE:MAG / acceleration.
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
}

// Execute final descent burn.
set WARP to 0.
printLine("Starting final descent burn...").
until ALT:RADAR < ENGINE_CUTOFF_ALTITUDE {
	printLine("  collision: " + round(collisionEta) + "s | burn time: " + round(surfaceBurnTime) + "s | speed: " + round(fallSpeed), true).
	lock THROTTLE to surfaceBurnTime / collisionEta.
}
lock THROTTLE to 0.
unlock THROTTLE.
printLine("  done").

// Finalize
printLine("Landed! (Hopefully!)").
unlock STEERING.
SAS on.


function calcShipHeightOffset() {
}

// Function to calculate gravitational acceleration
function CalculateGravity {
    parameter bodyMu, bodyRadius, shipAltitude.
    return bodyMu / (bodyRadius + shipAltitude) ^ 2.
}


//local TARGET_BURN_SECS = 3.
//// Calculate the required acceleration to achieve the required Delta V in the specified time
//local requiredAcceleration is SHIP:VELOCITY:ORBIT:MAG / TARGET_BURN_SECS.
//// Calculate the required thrust to achieve this acceleration
//local requiredThrust is requiredAcceleration * shipMass;
//// Calculate the thrust setting (0 to 1) based on max thrust
//local thrustSetting is requiredThrust / maxThrust;
//print "Required thrust of " + round(thrustSetting * 100) + "% to achieve necessary deltaV".
//if thrustSetting > 1 {thrustSetting is 1.}

//if orbitBurnTime > 2 {
//}



//until SHIP:STATUS = "LANDED" OR SHIP:STATUS = "SPLASHED" {
//	print "Waiting to burn...".
//	wait until calcMaxFallSpeed(ALT:RADAR) <= SHIP:VELOCITY:SURFACE:MAG * 1.15.
//	burn.
	//add node(TIME:SECONDS, 0, 0, -SHIP:VELOCITY:SURFACE:MAG).
	//run mnode.ks.
	
//}

//local maxFallSpeed is calcMaxFallSpeed(LANDING_HEIGHT).
//calcMaxFallSpeed(SHIP:ALTITUDE).

// Kill all momentum and fall downwards.
//add node(TIME:SECONDS, 0, 0, -SHIP:VELOCITY:ORBIT:MAG).
//run mnode.ks.

//calcEngineIgniteForLand().

//wait until SHIP:VELOCITY:SURFACE:MAG

//until SHIP:ALTITUDE <= LANDING_HEIGHT {
	//if (SHIP:VELOCITY:SURFACE:MAG > maxFallSpeed) {
		//executeBurn(SHIP:VELOCITY:SURFACE:MAG - maxFallSpeed).
	//}
	//if (SHIP:ALTITUDE >= LANDING_HEIGHT + maxFallSpeed * 10) {
		//wait 10
	//}
	//wait until SHIP:ALTITUDE <= LANDING_HEIGHT
//}

function calcMaxFallSpeed {
	// Parameters
	parameter height.
	local g is BODY:MU / (BODY:RADIUS + SHIP:ALTITUDE)^2. // gravitational acceleration
	local acceleration is SHIP:AVAILABLETHRUST / SHIP:MASS.

	// Calculate net acceleration
	local a is acceleration - g.

	if a < 0 {
		print "a=" + round(a) + ": CAnnot survive.".
		return -1.
	}
	// Calculate max survivable fall speed
	local maxFallSpeed is SQRT(2 * a * ALT:RADAR).

	//print "a=" + round(a) + ": max fall speed at " + round(height) + "m is " + ROUND(maxFallSpeed, 2) + "m/s".
	return maxFallSpeed.

}

function killLateralMovement {
    // Get the horizontal component of the velocity vector
    lock surfaceVelocity to SHIP:VELOCITY:SURFACE.
	lock yAxis to SHIP:UP:VECTOR.
	local verticalVelocity is VDOT(surfaceVelocity, yAxis) * yAxis.
    local horizontalVelocity is surfaceVelocity - verticalVelocity.

    // Check if there is significant horizontal velocity to correct
    if horizontalVelocity:mag > 0.1 { // Threshold to avoid jittering, adjust as necessary
        // Calculate the direction to thrust in (opposite of horizontal velocity)
        local thrustDirection is -horizontalVelocity:NORMALIZED.

        // Align the ship's orientation with the thrust direction
        lock STEERING to thrustDirection.
		
		wait 20.

        // Apply full throttle to counteract horizontal motion
        lock THROTTLE to 0.25.

        // Wait until horizontal velocity is nearly zero
		lock waitVel to surfaceVelocity - yAxis * VDOT(surfaceVelocity, yAxis).
        wait until waitVel:MAG < 0.1.

        // Reset throttle
        lock THROTTLE to 0.
    }
}

function calcEngineIgniteForLand {
	// Get necessary variables
	LOCAL g IS BODY:MU / (BODY:RADIUS + SHIP:ALTITUDE)^2. // gravitational acceleration
	LOCAL vvv IS SHIP:VELOCITY:SURFACE:Y. // current vertical speed (descent rate)
	LOCAL s IS SHIP:ALTITUDE. // current altitude
	LOCAL F IS SHIP:AVAILABLETHRUST. // available thrust
	LOCAL m IS SHIP:MASS. // mass of the ship

	// Calculate deceleration and time to start burn
	LOCAL a IS F / m - g. // max deceleration capability
	LOCAL t IS ABS(vvv) / a. // time to start deceleration
	LOCAL d IS ABS(vvv^2) / (2 * a). // distance to start deceleration

	// Print out the results
	PRINT "Deceleration required: " + ROUND(a, 2) + " m/s²".
	PRINT "Time to start deceleration: " + ROUND(t, 2) + " seconds".
	PRINT "Distance to start deceleration: " + ROUND(d, 2) + " meters".

	// Example condition to start burn
	IF s <= d {
		PRINT "Start burn now!".
	}
}

function burn {
	set WARP to 0.
	lock acceleration to SHIP:AVAILABLETHRUST / SHIP:MASS.
	lock burnTime to SHIP:VELOCITY:SURFACE:MAG / acceleration.
	print "Starting burn...".
	if (burnTime > 1) {
		lock THROTTLE to 1.0.
	} else {
		lock THROTTLE to 0.1.
	}
	if SHIP:DELTAV:CURRENT < SHIP:VELOCITY:SURFACE:MAG {
		print "Insufficient thrust in this stage, will have to stage mid-burn.".
		set stageBurnTime to SHIP:DELTAV:CURRENT / acceleration.
		wait until SHIP:DELTAV:CURRENT < 0.001.
		print "Staging.".
		stage.
		//set burnTime to burnTime - stageBurnTime.
	}
	//wait burnTime - 5.
	wait until SHIP:VELOCITY:SURFACE:MAG / acceleration < 1.5.
	if SHIP:VELOCITY:SURFACE:MAG > 3 {
		lock throttle to 0.2.
		wait until SHIP:VELOCITY:SURFACE:MAG > 3.
	}
	//wait until NEXTNODE:DELTAV:MAG < 0.1.
	lock THROTTLE to 0.

	unlock THROTTLE.
	print "Burn complete.".
}