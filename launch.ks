RUNONCEPATH("common.ks").

declare parameter launchHeading is 90, simpleLaunch is true.

clearscreen.
SAS off.

local TARGET_ORBIT_RADIUS is 90000.
local TARGET_APOAPSIS_ETA is 30.


if SHIP:STATUS = "PRELAUNCH" or SHIP:STATUS = "LANDED" {
	printLine("5", true).
	wait 1.
	printLine("4", true).
	wait 1.
	printLine("3", true).
	wait 1.
	printLine("2", true).
	wait 1.
	printLine("1", true).
	wait 1.
}

clearscreen.
SAS off.
printLine("Executing launch.").
printLine("").
local initialDeltaV is SHIP:DELTAV:VACUUM.

// Set trigger to deploy solar panels when hitting space.
if BODY:ATM:EXISTS {
	when ALTITUDE > BODY:ATM:HEIGHT then {
		deploySolarPanels().
	}
}

// Set trigger to stage.
when SHIP:AVAILABLETHRUST = 0 then {
	stage.
	wait until stage:ready.
	return true. // Preserve this trigger.
}

// Prep for takeoff.
lock STEERING to UP.
lock THROTTLE to 1.

// Takeoff (assuming we are on the ground).
if SHIP:STATUS = "PRELAUNCH" or SHIP:STATUS = "LANDED" {
	stage.
	wait until stage:ready.
}
wait until SHIP:VELOCITY:SURFACE:MAG > 100 and ALTITUDE > 100.


// Start slow turn to vector.
printLine("Pitching slightly towards " + launchHeading + "°...").
local INITIAL_LAUNCH_PITCH is 80.
lock STEERING to HEADING(launchHeading, INITIAL_LAUNCH_PITCH).
//wait until SHIP:VELOCITY:SURFACE:MAG > 500 and ALTITUDE > 2500.


if simpleLaunch {
	printLine("Waiting to 6.5k").
	wait until ALTITUDE > 6500 or APOAPSIS >= TARGET_ORBIT_RADIUS.
	printLine("Tilting to 75°").
	lock STEERING to HEADING(launchHeading, 75).
	printLine("Waiting til 12k").
	wait until ALTITUDE > 12000 or APOAPSIS >= TARGET_ORBIT_RADIUS.
	printLine("Tilting to 60°").
	lock STEERING to HEADING(launchHeading, 60).
	printLine("Waiting til 15k").
	wait until ALTITUDE > 15000 or APOAPSIS >= TARGET_ORBIT_RADIUS.
	printLine("Tilting to 45°").
	lock STEERING to HEADING(launchHeading, 45).
	printLine("Waiting til 45k").
	wait until ALTITUDE >= 45000 or APOAPSIS >= 70000.
	lock STEERING to HEADING(launchHeading, 5).
	wait until APOAPSIS >= TARGET_ORBIT_RADIUS.
}

// Set steering to keep apoapsis at the target time
printLine("Following prograde...").
until APOAPSIS >= TARGET_ORBIT_RADIUS {

	// Calculate the deviation of current ETA to apoapsis from the target ETA.
	local deviationFromTarget is 1 - (ETA:APOAPSIS / TARGET_APOAPSIS_ETA).

	// Calculate the new pitch based on this deviation.
	// If deviationFromTarget is 0 (ETA is perfectly on target), newPitch should be current prograde pitch.
	// If deviationFromTarget is positive (under target), increase pitch towards 90°.
	// If deviationFromTarget is negative (over target), decrease pitch towards 0°.
	local newPitch is SHIP:PROGRADE:PITCH + (90 * deviationFromTarget).
	printLine("  Pitching "+ round(newPitch) +  "° based on deviation: " + round(deviationFromTarget * 100) + "%.", true).
	
	// Calculate minimum pitch based on altitude
	// Linearly interpolate minimum pitch from 45° at 0m, to 0° at 60km.
	local minPitchForAlt is MAX(0, MIN(45, 45 * (1 - SHIP:ALTITUDE / 60000))).
	set newPitch to min(newPitch, minPitchForAlt).
	
	if deviationFromTarget < 0.10 and APOAPSIS > 55000 {
		// If we would pitch too far downward, instead throttle down a little.
		lock THROTTLE to 1 - deviationFromTarget.
	}

	// Lock steering to the new pitch and the given launch heading
	// Ensure newPitch remains within the bounds of 0 to 90 degrees
	LOCK STEERING TO HEADING(launchHeading, MAX(0, MIN(90, newPitch))).
}
lock THROTTLE to 0.

