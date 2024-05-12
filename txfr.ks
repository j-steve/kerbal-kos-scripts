run common.ks.
//print getPhaseAngle().
//print calcPhaseAngle().
local txfrSemiMajorAxis is calcSemiMajorAxis(SHIP:ORBIT:APOAPSIS + BODY:RADIUS, MUN:ORBIT:APOAPSIS + BODY:RADIUS).
local txfrOrbitPeriod is calcOrbitPeriod(txfrSemiMajorAxis).
local txfrTime is txfrOrbitPeriod / 2. // Only outbound trip is relevent, so split total period in half.
printLine(".").
printLine(".").
printLine(calcSemiMajorAxis(SHIP:ORBIT:APOAPSIS, SHIP:ORBIT:PERIAPSIS)).
printLine(calcSemiMajorAxis(SHIP:ORBIT:APOAPSIS, SHIP:ORBIT:PERIAPSIS) + KERBIN:RADIUS).
printLine(calcOrbitPeriod(ship:orbit:semiMajorAxis)).
printLine(".").
printLine("WAITTIME: " + waitTime()).
printLine("WAITTIME: " + (waitTime() / 365)).
printLine("WAITTIME: " + (waitTime() / 24 /  365)).
printLine("WAITTIME: " + (waitTime() / 60 / 24 /  365)).
printLine("WAITTIME: " + (waitTime() / 60 / 60 / 24 /  365)).

//stage.
//wait until SHIP:VELOCITY:ORBIT:MAG >= 100.


function calcOrbitPeriod {
	parameter semiMajorAxis.
	return 2 * CONSTANT:PI * SQRT(semiMajorAxis ^ 3 / BODY:MU).
}

function waitTime {
	local T_i is 60910.25. // days
	local T_f is 224.70. //  days
	local n_i is 2 * CONSTANT:PI / (T_i * 86400). // seconds.
	local n_f is 2 * CONSTANT:PI / (T_f * 86400). // seconds.
	// OK to this point at least.
	local r_i is 4.53239E9.
	local r_f is 1.08209E8.
	local a_t is (r_i + r_f) / 2.  // km
	// local t_12 is CONSTANT:PI / SQRT(BODY:MU) * a_t ^ (3/2).
	local t_12 is CONSTANT:PI / SQRT(1.32712 * 10 ^ 11) * a_t ^ (3/2).

	local gamma_1 is calcPhaseAngle(n_f, t_12).
	printLine("gamma_1:" + gamma_1).
	local gamma_2 is calcPhaseAngle(n_i, t_12).
	printLine("gamma_2:" + gamma_2).
    return (-2 * gamma_2 + 2 * CONSTANT:PI) / (n_f - n_i).
}

function calcPhaseAngle {
	parameter meanMotion1, meanMotion2.
	return MOD(CONSTANT:PI - meanMotion1 * meanMotion2, 2 * CONSTANT:PI).
}

function getPhaseAngle {
    local munPos is mun:position - kerbin:position.
    local shipPos is ship:position - kerbin:position.
    local phaseAngle is vang(shipPos, munPos).
    if vdot(vcrs(shipPos, munPos), kerbin:position:normalized) < 0 {
        set phaseAngle to 360 - phaseAngle.
    }
    return phaseAngle.
}