// -------------------------------------------------------------------------------------------------
// Assuming the active ship is stopped (relative motion ~0) within ~1km of near another target ship, 
// this script will align their docking ports and bring them together to dock.
// The other ship must be running `boot/harborMaster.ks`.
// -------------------------------------------------------------------------------------------------

RUNONCEPATH("common.ks").
RUNONCEPATH("dockUtils.ks").

parameter _target is TARGET.
if _target:ISTYPE("Part") {set _target to _target:SHIP.}
parameter enableRcsLastMile is -1.
if enableRcsLastMile = -1 {
    list RCS in myRcsParts.
    set enableRcsLastMile to myRcsParts:LENGTH > 0.
}


local startupData is startup("Docking to " + _target:NAME + "...").
dock().
startupData:END().

function dock {
    local myPort is findShipDockingPort().
    local stationPort is findTargetDockingPort(_target, myPort:NODETYPE).
    local portHighlight is HIGHLIGHT(myPort, BLUE).
    local stationHighlight is HIGHLIGHT(stationPort, BLUE).
    printLine("Best port: " + myPort:NAME + " (" + myPort:NODETYPE + ")").

    // Point at station.
    _warpFreeze(). // Ensure there's no initial motion in ship/station.
    lock STEERING to _target:POSITION.
    wait until VANG(myPort:FACING:FOREVECTOR, _target:POSITION) < 1.
    lock steering to "kill".
    wait 1.
    _warpFreeze(). // Freeze the ship.

    _target:CONNECTION:SENDMESSAGE(myPort:UID + "|" + stationPort:UID).
    myPort:CONTROLFROM().
    if kuniverse:activevessel = SHIP {
        set TARGET to stationPort.
    }

    printLine("Waiting for station rotation...").
    wait until not SHIP:MESSAGES:EMPTY.
    until SHIP:MESSAGES:EMPTY {SHIP:MESSAGES:POP.}
    printLine("  done").

    _warpFreeze(). // Freeze the station.

    //lock dockingPortAlignment to VANG(stationPort:FACING:FOREVECTOR, myPort:FACING:FOREVECTOR).
    lock dockingPortAlignment to VANG(myPort:FACING:FOREVECTOR, stationPort:NODEPOSITION - myPort:NODEPOSITION).
    until abs(dockingPortAlignment) <= 0.05 {
        lock STEERING to stationPort:NODEPOSITION.
        printLine("Alignment: " + round(180 - dockingPortAlignment, 3), true).
        // clearvecdraws().
        // local port2port is myPort:POSITION - stationPort:POSITION.
        // local node2node is myPort:NODEPOSITION - stationPort:NODEPOSITION.
	    // //vecdraw(myPort:POSITION,  port2port:NORMALIZED * -10000000, RGB(0, 1, 0), "port", 0.15, true).
	    // //vecdraw(myPort:NODEPOSITION,  node2node:NORMALIZED * -10000000, RGB(0, 0, 1), "node", 0.15, true).
        // vecdraw(myPort:POSITION, myPort:portfacing:forevector * 1000000, RGB(0, 0, 1), "fore", 0.15, true).
        // vecdraw(myPort:POSITION, myPort:portfacing:topvector * 1000000, RGB(0, 1, 0), "top", 0.15, true).
        // vecdraw(myPort:POSITION, myPort:portfacing:upvector * 1000000, RGB(1, 0, 0), "up", 0.15, true).
        wait 0.1.
    }
    _warpFreeze().  // Freeze the ship.

    // lock dockingPortAlignment to VANG(stationPort:FACING:FOREVECTOR, myPort:FACING:FOREVECTOR).
    // until abs(180 - dockingPortAlignment) < 1 {
    //     lock STEERING to stationPort:NODEPOSITION.
    //     printLine(dockingPortAlignment, true).
    // }
    // local currentFacing is myPort:FACING:FOREVECTOR.
    // lock STEERING to currentFacing.
    printLine("Hiting throttle, throttling up...").
    lock THROTTLE to 0.005.
    wait until (SHIP:VELOCITY:ORBIT - _target:VELOCITY:ORBIT):MAG > 0.2.
    lock THROTTLE to 0.
    
    printLine("Waiting for docking...").
    lock STEERING to "kill".
	set WARPMODE to "PHYSICS".
	set WARP to 4.
    wait until (myPort:NODEPOSITION - stationPort:NODEPOSITION):MAG < 15.
	set WARP to 0.
    
    if enableRcsLastMile {
        RCS on.
        set SHIP:CONTROL:FORE to -0.25.
        wait until (SHIP:VELOCITY:ORBIT - _target:VELOCITY:ORBIT):MAG < 0.05 or myPort:PARTNER <> "None".
        set SHIP:CONTROL:FORE to 0.
        RCS off.

        if myPort:PARTNER = "None" {
            lock steering to stationPort:NODEPOSITION.
            wait 5.
            RCS on.
            set SHIP:CONTROL:FORE to 0.1.
            wait until (SHIP:VELOCITY:ORBIT - _target:VELOCITY:ORBIT):MAG > 0.1 or myPort:PARTNER <> "None".
            set SHIP:CONTROL:FORE to 0.
            RCS off.
        }
    } else {
        lock steering to stationPort:NODEPOSITION.
    }

    // until myPort:PARTNER <> "None" {
    //     local dockDist is (myPort:NODEPOSITION - stationPort:NODEPOSITION):MAG.
    //     printLine(round(dockingPortAlignment, 2) + "° | Distance: " + round(dockDist, 1), true).
    // }
    // lock steering to "kill".
    wait until myPort:STATE:CONTAINS("Docked").
    // TODO: If this doesn't work, instead of waiting for docking, wait to get within 50 m, then kill speed and align again, THEN dock.

    set portHighlight:ENABLED to false.
    set stationHighlight:ENABLED to false.
}

function findTargetDockingPort {
    parameter _target, _dockingPortSize.
    local targetPorts is listOpenDockingPorts(_target, _dockingPortSize).
    if targetPorts:LENGTH = 0 {
        printLine("ERROR: no compatible docking ports on station!").
        return.
    }
    // TODO: Check the port facings and find the one which is most closely facing the ship.
    return targetPorts[0].
}

function findShipDockingPort {
    // Find the docking port which is facing forward (or most closely so), as this will be easiest to dock with.
    local bestPort is -1.
    local bestFacingDeviation is -1.
    for dockingPort in listOpenDockingPorts() {
        local facingDeviation is VANG(SHIP:FACING:FOREVECTOR, dockingPort:PORTFACING:VECTOR).
        if bestFacingDeviation = -1 or facingDeviation < bestFacingDeviation {
            set bestFacingDeviation to facingDeviation.
            set bestPort to dockingPort.
        }
    }
    return bestPort.
}

// Warp for a sec to "freeze" momentum.
function _warpFreeze {
    SET warp to 2.
    wait 5.
    set warp to 0.
}