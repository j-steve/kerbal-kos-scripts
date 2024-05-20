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
	local angularDifference is MOD(SHIP:ORBIT:TRUEANOMALY - ascNodeTrueAnomaly + 360, 360).	
	if angularDifference < 180 {.
		printLine("Using the other one: " + ascNodeTrueAnomaly).
		set ascNodeTrueAnomaly to mod(180 + ascNodeTrueAnomaly, 360).
		set ascBurnMultiplier to -1.
	}
	local nodeEta is calcEtaToTrueAnomaly(SHIP:ORBIT, ascNodeTrueAnomaly ).
	if ascNodeTrueAnomaly < SHIP:ORBIT:TRUEANOMALY {
		set nodeEta to nodeEta + SHIP:ORBIT:PERIOD.
		printLine("Adding period").
	}
	
	// Add node
	local inclDeltaV is calcInclinationDeltaV(SHIP:ORBIT, targt:ORBIT:INCLINATION - SHIP:ORBIT:INCLINATION).
	//printLine("inclDeltaV: " + round(inclDeltaV,0)).
	if hasnode {
		until not hasnode {
			remove nextnode.
			wait 2.
		}
	}
	ADD NODE(TIME:SECONDS + nodeEta, 0, -inclDeltaV * ascBurnMultiplier,0).
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
	
	
	//vecdraw(elipseCenter,  ascNodeVector * 100000000, RGB(1, 0, 1), "asc 2", 0.3, true).
	
	//vecdraw(elipseCenter2,  ascNodeVector * 100000000, RGB(1, 0, 1), "asc 2b", 0.3, true).
	//vecdraw(V(SHIP:BODY:POSITION:X - fociToElipseCenterDist, SHIP:BODY:POSITION:Y, SHIP:BODY:POSITION:Z - fociToElipseCenterDist),  ascNodeVector * 100000000, RGB(1, 0.2, 1), "asc 3", 0.3, true).
	//vecdraw(V(SHIP:BODY:POSITION:X + fociToElipseCenterDist, SHIP:BODY:POSITION:Y, SHIP:BODY:POSITION:Z + fociToElipseCenterDist),  ascNodeVector * 100000000, RGB(1, 0.2, 1), "asc 3", 0.3, true).
	

	//drawPlane(obj:POSITION, targetPlane).
	
	
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

function getPointString {
	parameter pointVal.
	return "(" + round(pointVal:X, 2) + ","  + round(pointVal:Y, 2) + "," + round(pointVal:Z, 2) + ")".
}

function waitForIntersect {
	parameter ascNodeVector.
	local minMag is 99999999999999999999999999.
	local minPosition is SHIP:POSITION - SHIP:OBT:BODY:POSITION.
	local myNode is NODE(Time:SECONDS, 0, 0, 0).
	add myNode.
	until false {
		//printLine(getPointString(ascNodeVector - SHIP:POSITION - SHIP:OBT:BODY:POSITION), true).
		//local thisMag is (ascNodeVector - SHIP:POSITION - SHIP:OBT:BODY:POSITION):MAG.
		local thisMag is VectorAngle(ascNodeVector, SHIP:OBT:BODY:POSITION).
		printLine(thisMag, true).
		if thisMag < minMag {
			set minMag to thisMag.
			set minPosition to (SHIP:OBT:BODY:POSITION):NORMALIZED.
			remove myNode.
			set myNode to  NODE(TIME:SECONDS, 0, 0, 0).
			add myNode.
		}
		//printLine((ascNodeVector - SHIP:POSITION - SHIP:OBT:BODY:POSITION):MAG, true).
		wait 0.5.
	}
}

function findIntersectionPoints {
	parameter shipPosition, shipVelocity, normVector, targetPosition.
    // Define the plane equation: normVector . (r - targetPosition) = 0
    // Substitute the parameterized orbit equation: r(t) = shipPosition + t * shipVelocity
    // Solve normVector . (shipPosition + t * shipVelocity - targetPosition) = 0 for t

    local coeffT is VDOT(normVector, shipVelocity).
    local constantt is VDOT(normVector, shipPosition - targetPosition).

    if coeffT = 0 {
        return "No intersection or infinite intersections (parallel or coincident).".
    }

    local t is -constantt / coeffT.

    // Calculate the intersection point
    local intersectionPoint is shipPosition + t * shipVelocity.
    return intersectionPoint.
}


function calculateD {
    parameter normVec, pointOnPlane.
    return normVec:X * pointOnPlane:X + normVec:Y * pointOnPlane:Y + normVec:Z * pointOnPlane:Z.
}

