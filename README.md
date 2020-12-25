<h2>Overview</h2>
This is a Raspberry Pi 4 compatible Ubuntu 18.04.4 preinstalled desktop/server for the new (and currently unsupported officially in the 18.04 LTS series) Raspberry Pi 4.<br>
<br>
For more information visit https://jamesachambers.com/raspberry-pi-4-ubuntu-server-desktop-18-04-3-image-unofficial/ including a walkthrough and lots of comments / discussion.<br>
<br>
The early official 19.10 release seems to be having a lot of issues particularly with USB devices (I couldn't get my USB devices to connect to it either during initial testing).  I also saw a lot of warnings in the log files especially with a full desktop installed.  I personally am not concerned about these early hardware issues and I expect those to improve quickly but be advised just because it's an official release doesn't mean it's rock solid stable yet!<br>
<br>
This unofficial Ubuntu image is a compilation of all the latest knowledge/firmware/fixes for running a 64 bit operating system on the new Raspberry Pi 4.  If you find problems report it in the issues section and I and others will assist!<br>
<br>
If you are looking to USB boot Ubuntu 20.04 / 20.10 I have released a tool to assist with creating USB bootable Ubuntu images.  Check it out at https://jamesachambers.com/raspberry-pi-4-ubuntu-20-04-usb-mass-storage-boot-guide/<br>
<br>
<h2>Highlights</h2>
<ul>
    <li>Fully 64-bit kernel and userspace environment</li>
    <li>Updates normally via apt dist-upgrade from the official Ubuntu repositories</li>
    <li>Raspberry Pi userland utilities included (vcgencmd, dtoverlay, etc.)</li>
    <li>raspi-config utility included (good for enabling I2C, SPI, etc.)</li>
    <li>Uses the official 4.19.y Raspbian linux kernel built with arm64 flags</li>
    <li>Firmware updates from the Raspbian image and the RPi-Distro/firmware-nonfree repository</li>
    <li>3D video hardware acceleration support via vc4-fkms-v3d stack.  Videos / games are giving very high and smooth FPS.</li>
    <li>Includes kernel headers and the full kernel source tree used to build a kernel with your own custom flags (/usr/src/ directory)</li>
    <li>Can build out-of-tree and DKMS modules</li>
    <li>Full desktop support available via apt install kubuntu-desktop, xubuntu-desktop, xfce4, mate-desktop-environment, etc.)</li>
    <li>5 GHz WiFi channel support</li>
    <li>Working Bluetooth and WiFi</li>
    <li>KVM virtualization support</li>
    <li>Update script provided to update kernels/firmware/modules</li>
</ul>

<h2>Getting Updates</h2>
First and foremost all of your updates will be coming from Ubuntu directly in apt as it would with any official image.  The only things set on package hold (using apt-mark hold flash-kernel linux-raspi2 linux-image-raspi2 linux-headers-raspi2 linux-firmware-raspi2) to prevent them from overwriting the firmware already on the image.  <br>
<br>
If you wish, you may apt-mark unhold those same packages and you will be 100% official Ubuntu.  The firmware is old right now so you will probably have issues, but presumably at some point the firmware will be backported for 18.04.4 and they'll be safe to use on the Pi 4 but it may take some time.<br>
<br>
Updates to the firmware and fixes to common problems will be provided as long as there is interest.<br>
<br>
I have also included an updater that will give you the latest kernel/firmware/modules/fixes that are included in each release.
If Ubuntu's 18.04.4 update servers get working firmware for the Raspberry Pi 4 I will change the update script to remove the apt-mark holds on the Raspberry Pi firmware package in apt and close the project down (leaving this here for people to learn from to hack an unsupported device into their own distros, or until I do it again on the next Pi release!)<br>
<br>

