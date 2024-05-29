RUNONCEPATH("common.ks").
RUNONCEPATH("nodeTuner.ks").

parameter targetEntity is SHIP, targetObjective is "dock", targetAltitude is -1.

local targetSoi is _getEntityBody(targetEntity).
if targetAltitude = -1 {
	if (targetSoi = MUN) {
		set targetAltitude to 100000.
	} else if (targetSoi = MINMUS) {
		set targetAltitude to 30000.
	} else if targetSoi:ATM:EXISTS {
		set targetAltitude to targetSoi:ATM:HEIGHT + 10000.
	} else {
		set targetAltitude to 50000.
	}
}

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
	set TARGET to targetSoi.

	if SHIP:STATUS = "PRELAUNCH" or SHIP:STATUS = "LANDED" {
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

// Returns the "Body" associated with the given entity.
// If the entity is a body, it will just return that entity.
// If it's a ship, it'll return the body it is orbiting.
function _getEntityBody {
	parameter _entity.
	if _entity:ISTYPE("Body") {
		return _entity.
	} else if _entity:ISTYPE("Vessel") {
		return _entity:ORBIT:BODY.
	} else {
		printLine("ERROR: Cannot get entity body for " + _entity).
		return _entity:THROW_ERROR. // Access a non-existant property to throw an exception.
	}
}