RUNONCEPATH("common.ks").

local startupData is startup().

if not HASTARGET {
	printLine("No target, defaulting to minmus.").
	set TARGET to MINMUS.
}

if SHIP:STATUS = "PRELAUNCH" or SHIP:STATUS = "LANDED" {
	// TODO: wait until target is overhead; set launch inclination.
	RUNPATH("launch.ks").
}

RUNPATH("inc.ks").

RUNPATH("txfr.ks").

RUNPATH("finetune.ks").

startupData:END().