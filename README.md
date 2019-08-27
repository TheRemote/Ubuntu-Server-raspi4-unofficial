This is an initial testing pre-release of a unofficial build of Ubuntu Server 18.04.3 preinstalled server for the new (and currently unsupported officially) Raspberry Pi 4.  

I have included both the script to create it (a little rough, make sure your loop interface is created as the same index as me) but it does work and makes the process of modifying the current official release to work on the Raspberry Pi 4 very quickly.

For more information visit https://jamesachambers.com/raspberry-pi-ubuntu-server-18-04-2-installation-guide/ including lots of comments and discussion.

All 4 GB of RAM are available in this preinstalled image.  I also made sure the WiFi interface was updated with the correct bootflags3 for the Raspberry Pi 4.

IMPORTANT: before you run apt-get upgrade you need to freeze the firmware update package to prevent Ubuntu from trying to flash incompatible firmware.  Simply run this command after you log in the first time to disable it:

sudo apt-mark hold flash-kernel

This will hold the package so it doesn't break your installation while letting you fully update everything else until official support is released.
