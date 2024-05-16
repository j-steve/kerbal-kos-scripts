RUNONCEPATH("common.ks").


print "Warping to atmo...".
set WARP to 6.
wait until SHIP:ALTITUDE < SHIP:BODY:ATM:HEIGHT + 10000.
alignRetrograde().

until SHIP:OBT:APOAPSIS <= SHIP:BODY:ATM:HEIGHT {
	
	print "Aerobraking...".
	set WARP to 0.
	wait until SHIP:ALTITUDE < SHIP:BODY:ATM:HEIGHT - 500.
	
	set WARPMODE to "PHYSICS".
	set WARP to 4.
	wait until SHIP:ALTITUDE > SHIP:BODY:ATM:HEIGHT + 500 or SHIP:OBT:APOAPSIS <= SHIP:BODY:ATM:HEIGHT.
	
	print "Warping to atmo...".
	set WARPMODE to "RAILS".
	set WARP to 10.
	wait until SHIP:ALTITUDE < SHIP:BODY:ATM:HEIGHT + 500.
}

print "Complete...good luck!  Don't forget your chute!".