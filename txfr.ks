run common.ks.
//print getPhaseAngle().
//print calcPhaseAngle().
local semiMajorAxis is calcSemiMajorAxis(SHIP:ORBIT:APOAPSIS + BODY:RADIUS, MUN:ORBIT:APOAPSIS + BODY:RADIUS).
printLine(semiMajorAxis).
printLine(calcOrbitPeriod(semiMajorAxis, KERBIN)).
printLine(".").
printLine(".").
printLine(calcSemiMajorAxis(SHIP:ORBIT:APOAPSIS, SHIP:ORBIT:PERIAPSIS)).
printLine(calcSemiMajorAxis(SHIP:ORBIT:APOAPSIS, SHIP:ORBIT:PERIAPSIS) + KERBIN:RADIUS).
printLine(calcOrbitPeriod(ship:orbit:semiMajorAxis, KERBIN)).

//stage.
//wait until SHIP:VELOCITY:ORBIT:MAG >= 100.

function getPhaseAngle {
    local munPos is mun:position - kerbin:position.
    local shipPos is ship:position - kerbin:position.
    local phaseAngle is vang(shipPos, munPos).
    if vdot(vcrs(shipPos, munPos), kerbin:position:normalized) < 0 {
        set phaseAngle to 360 - phaseAngle.
    }
    return phaseAngle.
}

function calcPhaseAngle {
	set x to 10.
	return 180 - x.
}

function calcOrbitPeriod {
	parameter semiMajorAxis, soiBody.
	return 2 * CONSTANT:PI * SQRT(semiMajorAxis ^ 3 / soiBody:MU).
}