
local commonDir is OPEN("0:/common").
for file in commonDir {
    if file:ISFILE and file:EXTENSION = "ks" and file:NAME <> "init.ks" {
        RUNONCEPATH("/common/" + file:NAME).
		COPYPATH("0:/common/" + file:NAME, "1:/common/" + file:NAME).
    }
}

// Switch back to the local volume to execute your scripts
SWITCH TO 1.