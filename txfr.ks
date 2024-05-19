RUNONCEPATH("common.ks").

parameter skipCirc is false.

executeTransfer().

function executeTransfer {
	if not HASTARGET {
		printLine("Please select transfer target first.").
		return.
	}
	printLine("Performing Hohmann transfer to " + TARGET:NAME + "...").
	if not skipCirc {
		run circ.ks. // Orbit must be circularized for subsequent calculations.
	}
	createHoffmanTxfrNode(SHIP:OBT, TARGET:OBT).
	run mnode.ks.
}

function createHoffmanTxfrNode {
	parameter startingOrbit, targetOrbit.
	local progradeModifier is 1.
	if targetOrbit:APOAPSIS < startingOrbit:APOAPSIS {
		set progradeModifier to -1.
	}
	local txfrSemiMajorAxis is calcSemiMajorAxis(startingOrbit:APOAPSIS + startingOrbit:BODY:RADIUS, targetOrbit:APOAPSIS + targetOrbit:BODY:RADIUS).
	local waitTime is calcTimeToTxfr(startingOrbit, targetOrbit, txfrSemiMajorAxis).
	local currentRadius is startingOrbit:APOAPSIS + targetOrbit:BODY:RADIUS. // Assuming a circular orbit, apoapsis = periapsis = current altitude.
	local txfrDeltaV is calcVisViva(currentRadius, startingOrbit:semimajoraxis, currentRadius, txfrSemiMajorAxis).
	add node(TimeSpan(waitTime), 0, 0, txfrDeltaV * progradeModifier).
}

function calcTimeToTxfr {
	parameter startingOrbit, targetOrbit, txfrSemiMajorAxis.
	local shipPosition is getAbsOrbitalPositionRads(startingOrbit).
	local targetPosition is getAbsOrbitalPositionRads(targetOrbit).
	local shipOrbitPeriod is startingOrbit:PERIOD.
	local targetOrbitPeriod is targetOrbit:PERIOD.
	if targetOrbit:NAME = "EVE" { // TODO: find a better way to detect "reverse orbits".
		set targetOrbitPeriod to targetOrbitPeriod * -1.
	}
	// Orbit period in seconds of the eliptical tranfer orbit which
	// will be taken by the ship to reach the target.
	local txfrOrbitPeriod is calcOrbitPeriod(txfrSemiMajorAxis).
	
	// Radians that the target will travel around its orbit during the transfer period.
	// Reflects the distance between its position when the ship departs, 
	// and its position when the ship arrives at the target.
	local targetElapsedTravel is txfrOrbitPeriod / 2 / targetOrbitPeriod.
	
	local bestTimeToGo is -1.
	from {local i is -10.} until i >= 10 step {set i to i+1.} do {
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
