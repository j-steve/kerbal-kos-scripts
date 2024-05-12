run common.ks.
//print getPhaseAngle().
//print calcPhaseAngle().
local txfrSemiMajorAxis is calcSemiMajorAxis(SHIP:ORBIT:APOAPSIS + BODY:RADIUS, MUN:ORBIT:APOAPSIS + BODY:RADIUS).
//local txfrOrbitPeriod is calcOrbitPeriod(txfrSemiMajorAxis).
//local txfrTime is txfrOrbitPeriod / 2. // Only outbound trip is relevent, so split total period in half.
//printLine(".").
//printLine(".").
//printLine(calcSemiMajorAxis(SHIP:ORBIT:APOAPSIS, SHIP:ORBIT:PERIAPSIS)).
//printLine(calcSemiMajorAxis(SHIP:ORBIT:APOAPSIS, SHIP:ORBIT:PERIAPSIS) + KERBIN:RADIUS).
//printLine(calcOrbitPeriod(ship:orbit:semiMajorAxis)).
//printLine(".").
//printLine("WAITTIME: " + (waitTime() / 60 / 60 / 24 /  365)).

local waitTimmee is newWaitTime( SHIP:ORBIT:PERIOD, MUN:ORBIT:PERIOD,txfrSemiMajorAxis, BODY:MU).
// set waitTimmee to waitTimmee - SHIP:ORBIT:PERIOD / 2. // There's a mistake somewhere that is flipping swhich side of the planet we need to burn at.
local fakeSemiMajor is calcSemiMajorAxis(4.53239* 10 ^9, 1.08209 * 10 ^ 8).
newWaitTime(60910.25 * 86400, 224.70 * 86400, fakeSemiMajor, 1.32712 * 10 ^ 11).
local currentRadius is ship:altitude + body:radius. // Assuming at current altitude
local txfrDeltaV is calcVisViva(currentRadius, ship:orbit:semimajoraxis, currentRadius, txfrSemiMajorAxis).
add node(TimeSpan(-waitTimmee), 0, 0, txfrDeltaV).

function calcOrbitPeriod {
	parameter semiMajorAxis.
	return 2 * CONSTANT:PI * SQRT(semiMajorAxis ^ 3 / BODY:MU).
}

function newWaitTime {
	parameter orbitPeriodOrigin, orbitPeriodDestination, semiMajorAxis, muu.
	local n_i is calcMeanMotion(orbitPeriodOrigin).
	local n_f is calcMeanMotion(orbitPeriodDestination).
	//local r_i is 4.53239E9.
	//local r_f is 1.08209E8.
	//local a_t is (r_i + r_f) / 2.  // km
	local t_12 is CONSTANT:PI / SQRT(muu) * semiMajorAxis ^ (3/2).
	local gamma_1 is calcPhaseAngle(n_f, t_12).
	local gamma_2 is calcPhaseAngle(n_i, t_12).
    local waitTimee is (-2 * gamma_2 + 2 * CONSTANT:PI * 1) / (n_f - n_i).
	printLine("Wait time: " + waitTimee + "s / " + (waitTimee / 60 / 60 / 24 / 365) + "y (gamma="  + round(gamma_2, 1) + ", n_f=" + round(n_f, 2) + ")").
	return waitTimee.
}

// Given an orbit period (number of seconds to complete 1 orbit), returns the mean motion
// (the angular speed required for a body to complete one orbit), assuming a perfectly circular orbit.
function calcMeanMotion {
	parameter orbitPeriod.
	return 2 * CONSTANT:PI / orbitPeriod.
}

function calcPhaseAngle {
	parameter meanMotion1, meanMotion2.
	return CONSTANT:PI - meanMotion1 * meanMotion2.
	return MOD(CONSTANT:PI - meanMotion1 * meanMotion2, 2 * CONSTANT:PI).
}

function calcVisViva {
    parameter rCurrent, aCurrent, rManeuver, aNew.
    local mu is body:mu.
    // Calculate current orbital speed
    local vCurrent is sqrt(body:mu * (2 / rCurrent - 1 / aCurrent)).

    // Calculate required orbital speed at the point of maneuver
    local vNew is sqrt(body:mu * (2 / rManeuver - 1 / aNew)).

    // Calculate delta-v
    local deltaV is abs(vNew - vCurrent).

    return deltaV.

}

function calcOrbitalSpeed {
	parameter radius, semiMajorAxis.
	return sqrt(BODY:MU * (2 / radius - 1 / semiMajorAxis)).
}