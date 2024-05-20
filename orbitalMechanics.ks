

function calcMeanMotion {
	// Mean motion can be expressed as 2pi / orbit period, or sqrt (mu / semiMajorAxis^3) -- both are equivelant.
	parameter myOrbit.
	printLine("sma " + myOrbit:SEMIMAJORAXIS).
	//return SQRT(myOrbit:BODY:MU / (myOrbit:SEMIMAJORAXIS ^ 3)).
	return 2 * CONSTANT:PI / myOrbit:PERIOD.
}

// Returns the time in seconds it will take to travel from the current position 
// (the current true anomaly) in the given orbit to the given position (true anomaly, in degrees).
function calcEtaToTrueAnomaly {
	parameter myOrbit, targetDegrees.
	local meanAnomalyCurrent is calcMeanAnomaly(myOrbit:ECCENTRICITY, myOrbit:TRUEANOMALY).
	local meanAnomalyTarget is calcMeanAnomaly(myOrbit:ECCENTRICITY, targetDegrees).
	return (meanAnomalyTarget - meanAnomalyCurrent) / 360 * myOrbit:PERIOD.
}

function calcMeanAnomaly {
	// https://space.stackexchange.com/questions/54396/how-to-calculate-the-time-to-reach-a-given-true-anomaly
	parameter eccentricity, trueAnomaly.
	local eccentricAnomaly is calcEccentricAnomaly(eccentricity, trueAnomaly).
	local sinOfEccentricAnomaly is SIN(eccentricAnomaly) * CONSTANT:RADTODEG.
	return eccentricAnomaly - eccentricity * sinOfEccentricAnomaly.
}

function calcEccentricAnomaly {
	// https://space.stackexchange.com/questions/54396/how-to-calculate-the-time-to-reach-a-given-true-anomaly
	parameter eccentricity, trueAnomaly.
	local eccentricAnomaly is ARCCOS((eccentricity + COS(trueAnomaly)) / (1 + eccentricity * COS(trueAnomaly))).
	if (eccentricAnomaly < 180) and (trueAnomaly > 180) {
		// Computed eccentric anomaly is always between the peripsis and the apoapsis.  
		// Flip it to the other half of the orbit circle if we've passed the apoapsis, 
		// aka, if current true anomaly > 180°.
		set eccentricAnomaly to 360 - eccentricAnomaly.
	}
	return eccentricAnomaly.
}

// Calulates the midpoint of the orbit, equidistant between apoapsis and peripsis in space.
// For perfectly circular orbits this will be the center of the planet.
// Returns the coordinatees, relative to the current ship position.
function calcOrbitCenter {
	parameter myOrbit.
	local fociToElipseCenterDist is myOrbit:ECCENTRICITY * myOrbit:SEMIMAJORAXIS.
	// We know the offset, but now we must rotate the offset around the axis so that it is positioned correctly.
	// See https://stackoverflow.com/questions/73922517/how-can-i-find-the-x-y-from-a-rotated-degree
	local orbitRotationTheta is myOrbit:ARGUMENTOFPERIAPSIS * myOrbit:ECCENTRICITY.
	local newX is myOrbit:BODY:POSITION:X + (fociToElipseCenterDist * COS(orbitRotationTheta)) .
	local newZ is myOrbit:BODY:POSITION:Z + (fociToElipseCenterDist * SIN(orbitRotationTheta)).
	return V(newX, myOrbit:BODY:POSITION:Y, newZ).
}