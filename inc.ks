RUNONCEPATH("common.ks").

clearscreen.
SAS off.
matchTargetInc().

function matchTargetInc {
	local targt is SHIP.
	if not HASTARGET {
		printLine("targna").
		//set TARGET to MINMUS.
	} else {
		printLine("taryaa").
		set targt to TARGET.
	}
	printLine("Adjusting inclination to match " + targt:NAME + ".").
	printLine("").
	
	// Get the ascending node.
	local ascNodeTrueAnomaly is calcAscNodeTrueAnomaly(targt).
	printLine("Angle of asc node: " + round(ascNodeTrueAnomaly,0)).
	// Check angular difference to see if we've passed the ascending node within the last half rotation.
	// If so it'll be faster to hit the descending node instead.
	local ascBurnMultiplier is 1.
	if targt:ORBIT:INCLINATION < SHIP:ORBIT:INCLINATION {
		//set ascBurnMultiplier to ascBurnMultiplier * -1.
	}
	local angularDifference is MOD(SHIP:ORBIT:TRUEANOMALY - ascNodeTrueAnomaly + 360, 360).	
	if angularDifference < 180 {
		// TODO: re-enable.
		// TODO: in elliptical orbits, it will take less delta v to burn at the point closer to apoapsis, so use that one instead.
		//printLine("Using the other one: " + ascNodeTrueAnomaly).
		//set ascNodeTrueAnomaly to mod(180 + ascNodeTrueAnomaly, 360).
		//set ascBurnMultiplier to ascBurnMultiplier * -1.
	}
	local nodeEta is calcEtaToTrueAnomaly(SHIP:ORBIT, ascNodeTrueAnomaly ).
	if ascNodeTrueAnomaly < SHIP:ORBIT:TRUEANOMALY {
		set nodeEta to nodeEta + SHIP:ORBIT:PERIOD.
		printLine("Adding period").
	}
	
	local inclDeltaV is calcInclinationDeltaV2(SHIP:ORBIT, targt:ORBIT:INCLINATION - SHIP:ORBIT:INCLINATION, ascNodeTrueAnomaly).
	//local velocityAtNode IS VELOCITYAT(SHIP, TIME:SECONDS + nodeEta):ORBIT:MAG.
	//printLine("Velocity at node is " + velocityAtNode).
	//local inclDeltaV is calcInclinationDeltaV4(velocityAtNode, velocityAtNode, targt:ORBIT:INCLINATION - SHIP:ORBIT:INCLINATION).
	printLine("asc node true anom: " + ascNodeTrueAnomaly).
	printLine("inclDeltaV: " + round(inclDeltaV,0)).
	
	if hasnode {
		until not hasnode {
			remove nextnode.
			wait 0.25.
		}
	}
	ADD NODE(TIME:SECONDS + nodeEta, 0, inclDeltaV  * ascBurnMultiplier , 0).
	until false {
		printLine(round(SHIP:ORBIT:TRUEANOMALY), true).
	}
	//RUNPATH("mnode.ks", 0.5).
}

