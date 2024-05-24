RUNONCEPATH("common.ks").
RUNONCEPATH("dockUtils.ks").

parameter _target is VESSEL("Station II").


local startupData is startup("Docking to " + _target:NAME + "...").
dock().
startupData:END().

function dock {
    // local harborMasters is _target:PARTSTAGGED("HarborMaster").
    // if harborMasters:LENGTH() = 0 {
    //     //local harborMaster is harborMasters[0]:GETMODULE("kOSProcessor").
    //     _target:CONNECTION:SENDMESSAGE("Sup dawn").
    // }
    local myPort is findShipDockingPort().
    local stationPorts is listOpenDockingPorts(_target, myPort:NODETYPE).
    if stationPorts:LENGTH = 0 {
        printLine("ERROR: no compatible docking ports on station!").
        return.
    }
    _target:CONNECTION:SENDMESSAGE(myPort:UID + "|" + stationPorts[0]:UID).
    local portHighlight is HIGHLIGHT(myPort, BLUE).
    local stationHighlight is HIGHLIGHT(stationPorts[0], BLUE).
    myPort:CONTROLFROM().
    if kuniverse:activevessel = SHIP {
        set TARGET to stationPorts[0].
    }
    //lock dockingPortAlignment to VANG(stationPorts[0]:FACING:FOREVECTOR, myPort:FACING:FOREVECTOR).
    lock dockingPortAlignment to VANG(myPort:FACING:FOREVECTOR, stationPorts[0]:NODEPOSITION - myPort:NODEPOSITION).
    until abs(180 - dockingPortAlignment) <= 0.05 {
        lock STEERING to stationPorts[0]:NODEPOSITION.
        printLine("Alignment: " + round(180 - dockingPortAlignment, 3), true).
        // clearvecdraws().
        // local port2port is myPort:POSITION - stationPorts[0]:POSITION.
        // local node2node is myPort:NODEPOSITION - stationPorts[0]:NODEPOSITION.
	    // //vecdraw(myPort:POSITION,  port2port:NORMALIZED * -10000000, RGB(0, 1, 0), "port", 0.15, true).
	    // //vecdraw(myPort:NODEPOSITION,  node2node:NORMALIZED * -10000000, RGB(0, 0, 1), "node", 0.15, true).
        // vecdraw(myPort:POSITION, myPort:portfacing:forevector * 1000000, RGB(0, 0, 1), "fore", 0.15, true).
        // vecdraw(myPort:POSITION, myPort:portfacing:topvector * 1000000, RGB(0, 1, 0), "top", 0.15, true).
        // vecdraw(myPort:POSITION, myPort:portfacing:upvector * 1000000, RGB(1, 0, 0), "up", 0.15, true).
        wait 0.1.
    }
    set warp to 2.
    wait 2.
    set warp to 0.

    // lock dockingPortAlignment to VANG(stationPorts[0]:FACING:FOREVECTOR, myPort:FACING:FOREVECTOR).
    // until abs(180 - dockingPortAlignment) < 1 {
    //     lock STEERING to stationPorts[0]:NODEPOSITION.
    //     printLine(dockingPortAlignment, true).
    // }
    // local currentFacing is myPort:FACING:FOREVECTOR.
    // lock STEERING to currentFacing.
    printLine("Locked on, waiting for docking...").
    lock THROTTLE to 0.05.
    wait 0.5.
    lock THROTTLE to 0.
    lock STEERING To -stationPorts[0]:PORTFACING:VECTOR.
    until myPort:PARTNER <> "None" {
        local dockDist is (myPort:NODEPOSITION - stationPorts[0]:NODEPOSITION):MAG.
        printLine(round(dockingPortAlignment, 2) + "° | Distance: " + round(dockDist, 1), true).
    }
    set portHighlight:ENABLED to false.
    set stationHighlight:ENABLED to false.
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