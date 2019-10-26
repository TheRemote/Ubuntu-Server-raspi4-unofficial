This is an initial testing pre-release of a unofficial build of Ubuntu Server 18.04.3 preinstalled server for the new (and currently unsupported officially) Raspberry Pi 4.<br>
<br>
For more information visit https://jamesachambers.com/raspberry-pi-4-ubuntu-server-desktop-18-04-3-image-unofficial/ including a walkthrough and lots of comments / discussion.<br>
<br>
Note: Ubuntu has released their first official distribution that supports the Raspberry Pi 4.  The bad news it it's only for the short term Ubuntu 19.10 Eoan Ermine release and *not* 
for the 18.04 LTS release that will still be supported until a whopping April 2023 still.  This means that for now this project will live on supporting the 18.04 LTS branch.<br>
<br>
The early official 19.10 release seems to be having a lot of issues particularly with USB devices (I couldn't get my USB devices to connect to it either during initial testing).  I also saw a lot of warnings in the log files especially with a full desktop installed.  I personally am not concerned about these early hardware issues and I expect those to improve quickly but be advised just because it's an official release doesn't mean it's rock solid stable yet!<br>
<br>
This unofficial Ubuntu image is a compilation of all the latest knowledge/firmware/fixes for running a 64 bit operating system on the new Raspberry Pi 4.  Here are some of the highlights:<br>
<ul>
    <li>Fully 64-bit kernel and userspace environment</li>
    <li>Updates normally via apt dist-upgrade from the official Ubuntu repositories</li>
    <li>Uses the official 4.19.y Raspbian linux kernel built with arm64 flags</li>
    <li>Firmware updates from the Raspbian image and the RPi-Distro/firmware-nonfree repository</li>
    <li>3D video hardware acceleration support via vc4-fkms-v3d stack.  Videos / games are giving very high and smooth FPS.</li>
    <li>Includes kernel headers and the full kernel source tree used to build a kernel with your own custom flags (/usr/src/ directory)</li>
    <li>Can build out-of-tree and DKMS modules.  Type apt-install hello-dkms to build a test DKMS module / get all the dependencies</li>
    <li>Full desktop support available via apt install kubuntu-desktop, xubuntu-desktop, xfce4, mate-desktop-environment, etc.)</li>
    <li>KVM virtualization support</li>
