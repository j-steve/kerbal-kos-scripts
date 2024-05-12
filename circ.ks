run common.ks.

// Max percent deviation acceptable in deducing whether current orbit is circularized.
local MIN_DEVIATION is 0.001.

circularizeOrbit().

function circularizeOrbit {
	if 1 - SHIP:ORBIT:PERIAPSIS / SHIP:ORBIT:APOAPSIS < MIN_DEVIATION {
		printLine("Orbit is alreacdy circularized.").
		return.
	}

	printLine("Circularizing orbit..." ).

	local apoapsisRadius is SHIP:ORBIT:APOAPSIS + BODY:RADIUS. // Assuming at current altitude
	local txfrDeltaV is calcVisViva(apoapsisRadius, SHIP:ORBIT:SEMIMAJORAXIS, apoapsisRadius, apoapsisRadius).
	add node(TimeSpan(SHIP:OBT:ETA:APOAPSIS), 0, 0, txfrDeltaV).
	run mnode.ks.

	printLine("  done: circularized at " + round(SHIP:ORBIT:APOAPSIS / 1000) + " km").
}