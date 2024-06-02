// -------------------------------------------------------------------------------------------------
// This program contains functions shared by `dock.ks` and `harborMaster.ks`,
// but still specific to docking (so not a good candidate for `common.ks`).
// -------------------------------------------------------------------------------------------------

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