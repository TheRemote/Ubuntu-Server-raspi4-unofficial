<h2>Overview</h2>
This is a Raspberry Pi 4 compatible Ubuntu 18.04.3 preinstalled server for the new (and currently unsupported officially in the 18.04 LTS series) Raspberry Pi 4.<br>
<br>
For more information visit https://jamesachambers.com/raspberry-pi-4-ubuntu-server-desktop-18-04-3-image-unofficial/ including a walkthrough and lots of comments / discussion.<br>
<br>
Note: Ubuntu has released their first official distribution that supports the Raspberry Pi 4.  The bad news it it's only for the short term Ubuntu 19.10 Eoan Ermine release and *not* 
for the 18.04 LTS release that will still be supported until a whopping April 2023 still.  This means that for now this project will live on supporting the 18.04 LTS branch.<br>
<br>
The early official 19.10 release seems to be having a lot of issues particularly with USB devices (I couldn't get my USB devices to connect to it either during initial testing).  I also saw a lot of warnings in the log files especially with a full desktop installed.  I personally am not concerned about these early hardware issues and I expect those to improve quickly but be advised just because it's an official release doesn't mean it's rock solid stable yet!<br>
<br>
This unofficial Ubuntu image is a compilation of all the latest knowledge/firmware/fixes for running a 64 bit operating system on the new Raspberry Pi 4.  If you find problems report it in the issues section and I and others will assist!<br>
<h2>Highlights</h2>
<ul>
    <li>Fully 64-bit kernel and userspace environment</li>
    <li>Updates normally via apt dist-upgrade from the official Ubuntu repositories</li>
    <li>Uses the official 4.19.y Raspbian linux kernel built with arm64 flags</li>
    <li>Firmware updates from the Raspbian image and the RPi-Distro/firmware-nonfree repository</li>
    <li>3D video hardware acceleration support via vc4-fkms-v3d stack.  Videos / games are giving very high and smooth FPS.</li>
    <li>Includes kernel headers and the full kernel source tree used to build a kernel with your own custom flags (/usr/src/ directory)</li>
    <li>Can build out-of-tree and DKMS modules.  Type apt-install hello-dkms to build a test DKMS module / get all the dependencies</li>
    <li>Full desktop support available via apt install kubuntu-desktop, xubuntu-desktop, xfce4, mate-desktop-environment, etc.)</li>
    <li>5 GHz WiFi channel support</li>
    <li>Working Bluetooth and WiFi</li>
    <li>KVM virtualization support</li>
    <li>Update script provided to update kernels/firmware/modules</li>
