RUNONCEPATH("common.ks").

// The minimum deviation between the expected node and the actual node.
// Lower number means that the final course will match the orignal more precisely,
// but it may take longer to achieve.
declare parameter maxFinalDeviation is 0.1, maxFacingDeviation is 0.5.

printLine("Executing next maneuver node.").
printLine("").

// Align header.
printLine("Aligning header...").
set WARP to 0.
SAS off.
lock STEERING to NEXTNODE:BURNVECTOR.
wait until VANG(SHIP:FACING:FOREVECTOR, NEXTNODE:BURNVECTOR) < 0.05.

// Pre-stage, if needed
until SHIP:AVAILABLETHRUST > 0 {
	print "No thrust, staging.".
	stage.
	wait until STAGE:READY.
}

// Calculate burn time.
printLine("Aligned, warping to node start...").
// Atomic engines may show an initial acceleration of 0 (they need to warm up), change to a small number instead.
lock acceleration to MAX(SHIP:AVAILABLETHRUST / SHIP:MASS, 0.001). 
local burnTime is NEXTNODE:DELTAV:MAG / acceleration.
printLine("  Will burn for " + round(burnTime) + " seconds.").
local halfBurnTime is burnTime / 2.

lock warpTime to NEXTNODE:ETA - halfBurnTime.
printLine("  Warping " + round(warpTime) + " seconds.").
if warpTime > 36000 { // 10 hours
	printLine("    Warping speed 6").
	set WARP to 7.
	wait warpTime - 36000. 
}
if warpTime > 7200 { // 120 mins
	printLine("    Warping speed 6").
	set WARP to 6.
	wait warpTime - 7200. 
}
if warpTime > 1800 {  // 30 mins
	printLine("    Warping speed 5").
	set WARP to 5.
	wait warpTime - 1800.
	set warpTime to NEXTNODE:ETA - halfBurnTime.
}
if warpTime > 600 { 
	printLine("    Warping speed 4").
	set WARP to 4.
	wait warpTime - (600 / 2).
	set warpTime to NEXTNODE:ETA - halfBurnTime.
}
if warpTime > 120 {
	printLine("    Warping speed 3").
	set WARP to 3.
	wait warpTime - (120 / 2).
	set warpTime to NEXTNODE:ETA - halfBurnTime.
}
if (warpTime > 0) {
	set WARP to 1.
	printLine("    Warping speed 1").
	wait warpTime - 10.
	printLine("    Warping speed 0").
	set WARP to 0.
	set warpTime to NEXTNODE:ETA - halfBurnTime.
	wait warpTime.
}
if WARP > 0 {
	printLine("    Warping speed 0").
	set WARP to 0.
}

//executeBurn(NEXTNODE:DELTAV:MAG).

printLine("Starting burn...").

lock facingError to VANG(SHIP:FACING:FOREVECTOR, NEXTNODE:BURNVECTOR).
lock safeThrottle to 1 - sqrt(facingError / maxFacingDeviation). // Full stop at an error of maxFacingDeviation.
		
if (burnTime > 1) {
	lock THROTTLE to 1.0.
} else {
	lock THROTTLE to 0.1.
}
lock stageDeltaV to SHIP:STAGEDELTAV(SHIP:STAGENUM):CURRENT.
until stageDeltaV > NEXTNODE:DELTAV:MAG {
	printLine("  Will have to stage mid-burn.").
	set stageBurnTime to stageDeltaV / acceleration.
	until stageDeltaV <= 0 {
		lock throttle to safeThrottle.
	}
	printLine("  Staging.").
	stage.
	wait until STAGE:READY.
	printLine("    done").
	set burnTime to burnTime - stageBurnTime.
}
until NEXTNODE:DELTAV:MAG < maxFinalDeviation {
	local newThrottle is safeThrottle.
	if NEXTNODE:DELTAV:MAG / acceleration < 1.5 { // last 1.5 seconds of burn
		set newThrottle to newThrottle * 0.2.
	}
	lock throttle to newThrottle.
}
lock THROTTLE to 0.

unlock THROTTLE.
printLine("Burn complete.").

unlock STEERING.
remove NEXTNODE.
SAS on.