RUNONCEPATH("common.ks").
RUNONCEPATH("nodeTuner.ks").

parameter targetEntity is SHIP, targetObjective is "dock", targetAltitude is -1.

local targetSoi is _getEntityBody(targetEntity).
if targetAltitude = -1 {
	if (targetSoi = MUN) {
		set targetAltitude to 40000.
	} else if (targetSoi = MINMUS) {
		set targetAltitude to 20000.
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

	local wasLaunched is false.
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
		set wasLaunched to true.
	}

	if wasLaunched or findClosestApproach(SHIP:ORBIT, targetSoi):DISTANCE > SHIP:APOAPSIS  {
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
	until SHIP:ORBIT:BODY = targetSoi {warpToSoiTransfer().}

	if targetObjective = "flyby" {
		printLine("Warping to periapsis...").
		local warpToTime is TIME:SECONDS + SHIP:ORBIT:ETA:PERIAPSIS.
		WARPTO(warpToTime).
		wait until TIME:SECONDS >= warpToTime.
		
		printLine("At periapsis!  Confirm mission complete").
		printLine("Warping home in 10 seconds.").
		wait 10.
		warpToSoiTransfer().
		WAIT UNTIL SHIP:ORBIT:BODY = KERBIN.

		local returnNode is NODE(TIME:SECONDS + 10 * 60, 0, 0, 0).
		ADD returnNode.
		tuneNode(returnNode, {
				local periapsDelta is ABS(50000 - returnNode:ORBIT:PERIAPSIS).
				return choose 0 if periapsDelta < 5000 else periapsDelta.
			}).
		RUNPATH("mnode.ks", 1).
		clearNodes().

		printLine("Warping to periapsis...").
		_warpTo(TIME:SECONDS + SHIP:ORBIT:ETA:PERIAPSIS - 2 * 60).
		lock STEERING to RETROGRADE.
		alignRetrograde().
		lock THROTTLE to 1.
		PANELS off.
		until STAGE:NUMBER = 0 or SHIP:ALTITUDE - SHIP:GEOPOSITION:TERRAINHEIGHT < 10000{
			if SHIP:AVAILABLETHRUST = 0 {
				printLine("No throttle, staging.").
				stage.
				wait until stage:ready.
			}
			wait 0.5.
		}
		until STAGE:NUMBER = 0 {
			stage.
			wait until stage:ready.
		}
		printLine("Waiting to land")...
		set WARPMODE to "PHYSICS".
		set WARP to 4.
		wait until SHIP:STATUS = "LANDED" or SHIP:STATUS = "SPLASHED".
		
		printLine("Mission complete!")
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
					return choose 0 if newApoapsis > 0 and newApoapsis < (targetSoi:SOIRADIUS - 1000) else VELOCITYAT(SHIP, TIME:SECONDS + ETA:PERIAPSIS):ORBIT:MAG.
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

function warpToSoiTransfer {
	printLine("Warping to next SOI...").
	_warpTo(TIME:SECONDS + SHIP:ORBIT:ETA:TRANSITION + 10).
}

function _warpTo {
	parameter warpToTime.
	WARPTO(warpToTime).
	wait until TIME:SECONDS >= warpToTime.
}