print "Executing next maneuver node.".
print "".

// Align header.
print "Aligning header...".
set WARP to 0.
SAS off.
lock STEERING to NEXTNODE:BURNVECTOR.
wait until VANG(SHIP:FACING:FOREVECTOR, NEXTNODE:BURNVECTOR) < 0.05.

// Pre-stage, if needed
until SHIP:AVAILABLETHRUST > 0 {
	print "No thrust, staging.".
	stage.
	wait 5. // Wait for new values so acceleration is updated for next stage.
}

// Calculate burn time.
print "Aligned, warping to node start...".
lock acceleration to SHIP:AVAILABLETHRUST / SHIP:MASS.
local burnTime is NEXTNODE:DELTAV:MAG / acceleration.
print "  Will burn for " + round(burnTime) + " seconds.".
local halfBurnTime is burnTime / 2.

lock warpTime to NEXTNODE:ETA - halfBurnTime.
print "  Warping " + round(warpTime) + " seconds.".
if warpTime > 7200 { // 120 mins
	print "    Warping speed 6".
	set WARP to 6.
	wait warpTime - 7200. 
}
if warpTime > 1800 {  // 30 mins
	print "    Warping speed 5".
	set WARP to 5.
	wait warpTime - 1800.
	set warpTime to NEXTNODE:ETA - halfBurnTime.
}
if warpTime > 600 { 
	print "    Warping speed 4".
	set WARP to 4.
	wait warpTime - (600 / 2).
	set warpTime to NEXTNODE:ETA - halfBurnTime.
}
if warpTime > 120 {
	print "    Warping speed 3".
	set WARP to 3.
	wait warpTime - (120 / 2).
	set warpTime to NEXTNODE:ETA - halfBurnTime.
}
if (warpTime > 0) {
	set WARP to 1.
	print "    Warping speed 1".
	wait warpTime - 10.
	set WARP to 0.
	set warpTime to NEXTNODE:ETA - halfBurnTime.
	wait warpTime.
}

//executeBurn(NEXTNODE:DELTAV:MAG).

print "Starting burn...".
if (burnTime > 1) {
	lock THROTTLE to 1.0.
} else {
	lock THROTTLE to 0.1.
}
lock stageDeltaV to SHIP:STAGEDELTAV(SHIP:STAGENUM):CURRENT.
until stageDeltaV > NEXTNODE:DELTAV:MAG {
	print "Insufficient thrust in this stage, will have to stage mid-burn.".
	set stageBurnTime to stageDeltaV / acceleration.
	until stageDeltaV <= 0 {
		if VANG(SHIP:FACING:FOREVECTOR, NEXTNODE:BURNVECTOR) > 0.05 {
			lock THROTTLE to 0.
		} else if NEXTNODE:DELTAV:MAG / acceleration > 2 {
			lock THROTTLE to 1.
		}
	}
	print "Staging.".
	stage.
	wait 10. // Wait for new values so acceleration is updated for next stage.
	print "  done".
	set burnTime to burnTime - stageBurnTime.
}
until NEXTNODE:DELTAV:MAG < 0.1 {
	if VANG(SHIP:FACING:FOREVECTOR, NEXTNODE:BURNVECTOR) > 0.05 {
		lock THROTTLE to 0.
	} else if NEXTNODE:DELTAV:MAG / acceleration > 2 {
		lock THROTTLE to 1.
	} else if NEXTNODE:DELTAV:MAG > 0.1 {
		lock THROTTLE to 0.1.
	} 
}
lock THROTTLE to 0.

unlock THROTTLE.
print "Burn complete.".

unlock STEERING.
remove NEXTNODE.
SAS on.