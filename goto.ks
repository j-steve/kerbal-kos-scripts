RUNONCEPATH("common.ks").

local startupData is startup().

if not HASTARGET {
	printLine("No target, defaulting to minmus.").
	set TARGET to MINMUS.
}

if SHIP:STATUS = "PRELAUNCH" or SHIP:STATUS = "LANDED"  or SHIP:STATUS = "SUB_ORBITAL" {
	local launchInc is 90.
	if TARGET = MINMUS {
		// TODO: if uncrewed, wait until minmus is overhead.
		// SET WARP TO 4.
		// WAIT UNTIL VANG(SHIP:FACING:FOREVECTOR, MINMUS:POSITION) < 10.
		// set launchInc to 84.
	}
	RUNPATH("launch.ks", launchInc).
	clearNodes().
}

RUNPATH("inc.ks").
clearNodes().

RUNPATH("txfr.ks").
clearNodes().

RUNPATH("finetune.ks").
clearNodes().

startupData:END().