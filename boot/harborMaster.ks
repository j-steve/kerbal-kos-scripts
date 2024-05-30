@lazyGlobal OFF.

CD("0:").
RUNONCEPATH("common.ks").
RUNONCEPATH("dockUtils.ks").

until false {
    printLine("Monitoring for harbor traffic...").
    wait until not SHIP:MESSAGES:EMPTY.
    local message is SHIP:MESSAGES:POP.
    until SHIP:MESSAGES:EMPTY {set message to SHIP:MESSAGES:POP.}
    printLine("  Recieved message: " + message:CONTENT).
    printLine("    from " + message:SENDER:NAME).
    local messageParts is message:CONTENT:SPLIT("|").
    local startupData is startup().
	PANELS off.
    RCS off.
    prepareDock(message:SENDER, messageParts[0], messageParts[1]).
	PANELS on.
    startupData:END().
}

function prepareDock {
    parameter dockingVessel, vesselPortCid, stationPortCid.
    local stationPort is findPartByUid(SHIP, stationPortCid).
    local shipPort is findPartByUid(dockingVessel, vesselPortCid).
    printLine("Preparing dock.").
    stationPort:CONTROLFROM().
    printLine("Locked onto ship, aligning...").
    // lock dockingPortAlignment to VANG(stationPort:FACING:FOREVECTOR, shipPort:FACING:FOREVECTOR).
    lock dockingPortAlignment to VANG(stationPort:FACING:FOREVECTOR, shipPort:NODEPOSITION).
    //until abs(180 - dockingPortAlignment) < 1 {
    set SHIP:CONTROL:ROLL to 0.
        lock STEERING to shipPort:NODEPOSITION.
    until abs(dockingPortAlignment) < 2.5 {
        //lock STEERING to -shipPort:FACING:FOREVECTOR.
        //clearVecDraws().
        // local port2port is stationPort:POSITION - shipPort:POSITION.
        // local node2node is stationPort:NODEPOSITION - shipPort:NODEPOSITION.
	    //vecdraw(stationPort:NODEPOSITION,  node2node * -1000, RGB(1, 0, 0), "node", 0.15, true).
	    //vecdraw(stationPort:POSITION,  port2port * -1000, RGB(1, 0, 1), "port", 0.15, true).
        printLine(dockingPortAlignment, true).
        wait 0.001.
    }
    unlock steering.
    set SHIP:CONTROL:ROLL to 0.
    dockingVessel:CONNECTION:SENDMESSAGE("Aligned").
    // lock STEERING to -shipPort:PORTFACING:VECTOR.
    // local currentFacing is stationPort:FACING:FOREVECTOR.
    // lock STEERING to currentFacing.
    printLine("Waiting for docking...").
    wait until shipPort:PARTNER <> "None".
    printLine("Docking complete.").
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