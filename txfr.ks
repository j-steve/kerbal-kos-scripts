run common.ks.
//print getPhaseAngle().
//print calcPhaseAngle().
//local txfrOrbitPeriod is calcOrbitPeriod(txfrSemiMajorAxis).
//local txfrTime is txfrOrbitPeriod / 2. // Only outbound trip is relevent, so split total period in half.
//printLine(".").
//printLine(".").
//printLine(calcSemiMajorAxis(SHIP:ORBIT:APOAPSIS, SHIP:ORBIT:PERIAPSIS)).
//printLine(calcSemiMajorAxis(SHIP:ORBIT:APOAPSIS, SHIP:ORBIT:PERIAPSIS) + KERBIN:RADIUS).
//printLine(calcOrbitPeriod(ship:orbit:semiMajorAxis)).
//printLine(".").
//printLine("WAITTIME: " + (waitTime() / 60 / 60 / 24 /  365)).

//local waitTimmee is newWaitTime( SHIP:ORBIT:PERIOD, MUN:ORBIT:PERIOD,txfrSemiMajorAxis, BODY:MU).
// set waitTimmee to waitTimmee - SHIP:ORBIT:PERIOD / 2. // There's a mistake somewhere that is flipping swhich side of the planet we need to burn at.
//local fakeSemiMajor is calcSemiMajorAxis(4.53239* 10 ^9, 1.08209 * 10 ^ 8).
//newWaitTime(60910.25 * 86400, 224.70 * 86400, fakeSemiMajor, 1.32712 * 10 ^ 11).
createHoffmanTxfrNode(MINMUS:OBT).

function createHoffmanTxfrNode {
	parameter targetOrbit.
	local txfrSemiMajorAxis is calcSemiMajorAxis(SHIP:ORBIT:APOAPSIS + BODY:RADIUS, targetOrbit:APOAPSIS + BODY:RADIUS).
	local waitTime is calcTimeToTxfr(targetOrbit, txfrSemiMajorAxis).
	local currentRadius is ship:altitude + body:radius. // Assuming at current altitude
	local txfrDeltaV is calcVisViva(currentRadius, ship:orbit:semimajoraxis, currentRadius, txfrSemiMajorAxis).
	add node(TimeSpan(waitTime), 0, 0, txfrDeltaV).
}

function calcOrbitPeriod {
	parameter semiMajorAxis.
	return 2 * CONSTANT:PI * SQRT(semiMajorAxis ^ 3 / BODY:MU).
}

function newWaitTime {
	parameter orbitPeriodOrigin, targetOrbitPeriod, semiMajorAxis, muu.
	local n_i is calcMeanMotion(orbitPeriodOrigin).
	local n_f is calcMeanMotion(targetOrbitPeriod).
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

function calcTimeToTxfr {
	parameter targetOrbit, txfrSemiMajorAxis.
	local shipPosition is getAbsOrbitalPositionRads(SHIP:OBT).
	local targetPosition is getAbsOrbitalPositionRads(targetOrbit).
	local shipOrbitPeriod is SHIP:OBT:PERIOD.
	local targetOrbitPeriod is targetOrbit:PERIOD.
	// Orbit period in seconds of the eliptical tranfer orbit which
	// will be taken by the ship to reach the target.
	local txfrOrbitPeriod is calcOrbitPeriod(txfrSemiMajorAxis).
	
	// Radians that the target will travel around its orbit during the transfer period.
	// Reflects the distance between its position when the ship departs, 
	// and its position when the ship arrives at the target.
	local targetElapsedTravel is txfrOrbitPeriod / 2 / targetOrbitPeriod.
	
	printLine("txfrOrbitPeriod: " + txfrOrbitPeriod).
	printLine("shipOrbitPeriod: " + shipOrbitPeriod).
	printLine("targetOrbitPeriod: " + targetOrbitPeriod).
	printLine("shipPosition: " + shipPosition).
	printLine("targetPosition: " + targetPosition).
	printLine(".").
	
	local bestTimeToGo is -1.
	from {local i is -2.} until i >= 5 step {set i to i+1.} do {
		set numerator to (targetElapsedTravel+(targetPosition-CONSTANT:PI-shipPosition)/(2*CONSTANT:PI)+i).
		set denominator to ((targetOrbitPeriod-shipOrbitPeriod)/(targetOrbitPeriod*shipOrbitPeriod)).
		local timeToGo is numerator / denominator.
        printLine("#" + i + ": " + timeToGo).
		if timeToGo > 0 and (bestTimeToGo < 0 or timeToGo < bestTimeToGo) {
			set bestTimeToGo to timeToGo.
		}
    }
	return bestTimeToGo.
}

// Given an object's orbit, returns its current position in rads, in absolute terms.
// This can let you compare the position of two different orbits.
function getAbsOrbitalPositionRads {
    parameter orbit1.

    local degrees is orbit1:LONGITUDEOFASCENDINGNODE + orbit1:ARGUMENTOFPERIAPSIS + orbit1:TRUEANOMALY.
    return mod(degrees, 360) * CONSTANT:DEGTORAD. // Convert degrees to radians using the constant
}