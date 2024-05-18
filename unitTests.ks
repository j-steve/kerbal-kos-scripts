RUNONCEPATH("common.ks.").

testInc().

function testInc {
	RUNONCEPATH("inc.ks.").

	if 38.0990705883338 - calcEccentricAnomaly(0.18, 45) > 0.000001 {
		printLine("TEST FAILED: calcEccentricAnomaly").
	}
	if 31.735562 - calcMeanAnomaly(0.18, 45) > 0.000001  {
		printLine("TEST FAILED: calcMeanAnomaly").
	}
	printLine("Testing complete.").
}