function drawPlane {
	parameter centerPos, planeNormalVector.
	clearvecdraws().
	set planeNormalVector to planeNormalVector:NORMALIZED. // Convert vector to ship-based vector.
	
	local upVector is V(0, 0, 1). // Assuming this is a vector not aligned with the planeNormalVector
    if abs(vdot(planeNormalVector, upVector)) > 0.99 {
        set upVector to V(0, 1, 0).
    }
	// Create two vectors that are perpendicular to the planeNormalVector and to each other
    local v1 is VECTORCROSSPRODUCT(planeNormalVector, upVector):NORMALIZED.
    local v2 is VECTORCROSSPRODUCT(planeNormalVector, v1):NORMALIZED.


	printLine("Up vector is " + upVector).
	printLine("v1 is " + v1).
	printLine("v2 is " + v2).
	
	local DRAW_DIST is 1000000.
	local DRAW_COUNT is 20.
	
	vecdraw(centerPos, upVector * DRAW_DIST * DRAW_COUNT, RGB(.5, .5, .5), "up", 0.15, true).
	vecdraw(centerPos, planeNormalVector * DRAW_DIST * DRAW_COUNT, RGB(0, 1, 0), "normal", 0.25, true).
	vecdraw(centerPos, v1 * DRAW_DIST * DRAW_COUNT, RGB(1, 0, 0), "v1", 0.25, true).
	vecdraw(centerPos, v2 * DRAW_DIST * DRAW_COUNT, RGB(0, 0, 1), "v2", 0.25, true).
	return.
	
	
	local i is -DRAW_DIST.
	from {local i is -DRAW_DIST.} until i >= DRAW_DIST step {set i to i + DRAW_DIST / DRAW_COUNT.} DO {
		local pos is centerPos + planeNormalVector * i.
		vecdraw(pos, V(1,0,0) * DRAW_DIST * DRAW_COUNT, RGB(1, 0, 0), "", 0.1, true).
		vecdraw(pos, V(1,0,0) * DRAW_DIST * DRAW_COUNT, RGB(1, 1, 0), "", 0.1, true).
		
		//local pos is centerPos + (v1 * x * DRAW_DIST) + (v2 * y * DRAW_DIST).
		//printLine(pos).
        //vecdraw(pos, v1 * DRAW_DIST * DRAW_COUNT, RGB(1, 0, 0), "", 1, true).
		//vecdraw(pos, v2 * DRAW_DIST * DRAW_COUNT, RGB(0, 1, 0), "", 1, true).
    }

}

function calcAscendingNode {
	parameter orbit1, orbit2.
	// Find the 
	local ascNodeDeg is orbit1:LONGITUDEOFASCENDINGNODE - SHIP:ORBIT:LAN.
	return ascNodeDeg.
}

// Returns the normal vector of the plane defined by the given orbit (relative to ship position).
// This is, the vector pointing "directly up" from the plane, or technically, a vector "z" that is
// exactly perpendicular to all four plane vectors (x, y, -x, -y).
function calcOrbitalPlaneNormal2 {
    parameter myOrbit.
	local positionRelativeToShip is myOrbit:POSITION - myOrbit:BODY:POSITION.
	return VECTORCROSSPRODUCT(myOrbit:VELOCITY:ORBIT, positionRelativeToShip):NORMALIZED.

}

function calcAscendingNodeSimple {
	parameter orbit1, orbit2.
	local ascNodeDeg is orbit1:LONGITUDEOFASCENDINGNODE - SHIP:ORBIT:LAN.
	return ascNodeDeg.
}

function calcInclinationDeltaV2 {
	// Converts angles from degrees to radians
	local DEG_TO_RAD is CONSTANT():PI / 180.

	// See https://en.wikipedia.org/wiki/Orbital_inclination_change#Calculation
	parameter myOrbit, incChange.
	local meanMotion is calcMeanMotion(myOrbit).

	// Convert inclination change from degrees to radians for trigonometric functions
	local incChangeRad is incChange * DEG_TO_RAD.

	// Adjusting trigonometric calculations to use radians
	local numerator is  2 * SIN(incChangeRad / 2) * (1 + myOrbit:ECCENTRICITY * COS(myOrbit:TRUEANOMALY * DEG_TO_RAD)) * meanMotion * myOrbit:SEMIMAJORAXIS.
	local denominator is SQRT(1 - myOrbit:ECCENTRICITY ^ 2) * COS((myOrbit:ARGUMENTOFPERIAPSIS + myOrbit:TRUEANOMALY) * DEG_TO_RAD).

	return numerator / denominator.
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