<h2>Building Image Yourself</h2>
I have included both the script to create the image yourself (BuildPiKernel64bit.sh) using the official images as a base.  Binary releases are also available as a preinstalled image (available in the "Releases" section at the top of this page) that you can download and write to a SD card without building anything yourself.<br>
<br>
Note that the script is more of a process and not one that you can just clone and use.  Please read through it if you want to build the image as there are lines commented that you will want read if you are building from scratch.<br>
<br>
The idea is that with the build script and the kernel source code built directly into the IMG file (/usr/src/rpi-linux-*) you don't need me to personally update it for you and customize every kernel flag for you or even plan on me being around in the future.  The kernel is just the plain Raspbian 4.19.y kernel source built directly from Git (see build script).  You have all the tools you need to change kernel flags and recompile, build kernel modules, and really do anything that I can do now.  This whole page is a set of tools and a process to let you customize if you need to.<br>
<br>

<h2>Support</h2>
If you come across a problem definitely open a GitHub issue or drop by the jamesachambers.com page linked at the top.  I can add these issues as fixes and include them in the firmware/kernel updates provided through Updater.sh<br>
<br>
<h3>To download the prebuilt image go to the "Releases" section.</h3><br>
<br>

<h2>Update History</h2>

<h3>December 25th 2020 - BootFix.sh Fixes / Safety Checks</h3>
<ul>
    <li>Added -q (quiet) and -f (force) to zcat command to tell it to proceed if kernel is not in gzip format which can vary between 20.04 and 20.10</li>
    <li>Added safety check for BootFix.sh to make sure it's being ran as sudo</li>
    <li>Added safety check for BootFix.sh to check for system-boot and writable automounts</li>
</ul>

<h3>December 13th 2020 - BootFix.sh and README fixes</h3>
<ul>
    <li>Added safety check for BootFix.sh to make sure it's on Raspbian as it uses Raspbian's /boot folder as a source to patch Ubuntu 20.04 / 20.10 to be able to USB boot</li>
</ul>

