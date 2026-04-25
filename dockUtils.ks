// -------------------------------------------------------------------------------------------------
// This program contains functions shared by `dock.ks` and `harborMaster.ks`,
// but still specific to docking (so not a good candidate for `common.ks`).
// -------------------------------------------------------------------------------------------------
RUNONCEPATH("/common/init.ks").

function listOpenDockingPorts {
    parameter _vessel is SHIP, portSize is -1.

    local dockingPorts is List().
    for _part in _vessel:DOCKINGPORTS {

		if _part:state = "Disabled" and _part:hasmodule("ModuleAnimateGeneric") {
			local _dockmodule is _part:getmodule("ModuleAnimateGeneric").
			if _dockmodule:hasevent("open shield") {
				_dockmodule:doevent("open shield").
				printLine("Opening docking port shield.").
				set _deadline to time:seconds + 10.
				wait until _part:state = "Ready" or time:seconds > _deadline.
			}
		}
        if _part:STATE = "Ready" and _part:TAG <> "nodock" {
            if portSize = -1 or _part:NODETYPE = portSize {
                dockingPorts:ADD(_part).
            }
        }
    }
    return dockingPorts.
}