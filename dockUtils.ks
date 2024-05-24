// Functions shared by dock and harborMaster.

function listOpenDockingPorts {
    parameter _vessel is SHIP, portSize is -1.
    local dockingPorts is List().
    for _part in _vessel:DOCKINGPORTS {
        if _part:STATE = "Ready" and _part:TAG <> "nodock" {
            if portSize = -1 or _part:NODETYPE = portSize {
                dockingPorts:ADD(_part).
            }
        }
    }
    return dockingPorts.
}