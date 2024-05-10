
list ENGINES in enginesList.

function calcBurnTime {
	parameter deltaV.
	local remainingDeltaV is deltaV.
	local totalBurnTime is 0.
	from {local i is SHIP:STAGENUM.} until i = 0 step {set i to i-1.} do {
		if remainingDeltaV <= 0 {break.}
		print "T -" + i.
		local stageDeltaV is SHIP:STAGEDELTAV(i):CURRENT.
		set remainingDeltaV to remainingDeltaV - stageDeltaV.
	} 
	local acceleration is SHIP:MAXTHRUST / SHIP:MASS.
	return deltaV / acceleration.
}