</ul>
<br>
I have included both the script to create the image yourself (BuildPiKernel64bit.sh) using the official images as a base.  Binary releases are also available as a preinstalled image (available in the "Releases" section at the top of this page) that you can download and write to a SD card without building anything yourself.  Note that the script is more of a process and not one that you can just clone and use.  Please read through it if you want to build the image as there are lines commented that you will want read if you are building from scratch.<br>
<br>
<strong>To download the prebuilt image go to the "Releases" section.</strong><br>
<br>
<strong>October 26th 2019 - v14 Desktop Pre-Release</strong><br>
-Kernel source tree and headers are now included in the image!<br>
-The kernel build source tree is located at rpi-linux-"${KERNEL_VERSION}"<br>
-Ubuntu's first official release has come for the Pi 4 but it's 19.10 only which is not a LTS release and support ends for it in 
-DKMS module building tested (you can test using apt install hello-dkms)<br>
-If you want custom kernel flags you can go to the /usr/src/rpi-linux folder and run make menuconfig (see BuildPiKernel64bit.sh for more info)<br>
-Rewrote build script to be more readable and reliable.  It's still a work in progress but I'm breaking things down into functions, etc.<br>
<br>
<strong>October 23nd 2019 - v13 Desktop Pre-Release</strong><br>
-raspi-config tool is now included with the image for (testing only, don't use on critical fully set up images).  You can use it to turn on i2c/spi/etc. File an issue if you find problems!<br>
-vcgencmd tool (and other libraspberrypi-userland packages) are now included (older build, works for essentials such as vcgencmd measure_temp, vcgencmd get_config int, vcgencmd get_throttled, etc)<br>
-Added 5Ghz WiFi band support (default regulatory domain US, change in /etc/default/crda if desired)<br>
-Updated kernel to 4.19.80<br>
-Fixed sound artifacts when playing YouTube/videos in browser<br>
-Fixed fsck errors during resize2fs operations<br>
<br>
<strong>October 6th 2019 - v12 Desktop Pre-Release</strong><br>
-Fixed Bluetooth not automatically attaching (now appears in both console and desktop mode)<br>
-Updated firmware using the latest from the Raspbian image<br>
<br>
<strong>October 5th 2019 - v11 Desktop Pre-Release</strong><br>
-Updated kernel to 4.19.76<br>
-Fixed several video driver issues including very low performance, YouTube videos in full screen freezing the Pi, low color resolution in xubuntu-desktop and graphical artifacts in kubuntu-desktop<br>
-Fixed bluetooth by adding missing firmware file not present in firmware-nonfree<br>
-Updated /boot/firmware/config.txt with useful HDMI debug flags -- uncomment some of these such as hdmi_safe if you are not getting display output<br>
-Added lines in config.txt to configure SPI and i2C -- you can uncomment these lines if you need to enable them<br>
-Updated WiFi firmware<br>
-Added missing regulatory.db files (used by WiFi) to /lib/firmware<br>
-Note for Kubuntu desktop: the compositor needs to be disabled for everything to draw correctly.  Use the shortcut Alt + Shift + F12 to disable the compositor and everything will draw normally.  Now go into the Settings app and go to the "Compositor" section and uncheck "Enable compositor at startup" to prevent it from turning back on when you reboot.<br>
<br>
<strong>October 3rd 2019 - v10 Desktop Pre-Release</strong><br>
-Fixed issue with wireless not showing in v9<br>
-Fixed bad symlink creation (pull request #38)<br>
<br>
<strong>October 2nd 2019 - v9 Desktop Pre-Release</strong><br>
-Updated kernel and modules to rpi-4.19.75<br>
-start*.elf and fixup*.dat files (GPU firmware) are now updated with each release<br>
-Kernel .config has been updated with the latest default config and Sakiki-'s conform_config.sh parameters<br>
-New conform_config_jamesachambers.sh script added to better keep track of kernel config changes<br>
-SPI is now enabled<br>
-CPU bandwidth provisioning for FAIR_GROUP_SCHED is now enabled (CONFIG_CFS_BANDWIDTH=y)<br>
-Additional Ceph kernel config parameters enabled (see conform_config_jamesachambers.sh for all params)<br>
-A lot of additional hardware support has been enabled via the official Raspberry Pi default kernel config params -- if you were having trouble with a device try v9<br>
-Cleaned up build script by adding additional needed dependencies to apt-get commands, broke up some sections and added additional comments<br>
<br>
<strong>September 19th 2019 - v8 Desktop Pre-Release</strong><br>
-Updated kernel to rpi-4.19.73<br>
-Added hosts entry to prevent slow sudo command<br>
-Added CONFIG_CGROUP_PIDS=y to .config file<br>
-Committed extras folder to repository<br>
-Added forcefsck file to run fsck on first boot<br>
-Reduced image size substantially by running fstrim on .img<br>
<br>
<strong>September 8th 2019 - v7 Desktop Pre-Release</strong><br>
-Updated kernel to rpi-4.19.71<br>
-Added CONFIG_BLK_DEV_RBD=y to kernel .config file to enable Ceph support<br>
<br>
<strong>September 7th 2019 - v6 Desktop Pre-Release</strong><br>
-Updated kernel to rpi-4.19.71<br>
-Integrated all available updates from apt into the base image<br>
-Fixed display driver issue -- if you are running v5 you can fix it by commenting out dtoverlay=vc4-fkms-v3d from /boot/config.txt<br>
-Enabled Ceph support in the kernel .config<br>
-Added build flags to kernel build line to build a more complete device tree (dtbo files)<br>
-Integrated all upstream updates since v5 from raspberrypi-linux and firmware-nonfree including a 3d driver fix for aarch64<br>
<br>
<strong>September 3rd 2019 - v5 Desktop Pre-Release Test</strong><br>
-Desktop support added<br>
-Expect lots of warnings in the logs.  If you find solutions to them please leave a comment -- many commits come from the comments!<br>
-Be advised -- installing can take quite a while on a Pi -- overnight or when you have something to do is a good time<br>
-Type one the following commands to install your preferred flavor of Ubuntu Desktop:<br>
sudo apt-get install xubuntu-desktop # or<br>
sudo apt-get install kubuntu-desktop<br>
<br>
<strong>September 2nd 2019 - v4 Pre-Release Test</strong><br>
-Recompiled kernel to include support for Ubuntu features that are not present in Raspbian<br>
-Enabled USB UAS support<br>
-Fixed video driver by modifying config.txt and compiling with 3D support<br>
-System now boots clean and loads all modules (sudo systemd status)<br>
<br>
<strong>September 2nd 2019 - v3 Pre-Release Test</strong><br>
-Fixed IPV6 and several other modules not loading<br>
<br>
<strong>August 31st 2019 - v2 Pre-Release Test</strong><br>
-Boot time reduced from 100s to around 30s<br>
-Messing with apt-mark or flash-kernel is no longer necessary and the fix has been built into the image<br>
-Fixed bluetooth firmware bug that was looking in /etc/firmware instead of /lib/firmware<br>
-Fixed entropy bug causing slow startup<br>
-Fixed mdadm.conf RAID warning<br>
-Module.symvars is now available in /boot/firmware/ if you need it to build kernel modules<br>
-If you need the whole source tree check out the accompanying build script in the repository. It's exactly how the source tree used to build the kernel is built.<br>
-Various other fixes (special thanks to Joan at jamesachambers.com for contributing so many)<br>
