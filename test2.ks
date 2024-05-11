
clearscreen.

print "Creating circularization node.".
local currentV is SHIP:ORBIT:VELOCITY:ORBIT:MAG. // Ideally this would be the projected velocity at apoapsis point instead.
local requiredV is calcRequiredVelocityAtApoapsis(75000).
local deltaV is requiredV - currentV.

// create maneuver node at apoapsis with the calculated deltaV as the prograde component
add node(TIME:SECONDS + ETA:APOAPSIS, deltaV, 0, 0).

//stage.
//wait until SHIP:VELOCITY:ORBIT:MAG >= 100.



// function to calculate required velocity at apoapsis to achieve desired periapsis
function calcRequiredVelocityAtApoapsis {
    parameter desiredPeriapsis. // desired periapsis altitude in meters

    local apoapsisRadius is ship:apoapsis + BODY:RADIUS. // radius at apoapsis
    local periapsisRadius is desiredPeriapsis + BODY:RADIUS. // desired radius at periapsis

    // calculate semi-major axis of the new orbit
    local semiMajorAxis is (apoapsisRadius + periapsisRadius) / 2.

    // use vis-viva equation to calculate the required velocity at apoapsis
    local visViva is sqrt(BODY:MU * (2 / apoapsisRadius - 1 / semiMajorAxis)).
    return visViva.
}