RUNONCEPATH("common.ks.").

testInc().

function testInc {
	RUNONCEPATH("inc.ks.").
	local allPass is true.
	if 38.0990705883338 - calcEccentricAnomaly(0.18, 45) > 0.000001 {
		printLine("ERROR - TEST FAILED: calcEccentricAnomaly").
		set allPass to false.
	}
	if 31.735562 - calcMeanAnomaly(0.18, 45) > 0.000001  {
		printLine("ERROR - TEST FAILED: calcMeanAnomaly").
		set allPass to false.
	}
	if allPass {
		printLine("All tests passed!.").
	}
}