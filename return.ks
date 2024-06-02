// -------------------------------------------------------------------------------------------------
// This program plots a return path to Kerbin from one of its moons, 
// performs an aerobraking movement, and lands.
//
// For a similar program designed for landing on atmosphere-less bodies, see `land.ks.`.
//
// TODO: This could be made more generic to land on any body with an atmosphere,
//       but currently it does have some Kerbin-specific logic.
// -------------------------------------------------------------------------------------------------

RUNONCEPATH("common.ks").
RUNONCEPATH("nodeTuner.ks").

local startupData is startup("Returning to Kerbin.").
clearNodes().

if SHIP:ORBIT:BODY <> KERBIN and not SHIP:ORBIT:hasnextpatch {
    local escapeSection is printSectionStart("Burning to escape " + SHIP:ORBIT:BODY:NAME + " SOI...").
    local nodeStartEta is ETA:PERIAPSIS.
    if PERIAPSIS <= 0 {set nodeStartEta to ETA:apoapsis.}
    local escapeNode is NODE(TIME:SECONDS + nodeStartEta, 0, 0, 0).
    ADD escapeNode.
    until escapeNode:ORBIT:hasnextpatch {
        set escapeNode:prograde to escapeNode:prograde + 1.
        wait 0.0001.
    }
    set escapeNode:prograde to escapeNode:prograde * 1.1. // Add 10% extra as a buffer.
    RUNPATH("mnode.ks", 1).
    clearNodes().
    escapeSection:END().
}

if SHIP:ORBIT:BODY <> KERBIN {
    printLine("Warpint to Kerbin SOI....").
    wait 1. // Ensure burn is 0 so we can warp.
    warpToEta( SHIP:ORBIT:nextpatcheta + 60).
}

until SHIP:ORBIT:TRANSITION <> "ESCAPE" {
    local cancelEscapeSection is printSectionStart("Preventing escape...").
    alignRetrograde().
    lock THROTTLE to 1.
    wait until SHIP:ORBIT:TRANSITION <> "ESCAPE".
    lock THROTTLE to 0.
    cancelEscapeSection:END().
}

until PERIAPSIS < 500000 {
    local periapsisSection is printSectionStart("Reducing periapsis...").
    alignRetrograde().
    lock THROTTLE to 1.
    wait until PERIAPSIS < 500000.
    lock THROTTLE to 0.
    // local returnNode is NODE(TIME:SECONDS + 10 * 60, 0, 0, 0).
    // ADD returnNode.
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
warpToEta(ETA:PERIAPSIS - 5 * 15).
RCS on.
PANELS off.
lock STEERING to RETROGRADE.
local facingRetrogradeTimeout is TIME:SECONDS + 60.
wait until isFacingRetrograde() or TIME:SECONDS >= facingRetrogradeTimeout. // Wait for heading alignment if possible.
if ETA:PERIAPSIS < ETA:APOAPSIS {warpToEta(ETA:PERIAPSIS - 60).}
lock THROTTLE to 1.

periapsisWarpSection:END().

// WARNING: During this section it is likely we'll lose connection to volume 0,
// so avoid running anything from `common.ks` or other fils until we've passed through the plasma.
// Otherwise we may face a "Volume 0 is inaccessible" error message during execution.
local burnSlowSection is printSectionStart("Burning to slow down...").
set WARPMODE to "PHYSICS".
set WARP to 4.
until STAGE:NUMBER = 0 or SHIP:ALTITUDE - SHIP:GEOPOSITION:TERRAINHEIGHT < 15000{
    if SHIP:AVAILABLETHRUST = 0 {
        //printLine("No throttle, staging.").
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
wait until SHIP:ALTITUDE < 750 or SHIP:STATUS = "LANDED" or SHIP:STATUS = "SPLASHED".
set WARP to 0.
if SHIP:ALTITUDE > 25 and SHIP:STATUS <> "LANDED" and SHIP:STATUS <> "SPLASHED" {
    wait 5. // Wait for chutes
    set WARP to 4.
    wait until SHIP:ALTITUDE < 200 or SHIP:STATUS = "LANDED" or SHIP:STATUS = "SPLASHED".
    set WARP to 2.
    wait until SHIP:ALTITUDE < 50 or SHIP:STATUS = "LANDED" or SHIP:STATUS = "SPLASHED".
    set WARP to 1.
    wait until SHIP:ALTITUDE < 25 or SHIP:STATUS = "LANDED" or SHIP:STATUS = "SPLASHED".
    set WARP to 0.
}

startupData:END("Welcome to " + SHIP:BODY:NAME + "!").
