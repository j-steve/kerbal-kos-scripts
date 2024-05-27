RUNONCEPATH("common.ks").
RUNONCEPATH("nodeTuner.ks").

parameter targetEntity is SHIP, targetAltitude is 100000, targetObjective is "dock".

local executeGoto is {
	local startupData is startup().
	clearNodes().

	if targetEntity = SHIP {
		if HASTARGET {
			SET targetEntity to TARGET.
		} else {
			printLine("No target, defaulting to Station II.").
			SET targetEntity to VESSEL("Station II").
		}
	} else {
		set TARGET to targetEntity.
	}
	local targetSoi is choose TARGET if targetEntity:ISTYPE("BODY") else targetEntity:BODY.
	set TARGET to targetSoi.

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
	if SHIP:BODY <> targetSoi and abs(soiPatch:periapsis - 100000)  > 1000 {
		RUNPATH("finetune.ks", targetAltitude).
		clearNodes().
	}

	// Warp to new SOI.
	until SHIP:ORBIT:BODY = targetSoi {
		printLine("Warping to next SOI...").
		local warpToTime is TIME:SECONDS + SHIP:ORBIT:ETA:TRANSITION + 10.
		WARPTO(warpToTime).
		wait until TIME:SECONDS >= warpToTime.
	}

	if targetObjective = "flyby" {
		printLine("Flyby complete.").
		return.
	}

	// Burn retrograde to eliminate escape velocity.
	_preventEscape().
	if apoapsis > 3 * 100000 {
		printLine("Reducing apoapsis").
		RUNPATH("circ", false).
	}

	// Target station and match its orbit.
	if targetEntity <> targetSoi {
		set TARGET to targetEntity.
		until abs(SHIP:ORBIT:INCLINATION - targetEntity:ORBIT:INCLINATION) < 1 {
			printLine("Matching target inclination").
			RUNPATH("inc.ks").
			_preventEscape().
		}

		RUNPATH("revendous.ks").

		RUNPATH("dock.ks", targetEntity).
	}

	startupData:END().

	function _preventEscape {
		if SHIP:STATUS = "ESCAPING" {
			printLine("Burning to stay in SOI.").
			local orbitNode is NODE(TIME:SECONDS + ETA:PERIAPSIS, 0, 0, 0).
			ADD orbitNode.
			tuneNode(orbitNode, {
					local newApoapsis is orbitNode:ORBIT:APOAPSIS.
					return choose 0 if newApoapsis > 0 and newApoapsis < targetSoi:SOIRADIUS else VELOCITYAT(SHIP, TIME:SECONDS + ETA:PERIAPSIS):ORBIT:MAG.
				}).
			RUNPATH("mnode.ks", 1).
			clearNodes().
		}
	}
}.

executeGoto().