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

	add node(time:seconds + nodeEta, 0,0,0).
	// until false {
	// 	printLine(round(SHIP:ORBIT:trueanomaly, 2), true).
	// }
	
	// Create and execute maneuver node.
	createIncTransferNode(nodeEta).
	//RUNPATH("mnode.ks").
	
	startupData:END().
}

function createIncTransferNode {
	parameter nodeEta.
	clearNodes().
	local incNode is NODE(TIME:SECONDS + nodeEta, 0, 0, 0).
	add incNode.
	local targetPlane is calcOrbitalPlaneNormal(TARGET:ORBIT).
	// Start with a high dV increment.  When we "overshoot" the target plane, 
	// go back and check again in the other direction (make it negative)
	// but with a more granular value (divide it by 10).
	// Stop when we reach a reasonably small dV increment.
	tuneNode(incNode, {
		local nodePlane is calcOrbitalPlaneNormal(incNode:ORBIT).
		//clearvecdraws().
		//vecdraw(SHIP:POSITION,  targetPlane * 100000000, RGB(0, 1, 0), "normal", 0.15, true).
		//vecdraw(SHIP:POSITION,  nodePlane * 100000000, RGB(0, 0, 1), "normal", 0.15, true).
		local dotProduct is VDOT(nodePlane, targetPlane).
		local magnitudesProduct is nodePlane:MAG * targetPlane:MAG.

		local cosineOfAngle is dotProduct / magnitudesProduct.
		local angleInRadians is ARCCOS(cosineOfAngle).
		//printLine("Ang in rads: " + angleInRadians).
		return abs(angleInRadians).
		//return ARCCOS(VDOT(targetPlane, calcOrbitalPlaneNormal(incNode:ORBIT))).
		}).
}

function tuneNode {
	parameter tnode, calcDelta, minDeltaVIncrement is 0.001, minDeltaPerDv is .01.
	local dv is 10.
	local burnDirections is LIST("prograde", "normal", "radialout", "retrograde", "antinormal", "radialin").
	local availableBurnDirections is LIST(0,1,2,3,4,5).
	local priorDelta is calcDelta:CALL().
	printLine("Tuning node...").
	until ABS(dv) < minDeltaVIncrement {
		local deltas is LIST(0, 0, 0, 0, 0, 0).
		//printLine("Prior delta: " + round(priorDelta, 3)).
		for i in availableBurnDirections {
			// Apply the thrust in this direction as a test to see how effective it would be.
			incrementNodeVector(burnDirections[i]).
			set deltas[i] to calcDelta:CALL().
			 // Undo the thrust application for now.
			incrementNodeVector(burnDirections[getOppositeDirectionIndex(i)]).
		}
		// Find the best possible thrust direction from among the 6 available options.
		local minDelta is -1.
		local minDeltaIndex is -1.
		for i in availableBurnDirections {
			if minDeltaIndex = -1 or deltas[i] < minDelta {
				set minDelta to deltas[i].
				set minDeltaIndex to i.
			}
		}
		local deltaImprovement is priorDelta - minDelta.
		if deltaImprovement / dv > minDeltaPerDv {
			 // Re-apply the thrust in the best possible direction, for real this time.
			incrementNodeVector(burnDirections[minDeltaIndex]).
			set priorDelta to minDelta.
			// Remove the opposite direction from the available directions, until we decrement dV.
			// There's no benefit to burning two opposite directions, and trying to do so may get us stuck in an infinate loop.
			removeValue(availableBurnDirections, getOppositeDirectionIndex(minDeltaIndex)).
			if (debugMode) {
				printLine("Best vector was " + burnDirections[minDeltaIndex] + " at dv " + dv).
				printLine("change from " + round(priorDelta, 2) + " to " + round(minDelta, 2)).
			}
		} else {
			// All options suck: try increasing by a smaller amount.
			set dv to dv / 10.
			set availableBurnDirections to LIST(0,1,2,3,4,5). // Reset burn directions
			if (debugMode) {
				printLine("Decreasing dv to " + dv).
			}
		}
	}
	printLine("  OK").

	function incrementNodeVector {
		parameter burnDirection.
		local multiplier is choose 1 if burnDirection = "prograde" or burnDirection = "normal" or burnDirection = "radialout" else -1.
		if burnDirection = "prograde" or burnDirection = "retrograde" {
			set tnode:PROGRADE to tnode:PROGRADE + dv * multiplier.
		} else if burnDirection = "normal" or burnDirection = "antinormal" {
			set tnode:NORMAL to tnode:NORMAL + dv * multiplier.
		} else {
			set tnode:RADIALOUT to tnode:RADIALOUT + dv * multiplier.
		}
	}

	function getOppositeDirectionIndex {
		parameter directionIndex.
		return MOD(directionIndex + burnDirections:LENGTH/2, burnDirections:LENGTH).
	}
}

