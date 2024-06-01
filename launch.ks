RUNONCEPATH("common.ks").

declare parameter launchHeading is 90.

local startupData is startup("Executing launch.").

local TARGET_ORBIT_RADIUS is 100000.
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

// Adjust heading as we climb.
if ALTITUDE < 6500 {
	printLine("Tilting 80° towards" + launchHeading + "°, waiting to 6.5k...").
	until ALTITUDE > 6500 or APOAPSIS >= TARGET_ORBIT_RADIUS {maintainHeading(80).}
}

printLine("Tilting to 75°, waiting til 10k").
until ALTITUDE > 10000 or APOAPSIS >= TARGET_ORBIT_RADIUS {maintainHeading(75).}

printLine("Tilting to 70°, waiting til 12.5k").
until ALTITUDE > 12500 or APOAPSIS >= TARGET_ORBIT_RADIUS {maintainHeading(70).}

printLine("Tilting to 65°, waiting til 15k").
until ALTITUDE > 15000 or APOAPSIS >= TARGET_ORBIT_RADIUS {maintainHeading(65).}

printLine("Tilting to 60°, waiting til 20k").
until ALTITUDE > 20000 or APOAPSIS >= TARGET_ORBIT_RADIUS {maintainHeading(60).}

printLine("Tilting to 55°, waiting til 25k").
until ALTITUDE > 25000 or APOAPSIS >= TARGET_ORBIT_RADIUS {maintainHeading(55).}

printLine("Tilting to 45°, waiting til 30k").
until ALTITUDE > 30000 or APOAPSIS >= TARGET_ORBIT_RADIUS {maintainHeading(45).}

printLine("Tilting to 25°, waiting til 45k").
until ALTITUDE >= 45000 or APOAPSIS >= 70000 {maintainHeading(25).}

printLine("Tilting to 5°, waiting til APOAPSIS = " + TARGET_ORBIT_RADIUS).
until APOAPSIS >= TARGET_ORBIT_RADIUS {maintainHeading(5).}

// Warp out of atmo.
if ALTITUDE < BODY:ATM:HEIGHT {
	printLine("Waiting to exit atmo..."). // Subsequent calcuations will be innacurate if we're still losing momentum due to atmo.
	lock THROTTLE to 0.
	set targetHeading to PROGRADE.
	set WARP to 2.
	wait until ALTITUDE > BODY:ATM:HEIGHT * .9.
	set WARP to 0.
	wait until ALTITUDE > BODY:ATM:HEIGHT.
}

printLine("Out of atmo, fixing apoapsis if needed.").
// Correct apoapsis if it's fallen below min.
until APOAPSIS > TARGET_ORBIT_RADIUS + 500 {.
	maintainHeading(PROGRADE:VECTOR).
}

// In a standard launch, we''ll create a node to burn at apoapsis.
// If it's not going well and we've already passed the apoapsis, then skip and just burn.
if ETA:apoapsis < ETA:periapsis {
	// Create maneuver node at apoapsis with the calculated deltaV as the prograde component
	// Compute dV to complete orbit..
	lock THROTTLE to 0.
	set RCS to false.
	printLine("Creating periapsis adjustment node and waiting for node start...").
	local currentV is VELOCITYAT(SHIP, TIME:SECONDS + ETA:APOAPSIS).
	local requiredV is calcRequiredVelocityAtApoapsis(TARGET_ORBIT_RADIUS).
	local deltaV is (requiredV - currentV:ORBIT:MAG).
	add node(TIME:SECONDS + ETA:APOAPSIS, 0, 0, deltaV).
	lock steering to NEXTNODE:BURNVECTOR.
	local acceleration is MAX(SHIP:AVAILABLETHRUST / SHIP:MASS, 0.001).
	local burnTime is NEXTNODE:DELTAV:MAG / acceleration.
	local periapsisRaiseBurnStart is TIME:SECONDS + NEXTNODE:ETA - burnTime / 2 - 10. // 10 seconds buffer time
	wait 0.5. // Wait so it registers throttle as being 0, otherwise it'll block the warp.
	WARPTO(periapsisRaiseBurnStart).
	wait until TIME:SECONDS >= periapsisRaiseBurnStart.
	set WARP to 0.
}

printLine("Rasing periapsis...").
// TODO: slow thrust at end, when burnTime is approaching 0, to prevent adding too much deltaV (raising pariapsis more than needed).
until PERIAPSIS > 90000 {maintainHeading(PROGRADE:VECTOR).}
lock THROTTLE to 0.
set RCS to false.
if HASNODE {remove NEXTNODE.}

// Circularize as needed.
// RUNPATH("circ.ks.").

// Exit.
printline("Orbit complete.").
local consumedDeltaV is round(initialDeltaV - SHIP:DELTAV:VACUUM).
local deltaVPerfection is consumedDeltaV / 3000 - 1. // 3000 = min to orbit of kerbin.
printline("  Consumed " + consumedDeltaV + " delta V (" + round(deltaVPerfection * 100) + "% excess).").
startupData:END().

// Keeps the ship pointed at the given vector or pitch; stages and toggles RCS as when necessary.
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
	set RCS to facingError > 10.
	wait 0.01.
}

// Returns the required deltaV at apoapsis to achieve the desired periapsis.
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

// Activates all deployables that should be initated when we hit space: solar panels, fairings, antennas.
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
		}
    }
	PANELS on.
}