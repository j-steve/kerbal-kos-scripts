
clearscreen.

until false {
	local lowestPart is getLowestPart().
	print "lowestPart: " + lowestPart.
	print "offsetHeight: " + (getPartHeight(SHIP:PARTS[0]) - getPartHeight(lowestPart)).
//print "x: " + (SHIP:PARTS[27]:p/OR,SHIP:PARTS[0]:position) - vdot(-FACING:VECTOR,SHIP:PARTS[27]:position)) at (0,8).
wait 1.
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