function removeValue {
	parameter myList, valToRemove.
	local valIndex is myList:FIND(valToRemove).
	if valIndex > -1 {
		myList:REMOVE(valIndex).
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
		vecdraw(obj:POSITION,  targetPlane * 10000000, RGB(1, 0, 0), "target normal", 0.15, true).
		vecdraw(SHIP:POSITION,  shipPlane * 10000000, RGB(0, 0, 1), "ship normal", 0.15, true).
		vecdraw(SHIP:BODY:POSITION,  ascNodeVector * 10000000, RGB(1, 1, 0), "asc node", 0.4, true).
		printLine("asc node vector: " + getPointString(ascNodeVector:NORMALIZED)).
	}
	// From an overhead view, the vector line will intersect the orbit at the point of the ascending node.
	// To find the degree at which the intersection occurs, take the arctan of that vector line.
	// (We ignore the y coordinate given that this is an overhead view. It's not needed since the orbital plane is 2D.)
	local ascendingNodeAngle is ARCTAN2( ascNodeVector:Z, ascNodeVector:X).	
	if debugMode {
		printLine("asc node vector is " + getPointString(ascNodeVector)).
		printLine("ascendingNodeAngle " + round(ascendingNodeAngle, 2) + "°").
		vecdraw(SHIP:BODY:POSITION,  V(1, 0, 0) * 10000000, RGB(0.5, 0.5, 0.5), "X", 0.4, true).
		vecdraw(SHIP:BODY:POSITION,  V(0, 1, 0) * 10000000, RGB(0.75, 0.75, 0.75), "Y", 0.4, true).
		vecdraw(SHIP:BODY:POSITION,  V(0, 0, 1) * 10000000, RGB(0.85, 0.85, 0.85), "Z", 0.4, true).
		vecdraw(SHIP:BODY:POSITION,  V(ascNodeVector:X, 0, ascNodeVector:Z):normalized * 10000000, RGB(0, 1, 1), "asc node v", 0.4, true).
		printLine("Body position: " + getPointString(SHIP:BODY:POSITION)).
	}

	// TODO: the ideal 2D view would be the orbit's normal vector, not sure how to do that.
	if ABS(90 - SHIP:ORBIT:INCLINATION) < 35 or ABS(-90 - SHIP:ORBIT:INCLINATION) < 35 {
		printLine("--------------------------------------------").
		printLine("WARNING: Current orbit is highly polar!").
		printLine("    Inclination calulation may be imprecise.").
		printLine("--------------------------------------------").
	}

	// This angle is correct based on some x axis.  To convert this to a useable true anomaly, find the angle of the periapsis, 
	// and then subtract that to get the true anomoly (since true anomaly is "0" at periapsis.)
	local periapsisCoords is POSITIONAT(SHIP, TIME:SECONDS + ETA:PERIAPSIS) - SHIP:ORBIT:BODY:POSITION.
	local periapsisAngle is ARCTAN2(periapsisCoords:Z, periapsisCoords:X).
	if SHIP:ORBIT:INCLINATION > 90 {
		// The orbit is retrograde (clockwise).
		set ascendingNodeAngle to (360 - ascendingNodeAngle) + periapsisAngle.
	} else {
		// The orbit is prograde (counterclockwise).
		printLine("Using CCW logic").
		set ascendingNodeAngle to (360 - periapsisAngle) + ascendingNodeAngle.
	}


	if debugMode {
		vecdraw(SHIP:BODY:POSITION,  periapsisCoords:normalized * 10000000, RGB(0.99, 0, 0.55), "periapsis", 0.4, true).
		printLine("Periapsis coords: " + getPointString(periapsisCoords)).
		printLine("Periapsis angle: " + round(periapsisAngle, 2) +  "°").
		printLine("SHIP:ORBIT:TRUEANOMALY " + round(SHIP:ORBIT:TRUEANOMALY, 2) + "°").
		printLine("Descending node true anomaly is " + round(ascendingNodeAngle, 2) + "°").

		local halfwayPoint is (periapsisCoords:normalized - ascNodeVector:normalized):NORMALIZED.
		printLine("halfwayPoint coords: " + getPointString(halfwayPoint)).
		vecdraw(SHIP:BODY:POSITION,  halfwayPoint * 10000000, RGB(0.15, 0.35, 0.25), "halfway", 0.4, true).
	}

	// Technically this logic has found us the descending node (because of the way we used the acsending vector).
	// So add 180 to get the ascending node instead and return that on a 360-degree scale.
	return MOD(ascendingNodeAngle + 180, 360).
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