// Returns to Kerbin from orbit and parachutes to landing.
RUNONCEPATH("common.ks").
RUNONCEPATH("nodeTuner.ks").

local startupData is startup("Returning to Kerbin.").

printLine("Warping to periapsis...").
_warpTo(TIME:SECONDS + SHIP:ORBIT:ETA:PERIAPSIS - 2 * 60).
lock STEERING to RETROGRADE.
alignRetrograde().
lock THROTTLE to 1.
PANELS off.

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