#!/bin/sh

if [ "$(/usr/bin/sed -n 's/.*startseat=\([^ ]*\).*/\1/p' /proc/cmdline)" = "true" ]; then
	/usr/bin/sed -i "s/EnableNesting *= *.*/EnableNesting=true/" /etc/sddm.conf
else
	/usr/bin/sed -i "s/EnableNesting *= *.*/EnableNesting=false/" /etc/sddm.conf
fi

if [ "$(/usr/bin/sed -n "s/EnableNesting *= *\(.*\)$/\1/p" /etc/sddm.conf)" = "true" ]; then
	/usr/bin/xinit /usr/bin/sddm -- :0 vt1
else
	/usr/bin/sddm
fi
