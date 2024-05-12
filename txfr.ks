run common.ks.

run circ.ks. // Orbit must be circularized for subsequent calculations.

createHoffmanTxfrNode(MINMUS:OBT).

function createHoffmanTxfrNode {
	parameter targetOrbit.
	local txfrSemiMajorAxis is calcSemiMajorAxis(SHIP:ORBIT:APOAPSIS + BODY:RADIUS, targetOrbit:APOAPSIS + BODY:RADIUS).
	local waitTime is calcTimeToTxfr(targetOrbit, txfrSemiMajorAxis).
	local currentRadius is ship:altitude + body:radius. // Assuming at current altitude
	local txfrDeltaV is calcVisViva(currentRadius, ship:orbit:semimajoraxis, currentRadius, txfrSemiMajorAxis).
	add node(TimeSpan(waitTime), 0, 0, txfrDeltaV).
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
	
	local bestTimeToGo is -1.
	from {local i is -1.} until i >= 5 step {set i to i+1.} do {
		set numerator to (targetElapsedTravel+(targetPosition-CONSTANT:PI-shipPosition)/(2*CONSTANT:PI)+i).
		set denominator to ((targetOrbitPeriod-shipOrbitPeriod)/(targetOrbitPeriod*shipOrbitPeriod)).
		local timeToGo is numerator / denominator.
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

function calcOrbitPeriod {
	parameter semiMajorAxis.
	return 2 * CONSTANT:PI * SQRT(semiMajorAxis ^ 3 / BODY:MU).
}
