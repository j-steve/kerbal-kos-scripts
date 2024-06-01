// // Create a GUI window
// LOCAL my_gui IS GUI(200).
// // Add widgets to the GUI
// LOCAL label IS my_gui:ADDLABEL("Hello world!").
// SET label:STYLE:ALIGN TO "CENTER".
// SET label:STYLE:HSTRETCH TO True. // Fill horizontally
// LOCAL ok TO my_gui:ADDBUTTON("OK").
// // Show the GUI.
// my_gui:SHOW().
// // Handle GUI widget interactions.
// //
// // This is the technique known as "callbacks" - instead
// // of actively looking again and again to see if a button was
// // pressed, the script just tells kOS that it should call a
// // delegate function when it notices the button has done
// // something, and then the program passively waits for that
// // to happen:
// LOCAL isDone IS FALSE.
// function myClickChecker {
//   SET isDone TO TRUE.
// }
// SET ok:ONCLICK TO myClickChecker@. // This could also be an anonymous function instead.
// wait until isDone.

// print "OK pressed.  Now closing demo.".
// // Hide when done (will also hide if power lost).
// my_gui:HIDE().

CLEARGUIS().
local my_gui is GUI(200).

my_gui:ADDLABEL(SHIP:NAME).
setupButton("retrograde").
setupButton("srfretrograde").
setupButton("target").
setupButton("antitarget").
setupButton("up").
setupButton("unlock").
SET btnClose TO my_gui:ADDBUTTON("x").

my_gui:SHOW().

WAIT UNTIL btnClose:TAKEPRESS.
exitGui().

function setupButton {
    parameter _steeringLock.
    local lockSteeringFunc is lockSteering@.
    local _button is my_gui:ADDBUTTON(_steeringLock).
    set _button:TOGGLE to true.
    set _button:EXCLUSIVE to true.
    set _button:ONCLICK to lockSteeringFunc:BIND(_steeringLock).
}

function lockSteering {
    parameter _steeringLock.
    if _steeringLock = "retrograde" {
        lock STEERING to RETROGRADE.
        SAS OFF.
    } else if _steeringLock = "srfretrograde" {
        lock STEERING to SRFRETROGRADE.
        SAS OFF.
    }  else if _steeringLock = "target" {
        lock STEERING to TARGET:POSITION.
        SAS OFF.
    } else if _steeringLock = "antitarget" {
        lock STEERING to TARGET:POSITION.
        SAS OFF.
    } else if _steeringLock = "up" {
        lock STEERING to UP.
        SAS OFF.
    } else if _steeringLock = "unlock" {
        unlock STEERING.
        SAS ON.
    } else {
        print "ERROR: Unknown steering lock value: " + _steeringLock.
        exitGui().
    } 
}

function exitGui {
    unlock STEERING.
    my_gui:HIDE().
}