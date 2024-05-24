parameter bootFile is "boot/openConsole.ks".

DELETEPATH("1:boot/boot.ks").
LOG "RUNPATH(" + CHAR(34) + "0:" + bootFile + CHAR(34) + ")." TO "1:boot/boot.ks".
SET core:bootfilename to "boot/boot.ks".
print "Set boot path to " + CHAR(34) + bootFile + CHAR(34).
