
clearscreen.

until false {
	local lowestPart is getLowestPart().
	print "lowestPart: " + lowestPart.
	print "offsetHeight: " + (getPartHeight(SHIP:PARTS[0]) - getPartHeight(lowestPart)).
//print "x: " + (SHIP:PARTS[27]:p/OR,SHIP:PARTS[0]:position) - vdot(-FACING:VECTOR,SHIP:PARTS[27]:position)) at (0,8).
wait 1.
}

// Returns the height of the ship above ground.
// Specifically, the height of the core part (the space capsule or control pod) 
// relative to the height of the lowest-level part (presumably an engine).
// Useful because basic altitutde caluclation is relative to the core of the ship, not its base.
function getShipHeight {
	local lowestPart is getLowestPart().
	return getPartHeight(SHIP:PARTS[0]) - getPartHeight(lowestPart)
}


function getLowestPart {
    local lowestPartHeight is getPartHeight(SHIP:PARTS[0]).
	local lowestPart is SHIP:PARTS[0].

    for part in SHIP:PARTS {
        local partHeight is getPartHeight(part).
        if partHeight < lowestPartHeight {  // Remember, more negative means further back along -facing vector
            set lowestPartHeight to partHeight.
            set lowestPart to part.
        }
    }
    return lowestPart.
}

// Given a part, returns its vertical height on the ship.
function getPartHeight {
	parameter part.
	return vdot(SHIP:FACING:FOREVECTOR, part:POSITION).
}