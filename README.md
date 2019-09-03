This is an initial testing pre-release of a unofficial build of Ubuntu Server 18.04.3 preinstalled server for the new (and currently unsupported officially) Raspberry Pi 4.<br>
<br>
I have included both the script to create it yourself from the official images as a base as well as a precompiled image that you can download and simply write straight to your SD card.  The included script makes the process of modifying the current official release to work on the Raspberry Pi 4 much easier.<br>
<br>
For more information visit https://jamesachambers.com/raspberry-pi-4-ubuntu-server-desktop-18-04-3-image-unofficial/ or including a walkthrough and lots of comments / discussion.<br>
<br>
All 4 GB of RAM are available in this preinstalled image.  WiFi, Bluetooth, and other drivers have been updated for the Raspberry Pi 4.<br>
<br>
This will hold the package so it doesn't break your installation while letting you fully update everything else until official support is released.<br>
<br>
To download the prebuilt image go to the "Releases" section to get the download.<br>
<br>
September 3rd 2019 - v5 Desktop Pre-Release Test<br>
-Desktop support added<br>
-Expect lots of warnings in the logs.  If you find solutions to them please leave a comment -- many commits come from the comments!<br>
-Be advised -- installing can take quite a while on a Pi -- overnight or when you have something to do is a good time<br>
-Type one the following commands to install your preferred flavor of Ubuntu Desktop:<br>
sudo apt-get install xubuntu-desktop # or<br>
sudo apt-get install kubuntu-desktop<br>
<br>
September 2nd 2019 - v4 Pre-Release Test<br>
-Recompiled kernel to include support for Ubuntu features that are not present in Raspbian<br>
-Enabled USB UAS support<br>
-Fixed video driver by modifying config.txt and compiling with 3D support<br>
-System now boots clean and loads all modules (sudo systemd status)<br>
<br>
September 2nd 2019 - v3 Pre-Release Test<br>
-Fixed IPV6 and several other modules not loading<br>
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
