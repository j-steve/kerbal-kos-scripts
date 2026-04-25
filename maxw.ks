CLEARSCREEN.
LOCAL maxSpotted IS 0.

PRINT "Monitoring Angular Velocity...".
PRINT "Press ABORT (Backspace) to stop.".

UNTIL ABORT {
    LOCAL currentVel IS SHIP:ANGULARVEL:MAG.
    
    IF currentVel > maxSpotted {
        SET maxSpotted TO currentVel.
    }
    
    PRINT "Current: " + ROUND(currentVel, 4) + " rad/s" AT(0, 3).
    PRINT "Maximum: " + ROUND(maxSpotted, 4) + " rad/s" AT(0, 4).
    
    WAIT 0.
}