</ul>
<h2>Updates</h2>
First and foremost all of your updates will be coming from Ubuntu directly in apt as it would with any official image.  The only things set on package hold (using apt-mark hold )
Updates to the firmware and fixes to common problems will be provided as long as there is interest.  <br>
<br>
I expect at some point Ubuntu will backport 18.04.3 back to LTS as it is their long term release but only they know how long tat might take!  In the mean time I will do some short term updates of firmware/fixes/kernels/etc. and when Ubuntu's repositories get working firmware you will switch back to their firmware.<br>
<br>
I have also included an updater that will give you the latest kernel/firmware/modules/fixes that are included in each release.
If Ubuntu's 18.04.3 update servers get working firmware for the Raspberry Pi 4 I will change the update script to remove the apt-mark holds on the Raspberry Pi firmware package in apt and close the project down (leaving this here for people to learn from to hack an unsupported device into their own distros, or until I do it again on the next Pi release!)<br>
<br>
<h2>Building Image Yourself</h2>
I have included both the script to create the image yourself (BuildPiKernel64bit.sh) using the official images as a base.  Binary releases are also available as a preinstalled image (available in the "Releases" section at the top of this page) that you can download and write to a SD card without building anything yourself.  Note that the script is more of a process and not one that you can just clone and use.  Please read through it if you want to build the image as there are lines commented that you will want read if you are building from scratch.<br>
<br>
The idea is that with the build script and the kernel source code built directly into the IMG file (/usr/src/rpi-linux-*) you don't need me to personally update it for you and customize every kernel flag for you or even plan on me being around in the future.  The kernel is just the plain Raspbian 4.19.y kernel source built directly from Git (see build script).  You have all the tools you need to change kernel flags and recompile, build kernel modules, and really do anything that I can do now.  This whole page is a set of tools and a process to let you customize if you need to.<br>
<br>
<h2>Support</h2>
If you come across a problem definitely open a GitHub issue or drop by the jamesachambers.com page linked at the top.  I can add these issues as fixes and include them in the firmware/kernel updates provided through Updater.sh
<br>
<strong>To download the prebuilt image go to the "Releases" section.</strong><br>
<br>
<h2>Update History</h2>
<strong>October 28th 2019 - v15 Official Release</strong><br>
<ul>
<li>Script to update between releases is finally ready, and with that I am taking this out of pre-release!</li>
<li>To get the update script use the following commands:</li>
</li>
wget https://raw.githubusercontent.com/TheRemote/Ubuntu-Server-raspi4-unofficial/master/Updater.sh<br>
chmod +x Updater.sh<br>
sudo ./Updater.sh<br>
<br></li>
<li>You can update from any pre-release release version.  Please make a backup first!</li>
<li>The updater is located at /home/Updater.sh on v15 and up (to run type sudo bash /home/Updater.sh)</li>
</ul>
<br>
<strong>October 26th 2019 - v14 Desktop Pre-Release</strong><br>
<ul>
<li>Kernel source tree and headers are now included in the image!</li>
<li>The kernel build source tree is located at rpi-linux-"${KERNEL_VERSION}"</li>
<li>Ubuntu's first official release has come for the Pi 4 but it's 19.10 only which is not a LTS release and support ends for it in July 2020</li>
<li>DKMS module building tested (you can test using apt install hello-dkms)</li>
<li>If you want custom kernel flags you can go to the /usr/src/rpi-linux folder and run make menuconfig (see BuildPiKernel64bit.sh for more info)</li>
<li>Rewrote build script to be more readable and reliable.  It's still a work in progress but I'm breaking things down into functions, etc.</li>
</ul>
<br>
<strong>October 23nd 2019 - v13 Desktop Pre-Release</strong><br>
<ul>
<li>raspi-config tool is now included with the image for (testing only, don't use on critical fully set up images).  You can use it to turn on i2c/spi/etc. File an issue if you find problems!</li>
<li>vcgencmd tool (and other libraspberrypi-userland packages) are now included (older build, works for essentials such as vcgencmd measure_temp, vcgencmd get_config int, vcgencmd get_throttled, etc)</li>
<li>Added 5Ghz WiFi band support (default regulatory domain US, change in /etc/default/crda if desired)</li>
<li>Updated kernel to 4.19.80</li>
<li>Fixed sound artifacts when playing YouTube/videos in browser</li>
<li>Fixed fsck errors during resize2fs operations</li>
</ul>
<br>
<strong>October 6th 2019 - v12 Desktop Pre-Release</strong><br>
<ul>
<li>Fixed Bluetooth not automatically attaching (now appears in both console and desktop mode)</li>
<li>Updated firmware using the latest from the Raspbian image</li>
</ul>
<br>
<strong>October 5th 2019 - v11 Desktop Pre-Release</strong><br>
<ul>
<li>Updated kernel to 4.19.76<br>
<li>Fixed several video driver issues including very low performance, YouTube videos in full screen freezing the Pi, low color resolution in xubuntu-desktop and graphical artifacts in kubuntu-desktop</li>
<li>Fixed bluetooth by adding missing firmware file not present in firmware-nonfree</li>
<li>Updated /boot/firmware/config.txt with useful HDMI debug flags -- uncomment some of these such as hdmi_safe if you are not getting display output</li>
<li>Added lines in config.txt to configure SPI and i2C -- you can uncomment these lines if you need to enable them</li>
<li>Updated WiFi firmware</li>
<li>Added missing regulatory.db files (used by WiFi) to /lib/firmware</li>
<li>Note for Kubuntu desktop: the compositor needs to be disabled for everything to draw correctly.  Use the shortcut Alt + Shift + F12 to disable the compositor and everything will draw normally.  Now go into the Settings app and go to the "Compositor" section and uncheck "Enable compositor at startup" to prevent it from turning back on when you reboot.</li>
</ul>
<br>
<strong>October 3rd 2019 - v10 Desktop Pre-Release</strong><br>
<ul>
<li>Fixed issue with wireless not showing in v9<br>
<li>Fixed bad symlink creation (pull request #38)<br>
</ul>
<br>
<strong>October 2nd 2019 - v9 Desktop Pre-Release</strong><br>
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
<br>
<strong>September 19th 2019 - v8 Desktop Pre-Release</strong><br>
<ul>
<li>Updated kernel to rpi-4.19.73</li>
<li>Added hosts entry to prevent slow sudo command</li>
<li>Added CONFIG_CGROUP_PIDS=y to .config file</li>
<li>Committed extras folder to repository</li>
<li>Added forcefsck file to run fsck on first boot</li>
<li>Reduced image size substantially by running fstrim on .img</li>
</ul>
<br>
<strong>September 8th 2019 - v7 Desktop Pre-Release</strong><br>
<ul>
<li>Updated kernel to rpi-4.19.71</li>
<li>Added CONFIG_BLK_DEV_RBD=y to kernel .config file to enable Ceph support</li>
</ul>
<br>
<strong>September 7th 2019 - v6 Desktop Pre-Release</strong><br>
<ul>
<li>Updated kernel to rpi-4.19.71</li>
<li>Integrated all available updates from apt into the base image</li>
<li>Fixed display driver issue -- if you are running v5 you can fix it by commenting out dtoverlay=vc4-fkms-v3d from /boot/config.txt</li>
<li>Enabled Ceph support in the kernel .config</li>
<li>Added build flags to kernel build line to build a more complete device tree (dtbo files)</li>
<li>Integrated all upstream updates since v5 from raspberrypi-linux and firmware-nonfree including a 3d driver fix for aarch64</li>
</ul>
<br>
<strong>September 3rd 2019 - v5 Desktop Pre-Release Test</strong><br>
<ul>
<li>Desktop support added</li>
<li>Expect lots of warnings in the logs.  If you find solutions to them please leave a comment -- many commits come from the comments!</li>
<li>Be advised -- installing can take quite a while on a Pi -- overnight or when you have something to do is a good time</li>
<li>Type one the following commands to install your preferred flavor of Ubuntu Desktop:</li>
sudo apt-get install xubuntu-desktop # or</li>
sudo apt-get install kubuntu-desktop</li>
</ul>
<br>
<strong>September 2nd 2019 - v4 Pre-Release Test</strong><br>
<ul>
<li>Recompiled kernel to include support for Ubuntu features that are not present in Raspbian</li>
<li>Enabled USB UAS support</li>
<li>Fixed video driver by modifying config.txt and compiling with 3D support</li>
<li>System now boots clean and loads all modules (sudo systemd status)</li>
</ul>
<br>
<strong>September 2nd 2019 - v3 Pre-Release Test</strong><br>
<ul>
<li>Fixed IPV6 and several other modules not loading</li>
</ul>
<br>
<strong>August 31st 2019 - v2 Pre-Release Test</strong><br>
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
<br>