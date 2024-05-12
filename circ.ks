run common.ks.

local apoapsisRadius is SHIP:ORBIT:APOAPSIS + BODY:RADIUS. // Assuming at current altitude
local txfrDeltaV is calcVisViva(apoapsisRadius, SHIP:ORBIT:SEMIMAJORAXIS, apoapsisRadius, apoapsisRadius).
add node(TimeSpan(SHIP:OBT:ETA:APOAPSIS), 0, 0, txfrDeltaV).
run mnode.ks.

printLine("Orbit circularized at " + round(SHIP:ORBIT:APOAPSIS / 1000) + " km").
