## Nested Multi-Seat Session

This fork of [SDDM](https://github.com/sddm/sddm) allows to use a fork of the [xf86-video-nested](https://github.com/oiteam/xf86-video-nested) module to enable multi-seats using a single multi-head graphics card. Switching between multi-seat and ordinary operation will be done at boot time using a custom kernel parameter.

In its current state this approach requires several manual steps in order to make it work. They are explained in the following on the basis of an example configuration using two monitors (and keyboards and mice) including a "Desktop" seat and a "Couch" seat.

### Xorg configuration

For a nested session, there is one server Xorg instance running on `seat0`, using the actual hardware settings and one nested Xorg layer on top of the server instance for each physical seat.
For a reproducible setup, the monitor settings of the server configuration should be set manually:

#### /etc/X11/xorg.conf.d/80-screens.conf
```
Section "Monitor"
	Identifier	"Desktop"
EndSection

Section "Monitor"
	Identifier	"Couch"
	Option		"Position"	"1280 0"
	Option		"PreferredMode"	"1920x1080"
EndSection

Section "Screen"
	Identifier	"Desktop"
	Monitor		"Desktop"
	SubSection "Display"
		Depth	24
		Modes	"1280x1024"
	EndSubSection
EndSection

Section "Screen"
	Identifier	"Couch"
	Monitor		"Couch"
	SubSection "Display"
		Depth	24
		Modes	"1920x1080"
	EndSubSection
EndSection

Section "ServerLayout"
	Identifier	"L1"
	Screen		"Desktop"	0 0
	Screen		"Couch"		1280 0
	Option		"BlankTime"	"0"
	Option		"StandbyTime"	"0"
	Option		"SuspendTime"	"0"
	Option		"OffTime"	"0"
EndSection
```
Apparently the "Couch" monitor sits right of the "Desktop" monitor, defined by the `"Position"` option. This setup remains fixed, with or without multiple seats. The server instance is prevented from going into power saving mode, by setting the `"...Time"` options to `"0"`.

In this example, the monitor identifiers are assigned beforehand:

#### /etc/X11/xorg.conf.d/20-intel.conf
```
Section "Device"
   Identifier  "Intel Graphics"
   Driver      "intel"
   Option      "AccelMethod"  "sna"
   Option      "TearFree"    "true"
   Option      "DRI"    "3"
   Option      "Monitor-HDMI1" "Desktop"
   Option      "Monitor-HDMI3" "Couch"
EndSection
```

which except for the identifiers is specific for the available hardware.

At this point the configuration should be tested already to make sure resolutions and positions are set right.

So far, only monitor positions have been fixed. Now, seat configurations have to be defined, which can be adapted from the [xf86-video-nested README](https://github.com/oiteam/xf86-video-nested/blob/master/README):

#### /etc/X11/seat1.conf
```
Section "Module"
	Load		"shadow"
	Load		"fb"
EndSection

Section "Device"
	Identifier	"seat1"
	Driver		"nested"
EndSection

Section "Screen"
	Identifier	"Screen1"
	Device		"seat1"
	DefaultDepth	24
	SubSection "Display"
		Depth 24
		Modes "1920x1080"
	EndSubSection
	Option		"Origin"	"1280 0"
EndSection

Section "ServerLayout"
	Identifier	"Nested"
	Screen		"Screen1"
	Option		"AllowEmptyInput"	"true"
EndSection
```

#### /etc/X11/seat2.conf
```
Section "Module"
	Load		"shadow"
	Load		"fb"
EndSection

Section "Device"
	Identifier	"seat2"
	Driver		"nested"
EndSection

Section "Screen"
	Identifier	"Screen1"
	Device		"seat2"
	DefaultDepth	24
	SubSection "Display"
		Depth 24
		Modes "1280x1024"
	EndSubSection
	Option		"Origin"	"0 0"
EndSection

Section "ServerLayout"
	Identifier	"Nested"
	Screen		"Screen1"
	Option		"AllowEmptyInput"	"true"
EndSection
```

Both files only differ by their device identifiers and screen locations inside the provided server instance. The `"Module"` section is required for the xf86-video-nested module to work. The `"Server Layout"` identifier `"Nested"` is a hard coded value in SDDM for the Xorg `-layout` option.

The file names refer to the actual seat identifier and cannot be changed. The directory for these files may be adapted in the SDDM configuration however.

### udev Rules

Custom [udev rules](https://www.freedesktop.org/software/systemd/man/sd-login.html) are required to only create seats, if the appropriate kernel parameter is set. This is checked by evaluating `/proc/cmdline` using `sed`.

Devices which identify and are attached to a seat (such as keyboard, mouse and audio in the following) are listed using

`loginctl seat-status`

#### /etc/udev/rules.d/70-seat.rules
```
TAG+="seat", ATTR{name}=="Logitech K400 Plus", ENV{ID_SEAT}="seat1", TAG+="master-of-seat", PROGRAM="/usr/bin/sed -n 's/.*startseat=\([^ ]*\).*/\1/p' /proc/cmdline", RESULT=="true"

TAG+="seat", DEVPATH=="/devices/pci0000:00/0000:00:1f.3/sound/card0", ENV{ID_SEAT}="seat1", PROGRAM="/usr/bin/sed -n 's/.*startseat=\([^ ]*\).*/\1/p' /proc/cmdline", RESULT=="true"

TAG+="seat", ATTR{name}=="PS/2+USB Mouse", ENV{ID_SEAT}="seat2", TAG+="master-of-seat" PROGRAM="/usr/bin/sed -n 's/.*startseat=\([^ ]*\).*/\1/p' /proc/cmdline", RESULT=="true"

TAG+="seat", ATTR{name}=="NOVATEK USB Keyboard", ENV{ID_SEAT}="seat2" PROGRAM="/usr/bin/sed -n 's/.*startseat=\([^ ]*\).*/\1/p' /proc/cmdline", RESULT=="true"
```
### Setting up the Boot Loader

To set the kernel parameter `startseat=true` the boot loader configuration must be adapted.

For a systemd-boot setup a new configuration could be added, where `startseat=true` is added to the `options` key of a working configuration.

### Verify sddm.conf

The SDDM configuration file is not installed automatically. A standard configuration is obtained with

`sddm --example-config`

The following options must be present in the [X11] section:
- `EnableNesting=false`
- `SeatConfDir=/etc/X11`

where the path of the latter indicates the location of the seatX.conf files.

The `EnableNesting` option is altered automatically before SDDM is started, depending on whether `startseat=true` or not, which is done in /usr/bin/sddm-nest.

### Known Issues

- It is not possible to switch to a terminal using Ctrl+Alt+F1. If starting the display manager fails, a hardware reset might be required.
- The nested module tries several times to start a nested layer. In rare cases the number of tries might not be sufficient.
