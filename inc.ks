RUNONCEPATH("common.ks").

parameter debugMode is false.

matchTargetInc().

function matchTargetInc {
	if not HASTARGET {
		printLine("Targeting MINMUS by default").
		set TARGET to MINMUS.
	}
	local startupData is startup("Adjusting inclination to match " + TARGET:NAME + ".").
	
	// Get the ascending node.
	local ascNodeTrueAnomaly is calcAscNodeTrueAnomaly(TARGET).
	printLine("Angle of asc node: " + round(ascNodeTrueAnomaly,0)).
	// Check angular difference to see if we've passed the ascending node within the last half rotation.
	// If so it'll be faster to hit the descending node instead.
	local ascBurnMultiplier is -1.
	local angularDifference is MOD(SHIP:ORBIT:TRUEANOMALY - ascNodeTrueAnomaly + 360, 360).	
	if angularDifference < 180 {
		// TODO: re-enable.
		// TODO: in elliptical orbits, it will take less delta v to burn at the point closer to apoapsis, so use that one instead.
		// printLine("Using the other one: " + ascNodeTrueAnomaly).
		// set ascNodeTrueAnomaly to mod(180 + ascNodeTrueAnomaly, 360).
		// set ascBurnMultiplier to ascBurnMultiplier * -1.
	}
	local nodeEta is calcEtaToTrueAnomaly(SHIP:ORBIT, ascNodeTrueAnomaly ).
	if ascNodeTrueAnomaly < SHIP:ORBIT:TRUEANOMALY {
		set nodeEta to nodeEta + SHIP:ORBIT:PERIOD.
		printLine("Adding period").
	}
	
	// Create and execute maneuver node.
	createIncTransferNode(nodeEta, TARGET:ORBIT:INCLINATION).
	RUNPATH("mnode.ks").
	
	startupData:END().
}

function createIncTransferNode {
	parameter nodeEta, targetInclination.
	clearNodes().
	local incNode is NODE(TIME:SECONDS + nodeEta, 0, 0, 0).
	add incNode.
	local targetPlane is calcOrbitalPlaneNormal(TARGET:ORBIT).
	// Start with a high dV increment.  When we "overshoot" the target plane, 
	// go back and check again in the other direction (make it negative)
	// but with a more granular value (divide it by 10).
	// Stop when we reach a reasonably small dV increment.
	tuneNode(incNode, {return ABS((targetPlane - calcOrbitalPlaneNormal(incNode:ORBIT)):MAG).}).
}

function tuneNode {
	parameter tnode, evaluationFunc, minDeltaVIncrement is 0.00001.
	local dv is 10.
	local thrustVector is LIST(1, 1, 1).
	local i is 0.
	local priorDiff is evaluationFunc:CALL().
	until ABS(dv) < minDeltaVIncrement {
		set tnode:NORMAL to tnode:NORMAL + dv.
		local newDiff is evaluationFunc:CALL().
		if newDiff > priorDiff {
			set dv to -dv / 10.
		} 
		set priorDiff to newDiff.
	}
}

function clearNodes {
	if hasnode {
		until not hasnode {
			remove nextnode.
			wait 0.25.
		}
	}
}

function calcAscNodeTrueAnomaly {
	parameter obj.
	// To get the ascending node vector, find the normal vectors of the ship plane & target plane,
	// then take the cross product of those two to find a new vector perpendicular to both.
	// That vector will neccessarily be the line along which the two objects overlap,
	// which is also the point at which me must burn to adjust our inclination to match.
	local targetPlane is calcOrbitalPlaneNormal(obj:ORBIT).
	local shipPlane is calcOrbitalPlaneNormal(SHIP:ORBIT).
	local ascNodeVector is VECTORCROSSPRODUCT(targetPlane, shipPlane).
	if debugMode {
		clearvecdraws().
		vecdraw(obj:POSITION,  targetPlane * 100000000, RGB(1, 0, 0), "target normal", 0.15, true).
		vecdraw(SHIP:POSITION,  shipPlane * 100000000, RGB(0, 0, 1), "ship normal", 0.15, true).
		vecdraw(SHIP:BODY:POSITION,  ascNodeVector * 100000000, RGB(1, 1, 0), "asc node", 0.4, true).
		printLine("Waiting for " + getPointString(ascNodeVector:NORMALIZED)).
		vecdraw(calcOrbitCenter(SHIP:ORBIT),  ascNodeVector * SHIP:ORBIT:APOAPSIS + SHIP:ORBIT:BODY:RADIUS, RGB(1, 0, 1), "asc 3", 0.5, true).
	}
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
function calcOrbitalPlaneNormal {
    parameter myOrbit.
	local positionRelativeToShip is myOrbit:POSITION - myOrbit:BODY:POSITION.
	return VECTORCROSSPRODUCT(myOrbit:VELOCITY:ORBIT, positionRelativeToShip):NORMALIZED.
}

// Gives the delta V required for the given inclination change, provided both orbits are near circular.
function calcInclinationDeltaV5 {
	parameter targetInclination, burnNodeEta.
	local incChange is SHIP:ORBIT:INCLINATION - targetInclination.
	local velocityAtNode is VELOCITYAT(SHIP, burnNodeEta):ORBIT.
	// See https://en.wikipedia.org/wiki/Orbital_inclination_change#Calculation
	return 2 * velocityAtNode * SIN(incChange / 2).
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
	// See https://en.wikipedia.org/wiki/Orbital_inclination_change#Calculation
	parameter myOrbit, incChange, trueAnom.
	local meanMotion is calcMeanMotion(myOrbit).

	// Convert inclination change from degrees to radians for trigonometric functions
	local incChangeRad is incChange.
	local ecc is myOrbit:ECCENTRICITY.

	// Adjusting trigonometric calculations to use radians
	local sinHalfInc is SIN(incChange / 2).
	local oneEccCosAnom is 1 + ecc * COS(trueAnom).
	local numerator is  2 * sinHalfInc * oneEccCosAnom * meanMotion * myOrbit:SEMIMAJORAXIS.
	local denominator is SQRT(1 - ecc ^ 2) * COS((myOrbit:ARGUMENTOFPERIAPSIS + trueAnom)).
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