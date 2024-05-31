RUNONCEPATH("common.ks").

parameter atPrograde is true.

// Max percent deviation acceptable in deducing whether current orbit is circularized.
local MIN_DEVIATION is 0.001.

if atPrograde {
	circularizeOrbit(SHIP:ORBIT:APOAPSIS, SHIP:ORBIT:ETA:APOAPSIS, 1).
} else {
	circularizeOrbit(SHIP:ORBIT:PERIAPSIS, SHIP:ORBIT:ETA:PERIAPSIS, -1).
}

function circularizeOrbit {
	parameter burnPointAltitude, burnPointEta, progradeModifier.
	lock circularDeviation to 1 - SHIP:ORBIT:PERIAPSIS / SHIP:ORBIT:APOAPSIS.
	if circularDeviation < MIN_DEVIATION {
		printLine("Orbit is alreacdy circ'd with " + round(circularDeviation * 100, 4) + "% deviation.").
		return.
	}

	local startupData is startup("Circularizing orbit...").

	local burnPointRadius is burnPointAltitude + BODY:RADIUS. // Assuming at current altitude
	local txfrDeltaV is calcVisViva(burnPointRadius, SHIP:ORBIT:SEMIMAJORAXIS, burnPointRadius, burnPointRadius).
	add node(TIME:SECONDS + burnPointEta, 0, 0, txfrDeltaV * progradeModifier).
	run mnode.ks.

	
	printLine("  done: circ'd at " + round(SHIP:ORBIT:APOAPSIS / 1000) + " km with" + round(circularDeviation * 100, 4) + "% deviation.").
	startupData:END().
}