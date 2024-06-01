// Returns to Kerbin from orbit and parachutes to landing.
RUNONCEPATH("common.ks").
RUNONCEPATH("nodeTuner.ks").

local startupData is startup("Returning to Kerbin.").

if SHIP:ORBIT:BODY <> KERBIN and not SHIP:ORBIT:hasnextpatch {
    local escapeNode is NODE(TIME:SECONDS + ETA:PERIAPSIS, 0, 0, 0).
    ADD escapeNode.
    until escapeNode:ORBIT:hasnextpatch {
        set escapeNode:prograde to escapeNode:prograde + 1.
        wait 0.0001.
    }
    set escapeNode:prograde to escapeNode:prograde * 1.1. // Add 10% extra as a buffer.
    RUNPATH("mnode.ks", 1).
    clearNodes().
}

if SHIP:ORBIT:BODY <> KERBIN {
    printLine("Warpint to Kerbin SOI....").
    wait 1. // Ensure burn is 0 so we can warp.
    local warpToTime is TIME:SECONDS + SHIP:ORBIT:nextpatcheta + 60.
    WARPTO(warpToTime).
    wait until TIME:SECONDS >= warpToTime.
}

if ABS(50000-PERIAPSIS) > 100000 {
    local periapsisSection is printSectionStart("Reducing periapsis...").
    local returnNode is NODE(TIME:SECONDS + 10 * 60, 0, 0, 0).
    ADD returnNode.
    until ABS(50000-PERIAPSIS) < 100000 {
        set returnNode:prograde to returnNode:prograde - .1.
    }
    // tuneNode(returnNode, {
    //         if returnNode:ORBIT:HASNEXTPATCH {return 99999999999999999.}
    //         local periapsDelta is ABS(50000 - returnNode:ORBIT:PERIAPSIS).
    //         return choose 0 if periapsDelta < 5000 else periapsDelta.
    //     }, .001, 1).
    // RUNPATH("mnode.ks", 1).
    // clearNodes().
    periapsisSection:END().
}

until ABS(50000-PERIAPSIS) < 2500 {
    RUNPATH("finetune.ks", 50000, KERBIN).
}

local periapsisWarpSection is printSectionStart("Warping to periapsis...").
_warpTo(TIME:SECONDS + SHIP:ORBIT:ETA:PERIAPSIS - 3 * 60).
lock STEERING to RETROGRADE.
lock THROTTLE to 1.
PANELS off.
alignRetrograde().
periapsisWarpSection:END().

local burnSlowSection is printSectionStart("Burning to slow down...").
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
burnSlowSection:END("All stages completed.").

printLine("Waiting to land")...
set WARPMODE to "PHYSICS".
set WARP to 4.
wait until SHIP:STATUS = "LANDED" or SHIP:STATUS = "SPLASHED".
set WARP to 0.

startupData:END("Welcome to " + SHIP:BODY:NAME + "!").

function _warpTo {
	parameter warpToTime.
	WARPTO(warpToTime).
	wait until TIME:SECONDS >= warpToTime.
}
