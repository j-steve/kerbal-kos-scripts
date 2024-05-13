declare parameter launchHeading is 90.

RUNPATH("0:/common.ks").

local TARGET_ORBIT_RADIUS is 90000.

clearscreen.
SAS off.
printLine("Executing launch.").
printLine("").


//lock STEERING to UP.
//stage.
//wait until ALTITUDE >= 100.

printLine("Starting gravity turn...").
lock STEERING to HEADING(launchHeading, 90 - (ALTITUDE / 100)). // Simple gravity turn
until ALTITUDE >= 4000 {
	if SHIP:AVAILABLETHRUST = 0 {
		stage.
	}
	if APOAPSIS >= TARGET_ORBIT_RADIUS {
		lock THROTTLE to 0.
	} else {
		lock THROTTLE to 1.
	}
}
printLine("  done").

printLine("Burning to raise apoapsis...").
until APOAPSIS >= TARGET_ORBIT_RADIUS {
	lock STEERING to SRFPROGRADE.
	lock THROTTLE to 1.
	if SHIP:AVAILABLETHRUST = 0 {
		stage.
	}
}
lock THROTTLE to 0.
lock STEERING to HEADING(90, 0). // If we cant stop the thrust, at least channel it at the horizen instead of continuing to climb.
printline("  done").

if BODY:ATM:EXISTS {
	printline("Waiting to exit atmo..."). // Subsequent calcuations will be innacurate if we're still losing momentum due to atmo.
	set WARP to 2.
	wait until ALTITUDE >= BODY:ATM:HEIGHT * .9.
	set WARP to 0.
}

printline("Creating circularization node.").
local currentV is SHIP:ORBIT:VELOCITY:ORBIT:MAG. // Ideally this would be the projected velocity at apoapsis point instead.
local requiredV is calcRequiredVelocityAtApoapsis(TARGET_ORBIT_RADIUS).
local deltaV is (requiredV - currentV) * 1.2.  // Try to make up for currentV shortcoming.

print "NEED DV:" + deltaV .

// create maneuver node at apoapsis with the calculated deltaV as the prograde component
add node(TIME:SECONDS + ETA:APOAPSIS, 0, 0, deltaV).
run mnode.ks.
SAS off.

deploySolarPanels().

// TODO: The prior burn is insufficnet, I think because we are using current V rather than apoapsis V for the required delta. So keep burning.
until PERIAPSIS >= TARGET_ORBIT_RADIUS {
	lock STEERING to PROGRADE.
	lock THROTTLE to 1.
}
lock THROTTLE to 0.


// Exit.
printline("Orbit complete.").
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
			if part:GETMODULE(module):HASEVENT("extend solar panel") {
				part:GETMODULE(module):doevent("extend solar panel").
			}
			if part:GETMODULE(module):HASEVENT("extend antenna") {
				part:GETMODULE(module):doevent("extend antenna").
			}
		}
    }
}