function calcAscNodeTrueAnomaly {
	parameter obj.
	// To get the ascending node vector, find the normal vectors of the ship plane & target plane,
	// then take the cross product of those two to find a new vector perpendicular to both.
	// That vector will neccessarily be the line along which the two objects overlap,
	// which is also the point at which me must burn to adjust our inclination to match.
	local targetPlane is calcOrbitalPlaneNormal2(obj:ORBIT).
	local shipPlane is calcOrbitalPlaneNormal2(SHIP:ORBIT).
	local ascNodeVector is VECTORCROSSPRODUCT(targetPlane, shipPlane).
	clearvecdraws().
	vecdraw(obj:POSITION,  targetPlane * 100000000, RGB(1, 0, 0), "target normal", 0.15, true).
	vecdraw(SHIP:POSITION,  shipPlane * 100000000, RGB(0, 0, 1), "ship normal", 0.15, true).
	vecdraw(SHIP:BODY:POSITION,  ascNodeVector * 100000000, RGB(1, 1, 0), "asc node", 0.4, true).
	printLine("Waiting for " + getPointString(ascNodeVector:NORMALIZED)).
	
	//vecdraw(calcOrbitCenter(SHIP:ORBIT),  ascNodeVector * SHIP:ORBIT:APOAPSIS + SHIP:ORBIT:BODY:RADIUS, RGB(1, 0, 1), "asc 3", 0.5, true).
	// From an overhead view, the vector line will intersect the orbit at the point of the ascending node.
	// To find the degree at which the intersection occurs, take the arctan of that vector line.
	// (We ignore the y coordinate given that this is an overhead view. It's not needed since the orbital plane is 2D.)
	local ascendingNodeAngle is ARCTAN2( ascNodeVector:Z, ascNodeVector:X).	
	
	// This angle is correct based on some x axis.  To convert this to a useable true anomaly, use the ship's current position
	// to determine the degree difference between reported trueanomaly, and degrees from 0 on the X axis.
	// This gives us a number to add to the calculated degree position to get the "actual" true anomaly position to use.
	local currentShipAngle is ARCTAN2(-SHIP:ORBIT:BODY:POSITION:Z, -SHIP:ORBIT:BODY:POSITION:X).
	local trueAnomalyOffset is SHIP:ORBIT:TRUEANOMALY - currentShipAngle.
	local descNode is ascendingNodeAngle + trueAnomalyOffset.
	
	// Technically this logic has found us the descending node (because of the way we used the acsending vector).
	// So add 180 to get the ascending node instead and return that on a 360-degree scale.
	return MOD(descNode + 180, 360).
}

function getPointString {
	parameter pointVal.
	return "(" + round(pointVal:X, 2) + ","  + round(pointVal:Y, 2) + "," + round(pointVal:Z, 2) + ")".
}

// Returns the normal vector of the plane defined by the given orbit (relative to ship position).
// This is, the vector pointing "directly up" from the plane, or technically, a vector "z" that is
// exactly perpendicular to all four plane vectors (x, y, -x, -y).
function calcOrbitalPlaneNormal2 {
    parameter myOrbit.
	local positionRelativeToShip is myOrbit:POSITION - myOrbit:BODY:POSITION.
	return VECTORCROSSPRODUCT(myOrbit:VELOCITY:ORBIT, positionRelativeToShip):NORMALIZED.

}

function calcInclinationDeltaV4 {
	parameter initialVelocity, targetVelocity, incChange.
	return SQRT(initialVelocity^2 + targetVelocity^2 - 2 * initialVelocity * targetVelocity * COS(incChange)).
}

function calcInclinationDeltaV3 {
	parameter orbitalVelocityAtNode, incChange.
	return 2 * orbitalVelocityAtNode * SIN(incChange / 2).
}

function calcInclinationDeltaV2 {
	// Converts angles from degrees to radians
	local DEG_TO_RAD is CONSTANT():PI / 180.

	// See https://en.wikipedia.org/wiki/Orbital_inclination_change#Calculation
	parameter myOrbit, incChange, incChangeTrueAnom.
	local meanMotion is calcMeanMotion(myOrbit).
	printLine("meanMotion : " + meanMotion).

	// Convert inclination change from degrees to radians for trigonometric functions
	local incChangeRad is incChange .

	// Adjusting trigonometric calculations to use radians
	local numerator is  2 * SIN(incChangeRad / 2) * (1 + myOrbit:ECCENTRICITY * COS(incChangeTrueAnom * DEG_TO_RAD)) * meanMotion * myOrbit:SEMIMAJORAXIS.
	local denominator is SQRT(1 - myOrbit:ECCENTRICITY ^ 2) * COS((myOrbit:ARGUMENTOFPERIAPSIS + incChangeTrueAnom) * DEG_TO_RAD).

	return numerator / denominator.
}

function calcInclinationDeltaV {
	// See https://en.wikipedia.org/wiki/Orbital_inclination_change#Calculation
	parameter myOrbit, incChange, ascNodeTrueAnom.
	local incChangeRad is incChange * CONSTANT:DEGTORAD.

	local meanMotion is calcMeanMotion(myOrbit).
	local numerator is  2 * SIN(incChangeRad/2) * (1 + myOrbit:ECCENTRICITY * COS(ascNodeTrueAnom)) * meanMotion * myOrbit:semiMajorAxis.
	local denominator is SQRT(1 - myOrbit:ECCENTRICITY ^ 2) * COS(myOrbit:ARGUMENTOFPERIAPSIS + ascNodeTrueAnom).
	return numerator / denominator.
}