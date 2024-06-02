// -------------------------------------------------------------------------------------------------
// This program exposes `tuneNode()`, a powerful function which can optimize a given maneuver node
// for any purpose.
// -------------------------------------------------------------------------------------------------

@lazyGlobal OFF.
RUNONCEPATH("common.ks").

parameter debugMode is false.

// Given a maneuver node and a delta calculation function,
// this function will optimize the node to get as close as possible to the expected result.
// PARAMS:
//   tnode: a maneuver node.  It should have been added to the ship orbit already at the desired burn time,
//     but its normal/prograde/radialout values can be set to 0.  Whatever they are set to will be the
//     starting point for our tuning.
//   calcDelta: a function which returns a scalar value.  The absolute value of this number shoule indicate
//     how "good" the current tuning is: lower numbers are better, and 0 means perfect.  
//     We will stop looking for better options if it ever reaches 0.
//   minDeltaPerDv: the minimum improvement to our calcDelta function result we need to get in order to 
//     "justify" the delta V on the burn.  A lower number here may lead to a node that gets us closer 
//      to our ideal outcome, but the deltaV cost may be so high that it may not be worth it.
//   minDeltaVIncrement: the smallest amount of deltaV that's worth bothering to set on a node.
//      For example, if set to 1, then we will only tune our node to the nearest 1 deltaV increment,
//      and the final burn deltaV would be a whole number.
//      Smaller numbers here could lead to more percision in the final outcome, but will also increase
//      the `tuneNode` calculation time (and may have little or no impact on the final result anyways
//      if we can't actually burn that precisely).
function tuneNode {
	parameter tnode, calcDelta, minDeltaPerDv is .001, minDeltaVIncrement is 0.001.
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
			set deltas[i] to ABS(calcDelta:CALL()).
			if deltas[i] = 0 {
				// We can't beat 0, we can stop here and return early!
				printLine("  OK").
				return.
			}
			 // Undo the thrust application for now.
			incrementNodeVector(burnDirections[getOppositeDirectionIndex(i)]).            
			if (debugMode) {
                printLine("  " + burnDirections[i] + ": " + round(deltas[i], 2)).
            }
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
        if (debugMode) {
            printLine("best improvement: " + round(deltaImprovement, 5)).
        }
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
        if debugMode {
            wait 5.
        }
        wait 0.0001.
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