RUNONCEPATH("common.ks").

clearscreen.
SAS off.
matchTargetInc().

function matchTargetInc {
	printLine("Adjusting inclination to match " + TARGET:NAME + ".").
	printLine("").
	
	// TEST CODE
	lock currentRads to SHIP:ORBIT:TRUEANOMALY * CONSTANT:DEGTORAD.
	printLine("Current rads is " + currentRads).
	local targetRads is currentRads + 0.01.
	printLine("Targeting rads: " + targetRads).
	printLine("ETA is " + calcEtaToRadian(SHIP:ORBIT, targetRads)).
	local startTime is TIME:SECONDS.
	printline("Wait until...").
	until currentRads >= targetRads {
		printLine("CurrentRads: " + currentRads, true).
	}
	printLine("Elapsed time: " + (TIME:SECONDS - startTime)).
	printLine("Current rads is " + currentRads).
	return.
	// END TEST CODE
	
	printLine(calcAscendingNode(SHIP:ORBIT, TARGET:ORBIT)).
	printLine(calcInclinationDeltaV(SHIP:ORBIT, 32)).
}

function calcAscendingNodeRad {
	parameter orbit1, orbit2.
	local ascNodeDeg is orbit1:LONGITUDEOFASCENDINGNODE - orbit2:LONGITUDEOFASCENDINGNODE.
	return ascNodeDeg * CONSTANT:DEGTORAD.
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
	parameter myOrbit.
	return SQRT(myOrbit:BODY:MU / (myOrbit:semiMajorAxis ^ 3)).
}

function calcEtaToRadian {
	parameter myOrbit, targetTrueAnomaly.

	// Get current orbital elements
	local TWOPI is 2 * CONSTANT:PI.
	local currentTrueAnomaly is myOrbit:TRUEANOMALY * CONSTANT:DEGTORAD.
	local meanMotion is calcMeanMotion(myOrbit).

	// Calculate current and target mean anomaly
	LOCAL currentMeanAnomaly TO myOrbit:MEANANOMALYATEPOCH + meanMotion * (TIME:SECONDS - myOrbit:EPOCH).
	LOCAL targetMeanAnomaly TO currentMeanAnomaly + (targetTrueAnomaly - currentTrueAnomaly).

	// Normalize the mean anomalies to the range [0, 2*PI]
	IF targetMeanAnomaly > TWOPI {
		SET targetMeanAnomaly TO targetMeanAnomaly - TWOPI.
	} ELSE IF targetMeanAnomaly < 0 {
		SET targetMeanAnomaly TO targetMeanAnomaly + TWOPI.
	}

	// Calculate time to reach target true anomaly
	LOCAL timeToTarget TO (targetMeanAnomaly - currentMeanAnomaly) / meanMotion.
	IF timeToTarget < 0 {
		SET timeToTarget TO timeToTarget + myOrbit:PERIOD.
	}

	PRINT "Time to reach target true anomaly: " + ROUND(timeToTarget) + " seconds".
	return timeToTarget.
}