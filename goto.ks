// -------------------------------------------------------------------------------------------------
// This program is a "master controller" that can run a complete mission from launch to return,
// by chaining together the other sub-programs as needed.
//
// PARAMETERS:
// 	 targetEntity: The vessel name (`"Station II"`) or body name (`MINMUS`).  If not set, defaults to TARGET.
//   targetObjective: What to do on reaching the target.  Valid options are "flyby", "orbit", "dock", or "land".
// 
// EXAMPLE USAGE:
//   goto.ks().                    : Launch, intercept Minmus, and dock at Station II in its orbit.
//   goto.ks(mun, "flyby", 30000). : Launch, flyby the mun at 30km, and return & land at Kerbin.
//   goto.ks(sun, "flyby").        : Launch, escape to Kerbol (the sun) orbit, and return to Kerbin.
// -------------------------------------------------------------------------------------------------

RUNONCEPATH("/common/init.ks").

parameter targetEntity is -1, targetObjective is "dock", targetAltitude is -1.

if targetEntity = -1 {
	if HASTARGET {
		SET targetEntity to TARGET.
	} else {
		printLine("No target, defaulting to Station II.").
		SET targetEntity to VESSEL("Station II").
	}
}
local targetSoi is _getEntityBody(targetEntity).
if targetAltitude = -1 {
	if targetObjective = "land" {
		if targetEntity:ATM:EXISTS {
			set targetAltitude to targetEntity:ATM:HEIGHT * 0.8.
		} else {
			set targetAltitude to 0.
		}
	} else if (targetSoi = MUN) {
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

	set TARGET to targetSoi.

	local wasLaunched is false.
	if SHIP:STATUS = "PRELAUNCH" or SHIP:STATUS = "LANDED" {
		local launchInc is 90.
		if targetSoi = MINMUS {
			// TODO: if uncrewed, wait until TAGET is overhead, e.g. for minmus.
			// SET WARP TO 4.
			// WAIT UNTIL VANG(SHIP:FACING:FOREVECTOR, MINMUS:POSITION) < 10.
			// set launchInc to 84.
		}
		RUNPATH("launch.ks", launchInc).
		clearNodes().
		set wasLaunched to true.
	}

	if targetEntity = SUN {
		if SHIP:ORBIT:BODY <> SUN {
			_execEscape().
		}
		if SHIP:ORBIT:BODY = SUN {
			printLine("Reached Kerbol (Sun) orbit.").
			if targetObjective = "flyby" {
				local returnNode is addNodeAtEta(60).
				until returnNode:ORBIT:HASNEXTPATCH and returnNode:ORBIT:NEXTPATCHETA < 60 * 60 * 5 {
					// Wait for patch to be <= 5 hours into the future.  We don't want to wait to intercept Kerbin next year or something.
					set returnNode:PROGRADE to returnNode:PROGRADE - 1.
				}
				set returnNode:PROGRADE to returnNode:PROGRADE - 10. // Add a buffer to make sure we return.
				RUNPATH("mnode.ks", 1).
				warpToSoiTransfer().
				RUNPATH("return.ks").
			}
		}
		return.
	}

	local soiPatch is findOrbitalPatchForSoi(SHIP:ORBIT, targetSoi).
	if wasLaunched or (soiPatch:BODY <> targetSoi and findClosestApproach(SHIP:ORBIT, targetSoi):DISTANCE > SHIP:APOAPSIS)  {
		local targetInclination is targetSoi:ORBIT:INCLINATION.
		if SHIP:ORBIT:BODY = targetSoi {
			// If we're already orbiting the same body, then match inclination with the target directly.
			set targetInclination to targetEntity:ORBIT:INCLINATION.
		}
		if ABS(SHIP:ORBIT:INCLINATION - targetInclination) > 1 {
			printLine("target: " + targetSoi:NAME).
			printLine("Updating inc" + ABS(SHIP:ORBIT:INCLINATION - targetSoi:ORBIT:INCLINATION)).
			RUNPATH("inc.ks").
			clearNodes().
		} else {
			printLine("Inclination within 1 degree, not adjusting.").
		}

		RUNPATH("txfr.ks").
		clearNodes().
		set soiPatch to findOrbitalPatchForSoi(SHIP:ORBIT, targetSoi).
	}

	// TODO: Why isn't this being triggered on a trip to minmus?
	printLine("ship body: " + ship:body + " target soi: " + targetSoi).
	if SHIP:BODY <> targetSoi {
		// If our target altitude is very low (or 0), we dont want to force the final distance to hit that exactly.
		// The min variance is the minimum amount of deviation considered acceptable, e.g. even if we are off by X meters,
		// we will say "mission accomplished".
		local MIN_VARIANCE_METERS is 1000.
		until abs(soiPatch:periapsis - targetAltitude)  < MAX(targetAltitude * .05, MIN_VARIANCE_METERS) {
			RUNPATH("finetune.ks", targetAltitude).
			clearNodes().
		}
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

		RUNPATH("return.ks").
		
		printLine("Mission complete!").
		return.
	} else if targetObjective = "land" {
		RUNPATH("land.ks").
		printLine("Mission complete!").
		return.
	}

	// Burn retrograde to eliminate escape velocity.
	if SHIP:ORBIT:TRANSITION = "ESCAPE" or SHIP:ORBIT:APOAPSIS > 3 * 100000 {
		printLine("Reducing apoapsis").
		RUNPATH("circ", false).
	}

	// Target station and match its orbit.
	if targetEntity <> targetSoi {
		set TARGET to targetEntity.
		until abs(SHIP:ORBIT:INCLINATION - targetEntity:ORBIT:INCLINATION) < 2.5 {
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
			local orbitNode is addNodeAtEta(ETA:PERIAPSIS).
			tuneNode(orbitNode, {
					local newApoapsis is orbitNode:ORBIT:APOAPSIS.
					return choose 0 if newApoapsis > 0 and newApoapsis < (targetSoi:SOIRADIUS - 1000) else VELOCITYAT(SHIP, TIME:SECONDS + ETA:PERIAPSIS):ORBIT:MAG.
				}).
			RUNPATH("mnode.ks", 1).
			clearNodes().
		}
	}

	function _execEscape {
		local escapeSection is printSectionStart("Escaping to Kerbol...").
		local orbitNode is addNodeAtEta(ETA:PERIAPSIS).
		until orbitNode:ORBIT:TRANSITION = "ESCAPE" {
			set orbitNode:PROGRADE to orbitNode:PROGRADE + 1.
		}
		set orbitNode:PROGRADE to orbitNode:PROGRADE + 10. // Add a buffer to ensure we really do escape.
		RUNPATH("mnode.ks", 1).
		warpToSoiTransfer().
		escapeSection:END().
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
	} else {
		// if _entity:ISTYPE("Vessel") or _entity:ISTYPE("Station")
		return _entity:ORBIT:BODY.
	}
}

function warpToSoiTransfer {
	printLine("Warping to next SOI...").
	warpToEta(SHIP:ORBIT:ETA:TRANSITION + 10).
}