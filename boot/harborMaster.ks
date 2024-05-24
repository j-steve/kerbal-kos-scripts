@lazyGlobal OFF.

CD("0:").
RUNONCEPATH("common.ks").
RUNONCEPATH("dockUtils.ks").

until false {
    printLine("Monitoring for harbor traffic...").
    wait until not SHIP:MESSAGES:EMPTY.
    local message is SHIP:MESSAGES:POP.
    printLine("  Recieved message: " + message:CONTENT + " from " + message:SENDER).
    local messageParts is message:CONTENT:SPLIT("|").
    local startupData is startup().
    prepareDock(message:SENDER, messageParts[0], messageParts[1]).
    startupData:END().
}

function prepareDock {
    parameter dockingVessel, vesselPortCid, stationPortCid.
    local stationPort is findPartByUid(SHIP, stationPortCid).
    local shipPort is findPartByUid(dockingVessel, vesselPortCid).
    printLine("Preparing dock at port: " +  stationPort).
    stationPort:CONTROLFROM().
    printLine("Locked onto " +  shipPort + ", aligning & waiting for docking...").
    // lock dockingPortAlignment to VANG(stationPort:FACING:FOREVECTOR, shipPort:FACING:FOREVECTOR).
    lock dockingPortAlignment to VANG(stationPort:FACING:FOREVECTOR, shipPort:NODEPOSITION - stationPort:NODEPOSITION).
    //until abs(180 - dockingPortAlignment) < 1 {
    until abs(180 - dockingPortAlignment) < 0.05 {
        //lock STEERING to shipPort:NODEPOSITION.
        lock STEERING to -shipPort:FACING:FOREVECTOR.
        //clearVecDraws().
        local port2port is stationPort:POSITION - shipPort:POSITION.
        local node2node is stationPort:NODEPOSITION - shipPort:NODEPOSITION.
	    //vecdraw(stationPort:NODEPOSITION,  node2node * -1000, RGB(1, 0, 0), "node", 0.15, true).
	    //vecdraw(stationPort:POSITION,  port2port * -1000, RGB(1, 0, 1), "port", 0.15, true).
        printLine(dockingPortAlignment, true).
        wait 0.001.
    }
    unlock steering.
    // lock STEERING to -shipPort:PORTFACING:VECTOR.
    // local currentFacing is stationPort:FACING:FOREVECTOR.
    // lock STEERING to currentFacing.
    printLine("Waiting for docking...").
    wait until shipPort:PARTNER <> "None".
    printLine("Docking complete.").
    set portHighlight:ENABLED to false.
}

function findPartByUid {
    parameter _vessel, _uid.
    for _part in _vessel:PARTS {
        if _part:UID = _uid {
            return _part.
        }
    }
    printLine("ERROR: Failed to locate part uid=" + _uid + " on vessel " + _vessel:NAME).
}