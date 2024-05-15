RUNONCEPATH("common.ks").

alignRetrograde().

print "Warping to atmo...".
set WARP to 4.
wait until SHIP:ALTITUDE < SHIP:BODY:ATM:HEIGHT + 10000.

until SHIP:OBT:APOAPSIS <= SHIP:BODY:ATM:HEIGHT {
	
	print "Aerobraking...".
	set WARP to 0.
	wait until SHIP:ALTITUDE < SHIP:BODY:ATM:HEIGHT - 1000.
	
	set WARPMODE to "PHYSICS".
	set WARP to 4.
	wait until SHIP:ALTITUDE > SHIP:BODY:ATM:HEIGHT + 1000 or SHIP:OBT:APOAPSIS <= SHIP:BODY:ATM:HEIGHT.
	
	print "Warping to atmo...".
	set WARPMODE to "RAILS".
	set WARP to 5.
	wait until SHIP:ALTITUDE < SHIP:BODY:ATM:HEIGHT + 1000.
}

print "Complete...good luck!  Don't forget your chute!".