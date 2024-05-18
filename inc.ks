RUNONCEPATH("common.ks").

clearscreen.
SAS off.
set TARGET to MINMUS.
matchTargetInc().

function matchTargetInc {
	printLine("Adjusting inclination to match " + TARGET:NAME + ".").
	printLine("").
	
	// TEST CODE
	local testRes is calcEccentricAnomaly(0.18 	, 45 ).
	printLine("test ecc:" + testRes + " aka " + testRes * CONSTANT:DEGTORAD).
	set testRes to calcMeanAnomaly(0.18 	, 45).
	printLine("test mean:" + testRes + " aka " + testRes * CONSTANT:DEGTORAD).

	
	lock currentDegree to SHIP:ORBIT:TRUEANOMALY.
	printLine("Current position is " + round(currentDegree) + "° | mean: " + round(calcMeanAnomaly(SHIP:ORBIT:ECCENTRICITY, currentDegree)) + "°").
	local DEGREE_DIFF is 14. // How far ahead to increment for testing.
	local targetDegree is currentDegree + DEGREE_DIFF.
	printLine("Targeting position: " + round(targetDegree) + "° | mean: " + round(calcMeanAnomaly(SHIP:ORBIT:ECCENTRICITY, targetDegree)) + "°").
	local myEta is calcEtaToDegree(SHIP:ORBIT, targetDegree).
	printLine("ETA is " + round(myEta, 2)).
	local startTime is TIME:SECONDS.
	printline("Wait until...").
	until currentDegree >= targetDegree {
		//printLine("CurrentRads: " + round(currentDegree, 3), true).
		local eccDegree is calcEccentricAnomaly(SHIP:ORBIT:ECCENTRICITY, SHIP:ORBIT:TRUEANOMALY).
		local meanDegree is calcMeanAnomaly(SHIP:ORBIT:ECCENTRICITY, SHIP:ORBIT:TRUEANOMALY).
		local statusLine is "ETA: " + round(myEta - (TIME:SECONDS - startTime), 0).
		local startTime2 is TIME:SECONDS.
		wait until calcMeanAnomaly(SHIP:ORBIT:ECCENTRICITY, SHIP:ORBIT:TRUEANOMALY) >= meanDegree + 0.01.
		local endTime2 is TIME:SECONDS - startTime2.
		set statusLine to statusLine + " | true: " + round(SHIP:ORBIT:TRUEANOMALY, 0) + "°".
		set statusLine to statusLine + " | ecc: " + round(eccDegree, 0) + "°".
		set statusLine to statusLine + " | mean: " + round(meanDegree, 2) + "°".
		set statusLine to statusLine + " | elaps: " + round(endTime2, 2) + "s".
		printLine(statusLine, true).
	}
	local actualTime is TIME:SECONDS - startTime.
	printLine("Elapsed time: " + round(actualTime,2) + " | deviation: " + round(abs(1 - (myEta / actualTime)) * 100, 3) + "%").
	printLine("Current position is " + currentDegree + "°").
	return.
	// END TEST CODE
	
	printLine(calcAscendingNode(SHIP:ORBIT, TARGET:ORBIT)).
	printLine(calcInclinationDeltaV(SHIP:ORBIT, 32)).
}

function calcAscendingNodeDegree {
	parameter orbit1, orbit2.
	local ascNodeDeg is orbit1:LONGITUDEOFASCENDINGNODE - orbit2:LONGITUDEOFASCENDINGNODE.
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
	return SQRT(myOrbit:BODY:MU / (myOrbit:semiMajorAxis ^ 3)).
	//return TWOPI / myOrbit:PERIOD.
}

function calcEtaToDegree {
	parameter myOrbit, targetDegrees.
	local meanAnomalyCurrent is calcMeanAnomaly(myOrbit:ECCENTRICITY, myOrbit:TRUEANOMALY).
	local meanAnomalyTarget is calcMeanAnomaly(myOrbit:ECCENTRICITY, targetDegrees).
	//return (meanAnomalyTarget - meanAnomalyCurrent) / calcMeanMotion(myOrbit).
	return (meanAnomalyTarget - meanAnomalyCurrent) / 360 * myOrbit:PERIOD.
}

function calcEtaToRadian2 {
	parameter myOrbit, targetTrueAnomalyRad.
	local currentTrueAnomalyRad is myOrbit:TRUEANOMALY * CONSTANT:DEGTORAD.
	local meanAnomalyCurrent is calcMeanAnomaly(myOrbit:ECCENTRICITY, currentTrueAnomalyRad).
	local meanAnomalyTarget is calcMeanAnomaly(myOrbit:ECCENTRICITY, targetTrueAnomalyRad).
	return (meanAnomalyTarget - meanAnomalyCurrent) / calcMeanMotion(myOrbit).
}

function calcMeanAnomaly {
	// https://space.stackexchange.com/questions/54396/how-to-calculate-the-time-to-reach-a-given-true-anomaly
	parameter eccentricity, trueAnomaly.
	//local eccentricAnomaly is COS(-1 (-1 * (r/a-1) * (1/e))).
	local eccentricAnomaly is calcEccentricAnomaly(eccentricity, trueAnomaly).
	//printLine("eccentricity is " + eccentricity).
	//printLine("eccentricAnomaly is " + eccentricAnomaly).
	local sinecc is SIN(eccentricAnomaly) * CONSTANT:RADTODEG.
	//printLine("Sin is " + sinecc).
	local ectimessin is eccentricity * sinecc.
	//printLine("Sin time ecc is is " + ectimessin).
	return eccentricAnomaly - ectimessin.
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

function calcMeanAnomaly22 {
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