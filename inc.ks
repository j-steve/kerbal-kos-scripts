RUNONCEPATH("common.ks").

clearscreen.
SAS off.
matchTargetInc().

function matchTargetInc {
	if not HASTARGET {
		set TARGET to MINMUS.
	}
	printLine("Adjusting inclination to match " + TARGET:NAME + ".").
	printLine("").
	local ascNode is calcAscendingNode(SHIP:ORBIT, TARGET:ORBIT).
	local inclDeltaV is calcInclinationDeltaV(SHIP:ORBIT, TARGET:ORBIT:ECCENTRICITY - SHIP:ORBIT:ECCENTRICITY).
	local nodeEta is calcEtaToTrueAnomaly(SHIP:ORBIT, ascNode + SHIP:ORBIT:LAN).
	add NODE(TIME:SECONDS + nodeEta, inclDeltaV, 0, 0).
}

function calcAscendingNode {
	parameter orbit1, orbit2.
	local ascNodeDeg is orbit1:LONGITUDEOFASCENDINGNODE - orbit2:LONGITUDEOFASCENDINGNODE.
	printLine("Orbit1  : " + orbit1:LAN).
	printLine("Orbit2  : " + orbit2:LAN).
	printLine("asc node: " + ascNodeDeg).
	return ascNodeDeg.
}

function calcInclinationDeltaV {
	// See https://en.wikipedia.org/wiki/Orbital_inclination_change#Calculation
	parameter myOrbit, incChange.
	local meanMotion is calcMeanMotion(myOrbit).
	local numerator is  2 * SIN(incChange/2) * (1 + myOrbit:ECCENTRICITY * COS(myOrbit:TRUEANOMALY)) * meanMotion * myOrbit:semiMajorAxis.
	local denominator is SQRT(1 - myOrbit:ECCENTRICITY ^ 2) * COS(myOrbit:ARGUMENTOFPERIAPSIS + myOrbit:TRUEANOMALY).
	return numerator / denominator.
}

function calcMeanMotion {
	// Mean motion can be expressed as 2pi / orbit period, or sqrt (mu / semiMajorAxis^3) -- both are equivelant.
	parameter myOrbit.
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