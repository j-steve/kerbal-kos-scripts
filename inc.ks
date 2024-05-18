RUNONCEPATH("common.ks").

clearscreen.
SAS off.
set TARGET to MINMUS.
matchTargetInc().

function matchTargetInc {
	printLine("Adjusting inclination to match " + TARGET:NAME + ".").
	printLine("").
	
	// TEST CODE
	lock currentRads to SHIP:ORBIT:TRUEANOMALY * CONSTANT:DEGTORAD.
	printLine("Current rads is " + round(currentRads, 3) + " (" + round(currentRads * CONSTANT:RADTODEG) + " deg)").
	local RAD_DIFF is .91. // How far ahead to increment for testing.
	local targetRads is currentRads + RAD_DIFF.
	printLine("Targeting rads: " + round(targetRads, 3) + " (" + round(targetRads * CONSTANT:RADTODEG) + " deg)").
	local myEta is calcEtaToRadian2(SHIP:ORBIT, targetRads).
	printLine("ETA is " + round(myEta, 2)).
	local startTime is TIME:SECONDS.
	printline("Wait until...").
	until currentRads >= targetRads {
		//printLine("CurrentRads: " + round(currentRads, 3), true).
		local eccRad is calcEccentricAnomaly(SHIP:ORBIT:ECCENTRICITY, SHIP:ORBIT:TRUEANOMALY).
		printLine("ETA: " + round(myEta - (TIME:SECONDS - startTime), 0) + " | rads: " + round(currentRads * CONSTANT:RADTODEG) + "| ecc="+ round(eccRad * CONSTANT:RADTODEG), true).
	}
	local actualTime is TIME:SECONDS - startTime.
	printLine("Elapsed time: " + round(actualTime,2) + " | deviation: " + round(abs(1 - (myEta / actualTime)) * 100, 3) + "%").
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
	// Mean motion can be expressed as 2pi / orbit period, or sqrt (mu / semiMajorAxis^3) -- both are equivelant.
	parameter myOrbit.
	return SQRT(myOrbit:BODY:MU / (myOrbit:semiMajorAxis ^ 3)).
	//return TWOPI / myOrbit:PERIOD.
}

function calcEtaToRadian2 {
	parameter myOrbit, targetTrueAnomalyRad.
	local currentTrueAnomalyRad is myOrbit:TRUEANOMALY * CONSTANT:DEGTORAD.
	local meanAnomalyCurrent is calcMeanAnomaly(myOrbit:ECCENTRICITY, currentTrueAnomalyRad).
	local meanAnomalyTarget is calcMeanAnomaly(myOrbit:ECCENTRICITY, targetTrueAnomalyRad).
	return (meanAnomalyTarget - meanAnomalyCurrent) / calcMeanMotion(myOrbit).
}

function calcMeanAnomaly {
	// https://en.wikipedia.org/wiki/Eccentric_anomaly#From_the_mean_anomaly
	parameter eccentricity, trueAnomalyRad.
	//local eccentricAnomaly is COS(-1 (-1 * (r/a-1) * (1/e))).
	local eccentricAnomaly is calcEccentricAnomaly(eccentricity, trueAnomalyRad).
	return eccentricAnomaly - eccentricity * SIN(eccentricAnomaly).
}

function calcEccentricAnomaly {
	// https://en.wikipedia.org/wiki/Eccentric_anomaly#From_the_true_anomaly
	// https://www.csun.edu/~hcmth017/master/node14.html
    parameter eccentricity, trueAnomaly.
    local tanHalfE is SQRT((1 + eccentricity) / (1 - eccentricity)) * TAN(trueAnomaly / 2).
    local result is 2 * ARCTAN(tanHalfE) * CONSTANT:DEGTORAD.
	if result < 0 {
		set result to result + TWOPI.
	}
	return result.
}

function calcEtaToRadian {
	parameter myOrbit, targetTrueAnomaly.

	// Get current orbital elements
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