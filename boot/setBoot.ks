parameter bootFile is "boot/openConsole.ks".

DELETEPATH("1:" + bootFile).
LOG "RUNPATH(" + CHAR(34) + "0:" + bootFile + CHAR(34) + ")." TO ("1:" + bootFile).
SET core:bootfilename to bootFile.
print "Set boot path to " + CHAR(34) + bootFile + CHAR(34).