<h3>December 5th 2020 - BootFix.sh and README fixes</h3>
<ul>
    <li>Fixed unescaped EOF in BootFix.sh</li>
    <li>Fixed wrong dates in README (thanks clodnut, <a href="https://github.com/TheRemote/Ubuntu-Server-raspi4-unofficial/issues/116">issue #116</a>)</li>
</ul>

<h3>December 4th 2020 - BootFix.sh Ubuntu 20.04 / 20.10 USB Boot Image Fixer Release</h3>
<ul>
    <li>Released BootFix.sh script that fixes an Ubuntu image created by the Raspberry Pi Imager Tool</li>
    <li>Compatible with Ubuntu 20.04 / 20.10 versions / supports both 32 bit and 64 bit and desktop and server variants</li>
    <li>See detailed guide at https://jamesachambers.com/raspberry-pi-4-ubuntu-20-04-usb-mass-storage-boot-guide/</li>
</ul>

<h3>February 24th 2020 - v28 Release</h3>
<ul>
<li>Updated source image to Ubuntu 18.04.4</li>
<li>Added xubuntu-desktop precompiled images</li>
<li>Updated to kernel 4.19.105 (addresses critical vulnerability)</li>
<li>Fixed flash-kernel package missing dtb files</li>
<li>Fixed issue that could cause ssh keys to not be created properly</li>
</ul>

<h3>January 20th 2020 - v27 Release</h3>
<ul>
<li>Updated to kernel 4.19.97</li>
<li>Updated to Ubuntu 19.10.1 for base firmware instead of 19.10</li>
<li>Updated Raspbian-sourced firmware</li>
</ul>

<h3>December 20th 2019 - v26 Release</h3>
<ul>
<li>Updated to kernel 4.19.89</li>
<li>Power management firmware features for WiFi are now enabled (saves 55mA (~270mW) of power on Pi 4)</li>
<li>Updated firmware</li>
</ul>

<h3>December 3rd 2019 - v25 Release</h3>
<ul>
<li>Fixed issue with desktop driver not loading properly (thanks tarsij!)</li>
<li>Added haveged back in to prevent slow boots due to low entropy</li>
<li>Updated kernel with a few V3D and other fixes</li>
</ul>

<h3>November 29th 2019 - v24 Release</h3>
<ul>
<li>Updated kernel to 4.19.86</li>
<li>Updated packages and firmware</li>
<li>This kernel has additional USB and V3D improvements</li>
</ul>

<h3>November 21st 2019 - v23 Release</h3>
<ul>
<li>Updated kernel to 4.19.84</li>
<li>Fixed problem that could cause desktop v22 release to not load</li>
<li>Fixed issues with video performance while in headless mode (xrdp, xvnc performance improvements)</li>
<li>Enabled AppArmor kernel flags</li>
<li>Added #dtparam=i2c0=on and #dtparam=i2c1=on examples to /boot/firmware/config.txt to help enable those interfaces if needed</li>
</ul>

<h3>November 17th 2019 - v22 Release</h3>
<ul>
<li>Updated kernel to 4.19.83</li>
<li>This kernel includes a number of fixes to USB and other drivers -- if you were having trouble with USB v22 is worth a try for you!</li>
<li>You can now force an update in the updater even if you are at the latest version.  You can use this if you think something may have gone wrong during an update or you are troubleshooting and want to reload the firmware/kernel modules.</li>
<li>Fixed issue where lightdm service (used by xubuntu-desktop) would not load properly</li>
<li>Added bootcode.bin to /boot/firmware to allow older Pis to boot the image (3B+ confirmed to work so far, others need testing)</li>
<li>Added README documentation to /boot/firmware/overlays folder for documentation inside dtoverlay command</li>
<li>Updated firmware</li>
</ul>

<h3>November 8th 2019 - v21 Release</h3>
<ul>
<li>Preinstalled Desktop binary (ubuntu-desktop) now available in the releases section</li>
<li>Netplan changes removed by popular demand -- it was causing too many issues as everyone is using the image differently</li>
<li>Updater now removes old kernel source code automatically (no more manual cleaning of these large folders needed)</li>
</ul>

<h3>November 7th 2019 - v20 Release</h3>
<ul>
<li>Fixed bug that was causing kernel modules to not load (updating using /home/Updater.sh recommended)</li>
</ul>

<h3>November 6th 2019 - v19 Release</h3>
<ul>
<li>Fixed PulseAudio only playing sound in mono, stereo now works!</li>
<li>Added kernel flags to optimize speed/clean up warnings/fix crashes</li>
<li>Moved most fixes to /etc/rc.local so they are applied after installing a *ubuntu-desktop package without waiting for the next update</li>
<li>Removed machine-id from the base image so that cloned images wouldn't all have a duplicate machine-id</li>
<li>Fixed audit service error</li>
<li>Fixed "spice-vdagent[2107]: Cannot access vdagent virtio channel /dev/virtio-ports/com.redhat.spice.0" error</li>
<li>Fixed triggerhappy crash related to /lib/systemd/system/triggerhappy.socket being wrong type</li>
</ul>

<h3>November 3rd 2019 - v18 Release</h3>
<ul>
<li>Update to kernel 4.19.81</li>
<li>Added udev rule to allow users to use vcgencmd without sudo (thanks xlazom00)</li>
<li>Fixed udev mounts not being visible (thanks wyuenho for the pull request)</li>
<li>Build script improvements now gets cross chain compiler / qemu user static 4.1 / related build dependencies</li>
<li>Build script now retrieves all dependencies for you on a blank Ubuntu 18.04.3 Virtual Machine (if you want to build)</li>
</ul>

<h3>November 1st 2019 - v17 Release</h3>
<ul>
<li>Fixed issue with CUPS preventing firmware modules from loading in xubuntu-desktop</li>
<li>Fixed unescaped EOF issue that was messing up fixes in /etc/rc.local (thanks meisenzahl for the pull request!)</li>
</ul>


<h3>October 31st 2019 - v16 Release</h3>
<ul>
<li>Updated Pi firmware (sound / video fixes, see https://github.com/Hexxeh/rpi-firmware/commit/c5736330216628b5ff8e3d17dde7cc03ce2126e6)</li>
<li>Updated Ubuntu-side firmware from updates included on the preinstalled 1910 release image</li>
<li>New 64 bit Raspberry Pi userland tools/libraries (vcgencmd) tools are now available -- they are being freshly built each version now in the build script!</li>
<li>Fixed issue where Pulse would not come back on after first reboot</li>
<li>Fixed netplan so startup isn't delayed by several minutes without an ethernet cable plugged in</li>
<li>Fixed several kernel flags related to sound/video</li>
<li>Fixed several issues with updater</li>
</ul>

<h3>October 28th 2019 - v15 Official Release</h3>
<ul>
<li>Script to update between releases is finally ready, and with that I am taking this out of pre-release!</li>
<li>To get the update script use the following commands:</li>
<br>
wget https://raw.githubusercontent.com/TheRemote/Ubuntu-Server-raspi4-unofficial/master/Updater.sh<br>
chmod +x Updater.sh<br>
sudo ./Updater.sh<br>
<br></li>
<li>You can update from any pre-release release version.  Please make a backup first!</li>
<li>The updater is located at /home/Updater.sh on v15 and up (to run type sudo bash /home/Updater.sh)</li>
</ul>

<h3>October 26th 2019 - v14 Desktop Pre-Release</h3>
<ul>
<li>Kernel source tree and headers are now included in the image!</li>
<li>The kernel build source tree is located at rpi-linux-"${KERNEL_VERSION}"</li>
<li>Ubuntu's first official release has come for the Pi 4 but it's 19.10 only which is not a LTS release and support ends for it in July 2020</li>
<li>DKMS module building tested</li>
<li>If you want custom kernel flags you can go to the /usr/src/rpi-linux folder and run make menuconfig (see BuildPiKernel64bit.sh for more info)</li>
<li>Rewrote build script to be more readable and reliable.  It's still a work in progress but I'm breaking things down into functions, etc.</li>
</ul>

<h3>October 23nd 2019 - v13 Desktop Pre-Release</h3>
<ul>
<li>raspi-config tool is now included with the image for (testing only, don't use on critical fully set up images).  You can use it to turn on i2c/spi/etc. File an issue if you find problems!</li>
<li>vcgencmd tool (and other libraspberrypi-userland packages) are now included (older build, works for essentials such as vcgencmd measure_temp, vcgencmd get_config int, vcgencmd get_throttled, etc)</li>
<li>Added 5Ghz WiFi band support (default regulatory domain US, change in /etc/default/crda if desired)</li>
<li>Updated kernel to 4.19.80</li>
<li>Fixed sound artifacts when playing YouTube/videos in browser</li>
<li>Fixed fsck errors during resize2fs operations</li>
</ul>

<h3>October 6th 2019 - v12 Desktop Pre-Release</h3>
<ul>
<li>Fixed Bluetooth not automatically attaching (now appears in both console and desktop mode)</li>
<li>Updated firmware using the latest from the Raspbian image</li>
</ul>

<h3>October 5th 2019 - v11 Desktop Pre-Release</h3>
<ul>
<li>Updated kernel to 4.19.76</li>
<li>Fixed several video driver issues including very low performance, YouTube videos in full screen freezing the Pi, low color resolution in xubuntu-desktop and graphical artifacts in kubuntu-desktop</li>
<li>Fixed bluetooth by adding missing firmware file not present in firmware-nonfree</li>
<li>Updated /boot/firmware/config.txt with useful HDMI debug flags -- uncomment some of these such as hdmi_safe if you are not getting display output</li>
<li>Added lines in config.txt to configure SPI and i2C -- you can uncomment these lines if you need to enable them</li>
<li>Updated WiFi firmware</li>
<li>Added missing regulatory.db files (used by WiFi) to /lib/firmware</li>
<li>Note for Kubuntu desktop: the compositor needs to be disabled for everything to draw correctly.  Use the shortcut Alt + Shift + F12 to disable the compositor and everything will draw normally.  Now go into the Settings app and go to the "Compositor" section and uncheck "Enable compositor at startup" to prevent it from turning back on when you reboot.</li>
</ul>

<h3>October 3rd 2019 - v10 Desktop Pre-Release</h3>
<ul>
<li>Fixed issue with wireless not showing in v9</li>
<li>Fixed bad symlink creation (pull request #38)</li>
</ul>

<h3>October 2nd 2019 - v9 Desktop Pre-Release</h3>
<ul>
<li>Updated kernel and modules to rpi-4.19.75</li>
<li>start*.elf and fixup*.dat files (GPU firmware) are now updated with each release</li>
<li>Kernel .config has been updated with the latest default config and Sakiki-'s conform_config.sh parameters</li>
<li>New conform_config_jamesachambers.sh script added to better keep track of kernel config changes</li>
<li>SPI is now enabled</li>
<li>CPU bandwidth provisioning for FAIR_GROUP_SCHED is now enabled (CONFIG_CFS_BANDWIDTH=y)</li>
<li>Additional Ceph kernel config parameters enabled (see conform_config_jamesachambers.sh for all params)</li>
<li>A lot of additional hardware support has been enabled via the official Raspberry Pi default kernel config params -- if you were having trouble with a device try v9</li>
<li>Cleaned up build script by adding additional needed dependencies to apt-get commands, broke up some sections and added additional comments</li>
</ul>

<h3>September 19th 2019 - v8 Desktop Pre-Release</h3>
<ul>
<li>Updated kernel to rpi-4.19.73</li>
<li>Added hosts entry to prevent slow sudo command</li>
<li>Added CONFIG_CGROUP_PIDS=y to .config file</li>
<li>Committed extras folder to repository</li>
<li>Added forcefsck file to run fsck on first boot</li>
<li>Reduced image size substantially by running fstrim on .img</li>
</ul>

<h3>September 8th 2019 - v7 Desktop Pre-Release</h3>
<ul>
<li>Updated kernel to rpi-4.19.71</li>
<li>Added CONFIG_BLK_DEV_RBD=y to kernel .config file to enable Ceph support</li>
</ul>

<h3>September 7th 2019 - v6 Desktop Pre-Release</h3>
<ul>
<li>Updated kernel to rpi-4.19.71</li>
<li>Integrated all available updates from apt into the base image</li>
<li>Fixed display driver issue -- if you are running v5 you can fix it by commenting out dtoverlay=vc4-fkms-v3d from /boot/config.txt</li>
<li>Enabled Ceph support in the kernel .config</li>
<li>Added build flags to kernel build line to build a more complete device tree (dtbo files)</li>
<li>Integrated all upstream updates since v5 from raspberrypi-linux and firmware-nonfree including a 3d driver fix for aarch64</li>
</ul>

<h3>September 3rd 2019 - v5 Desktop Pre-Release Test</h3>
<ul>
<li>Desktop support added</li>
<li>Expect lots of warnings in the logs.  If you find solutions to them please leave a comment -- many commits come from the comments!</li>
<li>Be advised -- installing can take quite a while on a Pi -- overnight or when you have something to do is a good time</li>
<li>Type one the following commands to install your preferred flavor of Ubuntu Desktop:</li>
<li>sudo apt-get install xubuntu-desktop # or</li>
<li>sudo apt-get install kubuntu-desktop</li>
</ul>

<h3>September 2nd 2019 - v4 Pre-Release Test</h3>
<ul>
<li>Recompiled kernel to include support for Ubuntu features that are not present in Raspbian</li>
<li>Enabled USB UAS support</li>
<li>Fixed video driver by modifying config.txt and compiling with 3D support</li>
<li>System now boots clean and loads all modules (sudo systemd status)</li>
</ul>

<h3>September 2nd 2019 - v3 Pre-Release Test</h3>
<ul>
<li>Fixed IPV6 and several other modules not loading</li>
</ul>

<h3>August 31st 2019 - v2 Pre-Release Test</h3>
<ul>
<li>Boot time reduced from 100s to around 30s</li>
<li>Messing with apt-mark or flash-kernel is no longer necessary and the fix has been built into the image</li>
<li>Fixed bluetooth firmware bug that was looking in /etc/firmware instead of /lib/firmware</li>
<li>Fixed entropy bug causing slow startup</li>
<li>Fixed mdadm.conf RAID warning</li>
<li>Module.symvars is now available in /boot/firmware/ if you need it to build kernel modules</li>
<li>If you need the whole source tree check out the accompanying build script in the repository. It's exactly how the source tree used to build the kernel is built.</li>
<li>Various other fixes (special thanks to Joan at jamesachambers.com for contributing so many)</li>
</ul>
