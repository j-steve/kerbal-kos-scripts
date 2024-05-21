RUNONCEPATH("common.ks").

declare parameter launchHeading is 90.

local startupData is startup("Executing launch.").

local TARGET_ORBIT_RADIUS is 90000.
local TARGET_APOAPSIS_ETA is 30.
local initialDeltaV is SHIP:DELTAV:VACUUM.
local targetHeading is UP.
lock STEERING to targetHeading.

// TRIGGERS

// Set trigger to deploy solar panels when hitting space.
when ALTITUDE > BODY:ATM:HEIGHT then {
	deploySolarPanels().
}

// LAUNCH SEQUENCE

// Countdown.
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
	printLine("LIFTOFF", true).
}

// Takeoff (assuming we are on the ground).
if SHIP:STATUS = "PRELAUNCH" or SHIP:STATUS = "LANDED" {
	lock THROTTLE to 1.
	stage.
	until SHIP:VELOCITY:SURFACE:MAG > 75 and ALTITUDE > 100 {maintainHeading(90).}
}

// Start slow turn to vector.
printLine("Pitching slightly towards " + launchHeading + "°...").

// Adjust heading as we climb.
printLine("Waiting to 6.5k").
until ALTITUDE > 6500 or APOAPSIS >= TARGET_ORBIT_RADIUS {maintainHeading(80).}
printLine("Tilting to 75°").

printLine("Waiting til 10k").
until ALTITUDE > 10000 or APOAPSIS >= TARGET_ORBIT_RADIUS {maintainHeading(75).}
printLine("Tilting to 70°").

printLine("Waiting til 12k").
until ALTITUDE > 12000 or APOAPSIS >= TARGET_ORBIT_RADIUS {maintainHeading(70).}
printLine("Tilting to 60°").

printLine("Waiting til 15k").
until ALTITUDE > 15000 or APOAPSIS >= TARGET_ORBIT_RADIUS {maintainHeading(60).}
printLine("Tilting to 45°").

printLine("Waiting til 30k").
until ALTITUDE > 30000 or APOAPSIS >= TARGET_ORBIT_RADIUS {maintainHeading(45).}
printLine("Tilting to 25°").

printLine("Waiting til 45k").
until ALTITUDE >= 45000 or APOAPSIS >= 70000 {maintainHeading(25).}

printLine("Waiting til APOAPSIS = " + TARGET_ORBIT_RADIUS).
until APOAPSIS >= TARGET_ORBIT_RADIUS {maintainHeading(5).}
lock THROTTLE to 0.

// Warp out of atmo.
set targetHeading to PROGRADE.
printline("Waiting to exit atmo..."). // Subsequent calcuations will be innacurate if we're still losing momentum due to atmo.
set WARP to 2.
wait until ALTITUDE > BODY:ATM:HEIGHT * .9.
set WARP to 0.

// Correct apoapsis if it's fallen below min.
until APOAPSIS > TARGET_ORBIT_RADIUS + 500 {.
	maintainHeading(APOAPSIS:VECTOR).
}
lock THROTTLE to 0.
set RCS to false.

// Compute dV to complete orbit..
printline("Creating circularization node.").
local currentV is VELOCITYAT(SHIP, TIME:SECONDS + ETA:APOAPSIS).
local requiredV is calcRequiredVelocityAtApoapsis(TARGET_ORBIT_RADIUS).
local deltaV is (requiredV - currentV:ORBIT:MAG).
print "NEED DV:" + deltaV .

// Create maneuver node at apoapsis with the calculated deltaV as the prograde component
add node(TIME:SECONDS + ETA:APOAPSIS, 0, 0, deltaV).
until NEXTNODE:DELTAV:MAG < 1 {maintainHeading(NEXTNODE:BURNVECTOR).}
RUNPATH("circ.ks.").

// Exit.
printline("Orbit complete.").
local consumedDeltaV is round(initialDeltaV - SHIP:DELTAV:VACUUM).
local deltaVPerfection is consumedDeltaV / 3000 - 1. // 3000 = min to orbit of kerbin.
printline("  Consumed " + consumedDeltaV + " delta V (" + round(deltaVPerfection * 100) + "% excess).").
startupData:END().

// 
function maintainHeading {
	parameter targetVector. // Either a vector, or a target pitch (scalar).
	if SHIP:AVAILABLETHRUST = 0 {
		lock THROTTLE to 1.
		stage.
		wait 5.
		wait until stage:ready.
	}
	if targetVector:ISTYPE("scalar") {
		set targetVector to HEADING(launchHeading, targetVector):VECTOR.
	}
	lock STEERING to targetVector.
	local facingError is VANG(SHIP:FACING:FOREVECTOR, targetVector).
	lock THROTTLE to MAX(1 - facingError / 360, 0.25). // Always fire thrusters at at least 33%, as they may be needed to correct heading.
	set RCS to facingError > 5.
	wait 0.01.
}

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