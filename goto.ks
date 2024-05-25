RUNONCEPATH("common.ks").
RUNONCEPATH("nodeTuner.ks").

parameter targetEntity is SHIP.

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
	RUNPATH("finetune.ks").
	clearNodes().
}

// Warp to new SOI.
until SHIP:ORBIT:BODY = targetSoi {
	printLine("Warping to next SOI...").
	WARPTO(TIME:SECONDS + SHIP:ORBIT:ETA:TRANSITION).
	WAIT 10.
}

// Burn retrograde to eliminate escape velocity.
preventEscape().
if apoapsis > 3 * 100000 {
	printLine("Reducing apoapsis").
	RUNPATH("circ", false).
}

// Target station and match its orbit.
if targetEntity <> targetSoi {
	set TARGET to targetEntity.
	until abs(SHIP:ORBIT:INCLINATION - targetEntity:ORBIT:INCLINATION) < 2 {
		printLine("Matching target inclination").
		RUNPATH("inc.ks").
		preventEscape().
	}
	printLine("Approaching target.").
	// if findClosestApproach(SHIP:ORBIT, targetEntity):distance > 5 {
	// 	printLine("Tuning node").
	// 	local approachNode is NODE(TIME:SECONDS, 0, 0, 0).
	// 	ADD approachNode.
	// 	tuneNode(approachNode, {return findClosestApproach(approachNode:ORBIT, targetEntity):distance.}).
	// 	//RUNPATH("mnode.ks", 1).
	// 	//clearNodes().
	// }
	local minApproach is findClosestApproach(SHIP:ORBIT, targetEntity).
	printLine("Will approach to within " + minApproach:DISTANCE).

	RUNPATH("revendous.ks").

	RUNPATH("dock.ks", targetEntity).
}

startupData:END().

function preventEscape {
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

function findClosestApproach {
	parameter _orbit, _target.
	local minDist is VANG(SHIP:POSITION, _target:POSITION).
	local minEta is 0.
	from {local t is TIME:SECONDS.} until t >= TIME:SECONDS + _orbit:PERIOD step {set t to t + 1.} do {
		local shipPos is POSITIONAT(SHIP, t).
		local targetPos is POSITIONAT(_target, t).
        local dist is abs((shipPos - targetPos):MAG).
        IF dist < minDist {
            SET minDist TO dist.
            SET minEta TO t.
        } else {
			return Lexicon("distance", minDist, "eta", minEta).
		}
    }
	return Lexicon("distance", minDist, "eta", minEta).
}
