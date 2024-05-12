run common.ks.

// Max percent deviation acceptable in deducing whether current orbit is aligned.
local MIN_DEVIATION is 0.1.

executePlaneAlignment().

function executePlaneAlignment {
	if not HASTARGET {
		printLine("Please select plane alignment target first.").
		return.
	}
	local relativeInclination is SHIP:ORBIT:inclination - TARGET:ORBIT:inclination.
	if relativeInclination < MIN_DEVIATION {
		printLine("Orbit is already aligned to " + TARGET:NAME + ".").
		return.
	}
	printLine("Aligning plane to " + TARGET:NAME + "...").
	run circ.ks. // Can't calculate alignment until we're circularized.
	createPlaneAlignNode().
	printLine("  done").
}

function createPlaneAlignNode {
	// Get relative inclination
	set relativeInclination to SHIP:ORBIT:inclination - TARGET:ORBIT:inclination.

	// Find ascending node
	set nodeLAN to SHIP:ORBIT:longitudeofascendingnode.
	set targetLAN to TARGET:ORBIT:longitudeofascendingnode.
	//set ascendingNode to targetLAN - nodeLAN.
	set ascendingnode to targetLAN + nodeLan / 2.
	printLine("Ascending node is " + ascendingNode).
	
	set orbitalVelocityAtNode to sqrt(body:mu * (2 / SHIP:ALTITUDE - 1 / SHIP:ORBIT:semimajoraxis)).

	// Calculate delta-v needed for inclination change
	set deltaV to 2 * orbitalVelocityAtNode * sin(relativeInclination / 2).
	printLine("deltaV is " + deltaV).
	
	set nodeEta to calculateTimeToTrueAnomaly(ascendingNode).
	printLine("Node ETA: " + nodeEta / 60).
}


function calculateTimeToTrueAnomaly {
    parameter targetDegrees.
    
    local currentTrueAnomaly is (ship:orbit:longitudeofascendingnode + ship:orbit:trueanomaly) * CONSTANT:DEGTORAD.
    local orbitalPeriod is ship:orbit:period.
    local meanMotion is (2 * CONSTANT:PI) / orbitalPeriod.
    local targetTrueAnomaly is targetDegrees * CONSTANT:DEGTORAD.
    
    local angularDistance is targetTrueAnomaly - currentTrueAnomaly.
    
    // Ensure angular distance is positive
    if angularDistance < 0 {
        set angularDistance to angularDistance + 2 * CONSTANT:PI.
    }
	printLine("angularDistance: " + angularDistance).
    
    local timeToTargetAnomaly is angularDistance / meanMotion.
    
    return timeToTargetAnomaly.
}