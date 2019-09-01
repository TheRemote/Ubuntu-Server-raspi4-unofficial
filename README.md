This is an initial testing pre-release of a unofficial build of Ubuntu Server 18.04.3 preinstalled server for the new (and currently unsupported officially) Raspberry Pi 4.<br>
<br>
I have included both the script to create it yourself from the official images as a base as well as a precompiled image that you can download and simply write straight to your SD card.  The included script makes the process of modifying the current official release to work on the Raspberry Pi 4 much easier.<br>
<br>
For more information visit https://jamesachambers.com/raspberry-pi-ubuntu-server-18-04-2-installation-guide/ including lots of comments and discussion.<br>
<br>
All 4 GB of RAM are available in this preinstalled image.  WiFi, Bluetooth, and other drivers have been updated for the Raspberry Pi 4.<br>
<br>
This will hold the package so it doesn't break your installation while letting you fully update everything else until official support is released.<br>
<br>
To download the prebuilt image go to the "Releases" section to get the download.<br>
<br>
August 31st 2019 - v2 Pre-Release Test<br>
-Boot time reduced from 100s to around 30s<br>
-Messing with apt-mark or flash-kernel is no longer necessary and the fix has been built into the image<br>
-Fixed bluetooth firmware bug that was looking in /etc/firmware instead of /lib/firmware<br>
-Fixed entropy bug causing slow startup<br>
-Fixed mdadm.conf RAID warning<br>
-Module.symvars is now available in /boot/firmware/ if you need it to build kernel modules<br>
-If you need the whole source tree check out the accompanying build script in the repository. It's exactly how the source tree used to build the kernel is built.<br>
-Various other fixes (special thanks to Joan at jamesachambers.com for contributing so many)<br>