// Warp out of atmo.
lock STEERING to PROGRADE.
if BODY:ATM:EXISTS and ALTITUDE < BODY:ATM:HEIGHT {
	printline("Waiting to exit atmo..."). // Subsequent calcuations will be innacurate if we're still losing momentum due to atmo.
	set WARP to 2.
	wait until ALTITUDE > BODY:ATM:HEIGHT * .9.
	set WARP to 0.
}

// Correct apoapsis if it's fallen below min.
until APOAPSIS > TARGET_ORBIT_RADIUS + 500 {
	lock THROTTLE to 1.
}
lock THROTTLE to 0.

// Circularize.
printline("Creating circularization node.").
//local currentV is SHIP:ORBIT:VELOCITY:ORBIT:MAG. // Ideally this would be the projected velocity at apoapsis point instead.
local currentV is VELOCITYAT(SHIP, TIME:SECONDS + ETA:APOAPSIS).
local requiredV is calcRequiredVelocityAtApoapsis(TARGET_ORBIT_RADIUS).
local deltaV is (requiredV - currentV:ORBIT:MAG).

print "NEED DV:" + deltaV .

// create maneuver node at apoapsis with the calculated deltaV as the prograde component
add node(TIME:SECONDS + ETA:APOAPSIS, 0, 0, deltaV).
RUNPATH("mnode.ks", 10). // Run the maneuver node, set deviation to a high value (10) because this number is innacurate anyways.
SAS off.

// TODO: The prior burn is insufficnet, I think because we are using current V rather than apoapsis V for the required delta. So keep burning.
until PERIAPSIS >= BODY:ATM:HEIGHT + 500 {
	lock STEERING to PROGRADE.
	lock THROTTLE to 0.5.
}
lock THROTTLE to 0.

RUNPATH("circ.ks.").


// Exit.
printline("Orbit complete.").
local consumedDeltaV is round(initialDeltaV - SHIP:DELTAV:VACUUM).
local deltaVPerfection is consumedDeltaV / 3000 - 1. // 3000 = min to orbit of kerbin.
printline("  Consumed " + consumedDeltaV + " delta V (" + round(deltaVPerfection * 100) + "% excess).").
unlock THROTTLE.
unlock STEERING.
SAS on.

// function to calculate required velocity at apoapsis to achieve desired periapsis
function calcRequiredVelocityAtApoapsis {
    parameter desiredPeriapsis. // desired periapsis altitude in meters

    local apoapsisRadius is ship:apoapsis + BODY:RADIUS. // radius at apoapsis
    local periapsisRadius is desiredPeriapsis + BODY:RADIUS. // desired radius at periapsis

    // calculate semi-major axis of the new orbit
    local semiMajorAxis is calcSemiMajorAxis(apoapsisRadius, periapsisRadius).

    // use vis-viva equation to calculate the required velocity at apoapsis
    local visViva is sqrt(BODY:MU * (2 / apoapsisRadius - 1 / semiMajorAxis)).
    return visViva.
}

function deploySolarPanels {
    for part in SHIP:PARTS {
		for module in part:MODULES {
			if part:HASMODULE("ModuleProceduralFairing") {
				local fairingModule is part:GETMODULE("ModuleProceduralFairing").
				if fairingModule:HASEVENT("deploy") {
					fairingModule:DOEVENT("deploy").
				}
			}
			if part:GETMODULE(module):HASEVENT("extend solar panel") {
				part:GETMODULE(module):doevent("extend solar panel").
			}
			if part:GETMODULE(module):HASEVENT("extend antenna") {
				part:GETMODULE(module):doevent("extend antenna").
			}
			if part:GETMODULE(module):HASEVENT("extend solar panel") {
				part:GETMODULE(module):doevent("extend solar panel").
			}
		}
    }
}