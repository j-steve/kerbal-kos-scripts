RUNONCEPATH("common.ks").
RUNONCEPATH("nodeTuner.ks").

local startupData is startup().
clearNodes().

if not HASTARGET {
	printLine("No target, defaulting to minmus.").
	set TARGET to MINMUS.
}
local targetSoi is TARGET.

if SHIP:STATUS = "PRELAUNCH" or SHIP:STATUS = "LANDED"  or SHIP:STATUS = "SUB_ORBITAL" {
	local launchInc is 90.
	if targetSoi = MINMUS {
		// TODO: if uncrewed, wait until minmus is overhead.
		// SET WARP TO 4.
		// WAIT UNTIL VANG(SHIP:FACING:FOREVECTOR, MINMUS:POSITION) < 10.
		// set launchInc to 84.
	}
	RUNPATH("launch.ks", launchInc).
	clearNodes().
}

if findOrbitalPatchForSoi(SHIP:ORBIT, TARGET):BODY <> targetSoi {
	RUNPATH("inc.ks").
	clearNodes().

	RUNPATH("txfr.ks").
	clearNodes().
}

local soiPatch is findOrbitalPatchForSoi(SHIP:ORBIT, targetSoi).
if abs(soiPatch:periapsis - 100000)  > 1000 {
	RUNPATH("finetune.ks").
	clearNodes().
}

// Warp to new SOI.
until SHIP:ORBIT:BODY = targetSoi {
	printLine("Warping to next SOI...").
	WARPTO(TIME:SECONDS + SHIP:ORBIT:ETA:TRANSITION).
	WAIT 10.
}

if SHIP:STATUS = "ESCAPING" {
	printLine("Burning to stay in SOI.").
	local orbitNode is NODE(TIME:SECONDS + ETA:PERIAPSIS, 0, 0, 0).
	ADD orbitNode.
	tuneNode(orbitNode, {
			local newApoapsis is orbitNode:ORBIT:APOAPSIS.
			return choose 0 if newApoapsis > 0 and newApoapsis < targetSoi:SOIRADIUS else VELOCITYAT(SHIP, TIME:SECONDS + ETA:PERIAPSIS):ORBIT:MAG.
		}).
	RUNPATH("mnode.ks", 1).
}

startupData:END().

