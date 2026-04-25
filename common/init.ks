// -------------------------------------------------------------------------------------------------
// This script initializes the shared library environment for all KOS scripts.
// -------------------------------------------------------------------------------------------------
@lazyGlobal OFF.

local commonDir is OPEN("/common").
for file in commonDir {
    if file:ISFILE and file:EXTENSION = "ks" and file:NAME <> "init.ks" {
        RUNONCEPATH("/common/" + file:NAME).
    }
}