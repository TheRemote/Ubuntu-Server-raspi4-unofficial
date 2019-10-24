#!/usr/bin/env bash

# CONFIGURATION
IMAGE_VERSION="14"
TARGET_IMGXZ="ubuntu-18.04.3-preinstalled-server-arm64+raspi4.img.xz"
TARGET_IMG="ubuntu-18.04.3-preinstalled-server-arm64+raspi4.img"
SOURCE_RELEASE="18.04.3"
SOURCE_IMGXZ="ubuntu-18.04.3-preinstalled-server-arm64+raspi3.img.xz"
SOURCE_IMG="ubuntu-18.04.3-preinstalled-server-arm64+raspi3.img"
MountXZ=""

# FUNCTIONS
function MountIMG {
  MountXZ=$(sudo kpartx -avs "$TARGET_IMG")
  sync
  MountXZ=$(echo "$MountXZ" | awk 'NR==1{ print $3 }')
  MountXZ="${MountXZ%p1}"
  echo "Mounted $TARGET_IMG on loop $MountXZ"
}

function MountIMGPartitions {
  # % Mount the image on /mnt (rootfs)
  sudo mount /dev/mapper/"$MountXZ"p2 /mnt
  # % Remove overlapping firmware folder from rootfs
  sudo rm -rf /mnt/boot/firmware/*
  # % Mount /mnt/boot/firmware folder from bootfs
  sudo mount /dev/mapper/"$MountXZ"p1 /mnt/boot/firmware

  sync
  sleep 0.1
}

function UnmountIMGPartitions {
  sync
  sleep 0.1

  echo "Unmounting /mnt/boot/firmware"
  while mountpoint -q /mnt/boot/firmware && ! sudo umount /mnt/boot/firmware; do
    sync
    sleep 0.1
  done

  echo "Unmounting /mnt"
  while mountpoint -q /mnt && ! sudo umount /mnt; do
    sync
    sleep 0.1
  done

  sync
  sleep 0.1
}

function UnmountIMG {
  sync
  sleep 0.1

  UnmountIMGPartitions

  echo "Unmounting $TARGET_IMG"
  sudo kpartx -dvs "$TARGET_IMG"

  while [ -n "$(sudo losetup --list | grep /dev/$MountXZ)" ]; do
    sync
    sleep 0.1
  done
}

# INSTALL DEPENDENCIES

sudo apt-get install build-essential libgmp-dev libmpfr-dev libmpc-dev libssl-dev bison flex libncurses-dev kpartx qemu-user-static zerofree systemd-container -y

# PULL UBUNTU RASPBERRY PI 3 IMAGE
if [ ! -f "$TARGET_IMG" ]; then
  sudo rm -f $TARGET_IMG
fi

if [ ! -f "$SOURCE_IMGXZ" ]; then
  wget http://cdimage.ubuntu.com/ubuntu/releases/$SOURCE_RELEASE/release/$SOURCE_IMGXZ
fi

if [ ! -f "$SOURCE_IMG" ]; then
  xzcat "$SOURCE_IMGXZ" > "$SOURCE_IMG"
fi

sudo rm -f "$TARGET_IMG"
cp -vf "$SOURCE_IMG" "$TARGET_IMG"

sync
sleep 5

# % Expands the image by approximately 300MB to help us not run out of space and encounter errors
truncate -s +309715200 "$TARGET_IMG"
sync

# BUILD CROSS COMPILE TOOLCHAIN
cd ~
if [ -d "toolchains" ]; then
  cd toolchains/aarch64
  export TOOLCHAIN=`pwd`
else
  mkdir -p toolchains/aarch64
  cd toolchains/aarch64
  export TOOLCHAIN=`pwd`
  cd ~

  cd "$TOOLCHAIN"
  wget https://ftp.gnu.org/gnu/binutils/binutils-2.33.1.tar.bz2
  tar -xf binutils-2.*.tar.bz2
  mkdir binutils-2.*-build
  cd binutils-2.*-build
  ../binutils-2.*/configure --prefix="$TOOLCHAIN" --target=aarch64-linux-gnu --disable-nls
  make -j$(nproc)
  make install

  cd "$TOOLCHAIN"
  wget https://ftp.gnu.org/gnu/gcc/gcc-9.2.0/gcc-9.2.0.tar.gz
  tar -xf gcc-9.2.0.tar.gz
  mkdir gcc-9.2.0-build
  cd gcc-9.2.0-build
  ../gcc-9.2.0/configure --prefix="$TOOLCHAIN" --target=aarch64-linux-gnu --with-newlib --without-headers --disable-nls --disable-shared --disable-threads --disable-libssp --disable-decimal-float --disable-libquadmath --disable-libvtv --disable-libgomp --disable-libatomic --enable-languages=c
  make all-gcc -j$(nproc)
  make install-gcc
fi

# GET FIRMWARE NON-FREE
cd ~
if [ ! -d "firmware-nonfree" ]; then
  git clone https://github.com/RPi-Distro/firmware-nonfree firmware-nonfree --depth 1
else
  cd firmware-nonfree
  git pull
fi

# GET FIRMWARE
cd ~
if [ ! -d "firmware" ]; then
  git clone https://github.com/raspberrypi/firmware firmware --depth 1
else
  cd firmware
  git pull
fi

# MAKE FIRMWARE BUILD DIR
cd ~
sudo rm -rf firmware-build
mkdir firmware-build
cp -rf ~/firmware-nonfree/* ~/firmware-build
cp -rf ~/firmware-raspbian/* ~/firmware-build
sudo rm -rf ~/firmware-build/.git 
sudo rm -rf ~/firmware-build/.github

# BUILD KERNEL

# % Check out the 4.19.y kernel branch -- if building and future versions are available you can update which branch is checked out here
cd ~
if [ ! -d "rpi-linux" ]; then
  git clone https://github.com/raspberrypi/linux.git rpi-linux --single-branch --branch rpi-4.19.y --depth 1
  cd rpi-linux
  git checkout origin/rpi-4.19.y

  # CONFIGURE / MAKE
  cd ~/rpi-linux
  PATH=$PATH:$TOOLCHAIN/bin make -j$(nproc) ARCH=arm64 CROSS_COMPILE=aarch64-linux-gnu- distclean bcm2711_defconfig

  # % Run conform_config scripts which fix kernel flags to work correctly in arm64
  wget https://raw.githubusercontent.com/sakaki-/bcmrpi3-kernel-bis/master/conform_config.sh
  chmod +x conform_config.sh
  ./conform_config.sh
  rm -f conform_config.sh
  wget https://raw.githubusercontent.com/TheRemote/Ubuntu-Server-raspi4-unofficial/master/conform_config_jamesachambers.sh
  chmod +x conform_config_jamesachambers.sh
  ./conform_config_jamesachambers.sh
  rm -f conform_config_jamesachambers.sh

  # % This pulls the latest config from the repository -- if building yourself/customizing comment out
  rm .config
  wget https://raw.githubusercontent.com/TheRemote/Ubuntu-Server-raspi4-unofficial/master/.config

  # % Run prepare to register all our .config changes
  cd ~/rpi-linux
  PATH=$PATH:$TOOLCHAIN/bin make -j$(nproc) ARCH=arm64 DTC_FLAGS="-@ -H epapr" CROSS_COMPILE=aarch64-linux-gnu- prepare

  # % Prepare and build the rpi-linux source
  # % Create debian packages to make it easy to update the image
  PATH=$PATH:$TOOLCHAIN/bin make -j$(nproc) ARCH=arm64 DTC_FLAGS="-@ -H epapr" CROSS_COMPILE=aarch64-linux-gnu- LOCALVERSION=-james KDEB_PKGVERSION=v$IMAGE_VERSION Image modules dtbs deb-pkg

  # % Build kernel modules
  PATH=$PATH:$TOOLCHAIN/bin make -j$(nproc) ARCH=arm64 CROSS_COMPILE=aarch64-linux-gnu- modules_install # INSTALL_MOD_PATH="/mnt/piroot"
fi

export KERNEL_VERSION=`cat ./include/generated/utsrelease.h | sed -e 's/.*"\(.*\)".*/\1/'`


# MOUNT IMAGE
cd ~
MountIMG

# % Get the starting offset of the root partition
PART_START=$(sudo parted /dev/$MountXZ -ms unit s p | grep ":ext4" | cut -f 2 -d: | sed 's/[^0-9]//g')

# % Perform fdisk to correct the partition table
sudo fdisk /dev/$MountXZ <<EOF
p
d
2
n
p
2
$PART_START

p
w
EOF

# Close and unmount image then reopen it to get the new mapping
UnmountIMG
MountIMG

# Run fsck
sudo e2fsck -fva /dev/mapper/"$MountXZ"p2
sync
sleep 1

UnmountIMG
MountIMG

# Run resize2fs
sudo resize2fs /dev/mapper/"$MountXZ"p2
sync
sleep 1

UnmountIMG
MountIMG

# % Zero out free space on drive to reduce compressed img size
sudo zerofree -v /dev/mapper/"$MountXZ"p2

# % Map the partitions of the IMG file so we can access the filesystem
MountIMGPartitions

# % Clean out old firmware, kernel and modules that don't support RPI 4
sudo rm -rf /mnt/lib/firmware/4.15.0-1041-raspi2
sudo rm -rf /mnt/boot/firmware/*
sudo rm -rf /mnt/usr/src/*
sudo rm -rf /mnt/lib/modules/*

sudo rm -rf /mnt/boot/initrd*
sudo rm -rf /mnt/boot/config*
sudo rm -rf /mnt/boot/vmlinuz*
sudo rm -rf /mnt/boot/System.map*

sync
sleep 2

# CREATE FILES FOR UPDATER
cd ~
sudo rm -rf ~/updates
mkdir ~/updates
mkdir ~/updates/bootfs
mkdir ~/updates/bootfs/overlays
mkdir ~/updates/rootfs
mkdir ~/updates/rootfs/boot
mkdir ~/updates/rootfs/lib
mkdir ~/updates/rootfs/lib/firmware
mkdir ~/updates/rootfs/lib/modules
cp -rvf ~/firmware-build/* ~/updates/rootfs/lib/firmware
cp -rvf ~/rpi-linux/lib/modules/* ~/updates/rootfs/lib/modules

sync
sleep 2

# % Create cmdline.txt
sudo rm -f ~/updates/bootfs/cmdline.txt
cat << EOF | tee ~/updates/bootfs/cmdline.txt
snd_bcm2835.enable_headphones=1 snd_bcm2835.enable_hdmi=1 snd_bcm2835.enable_compat_alsa=0 dwc_otg.fiq_fix_enable=2 console=serial0,115200 console=tty1 root=/dev/mmcblk0p2 rootfstype=ext4 fsck.repair=yes fsck.mode=force rootwait
EOF

# % Create config.txt
sudo rm -f ~/updates/bootfs/config.txt
cat << EOF | tee ~/updates/bootfs/config.txt
# uncomment if you get no picture on HDMI for a default "safe" mode
#hdmi_safe=1

# uncomment this if your display has a black border of unused pixels visible
# and your display can output without overscan
disable_overscan=1

# uncomment the following to adjust overscan. Use positive numbers if console
# goes off screen, and negative if there is too much border
#overscan_left=16
#overscan_right=16
#overscan_top=16
#overscan_bottom=16

# uncomment to force a console size. By default it will be display's size minus
# overscan.
#framebuffer_width=1280
#framebuffer_height=720

# uncomment if hdmi display is not detected and composite is being output
#hdmi_force_hotplug=1

# uncomment to force a specific HDMI mode (this will force VGA)
#hdmi_group=1
#hdmi_mode=1

# uncomment to force a HDMI mode rather than DVI. This can make audio work in
# DMT (computer monitor) modes
#hdmi_drive=2

# uncomment to increase signal to HDMI, if you have interference, blanking, or
# no display
#config_hdmi_boost=4

# uncomment for composite PAL
#sdtv_mode=2

#uncomment to overclock the arm. 700 MHz is the default.
#arm_freq=800

# Uncomment some or all of these to enable the optional hardware interfaces
#dtparam=i2c_arm=on
#dtparam=i2s=on
#dtparam=spi=on

# Uncomment this to enable infrared communication.
#dtoverlay=gpio-ir,gpio_pin=17
#dtoverlay=gpio-ir-tx,gpio_pin=18

# Enable audio (loads snd_bcm2835)
dtparam=audio=on

[pi4]
dtoverlay=vc4-fkms-v3d
max_framebuffers=2
arm_64bit=1

[all]
#dtoverlay=vc4-fkms-v3d
EOF

# % Copy overlays / image / firmware
cp -rvf ~/rpi-linux/arch/arm64/boot/dts/broadcom/*.dtb ~/updates/bootfs
cp -rvf ~/rpi-linux/arch/arm64/boot/dts/overlays/*.dtb* ~/updates/bootfs/overlays
cp -vf ~/rpi-linux/arch/arm64/boot/Image ~/updates/rootfs/boot
cp -vf ~/vmlinuz ~/updates/rootfs/boot/vmlinuz-"${KERNEL_VERSION}"

# % Copy the new kernel modules
mkdir ~/updates/rootfs/lib/modules/${KERNEL_VERSION}
cp -ravf rpi-linux/kernel-install/* ~/updates/rootfs

# % Copy gpu firmware via start*.elf and fixup*.dat files
cp -rvf ~/firmware/boot/*.elf ~/updates/bootfs
cp -rvf ~/firmware/boot/*.dat ~/updates/bootfs

# % Copy kernel System.map and .config files
#cp -vf ~/rpi-linux/System.map ~/updates/bootfs/System.map-"${KERNEL_VERSION}"
#cp -vf ~/rpi-linux/.config ~/updates/bootfs/config-"${KERNEL_VERSION}"
cp -vf ~/rpi-linux/arch/arm64/boot/Image ~/updates/bootfs/kernel8.img

# % Copy bootfs and rootfs
sudo cp -rvf ~/updates/bootfs/* /mnt/boot/firmware
sudo cp -rvf ~/updates/rootfs/* /mnt

# % Create symlinks to our custom kernel -- this allows initramfs to find our kernel and update modules successfully
(
  cd /mnt/boot
  sudo ln -s vmlinuz-"${KERNEL_VERSION}" vmlinuz
  #sudo ln -s initrd.img-"${KERNEL_VERSION}" initrd.img
  sudo ln -s System.map-"${KERNEL_VERSION}" System.map
  sudo ln -s Module.symvers-"${KERNEL_VERSION}" Modules.symvers
  cd ~
)

# % Create kernel header symlink
#cd /mnt
#sudo rm lib/modules/${KERNEL_VERSION}/build
#sudo ln -s usr/src/linux-headers-${KERNEL_VERSION} lib/modules/${KERNEL_VERSION}/build

# % Remove initramfs actions for invalid existing kernels, then create a new link to our new custom kernel
sudo rm -rf /mnt/var/lib/initramfs-tools/*
sha1sum=$(sha1sum  /mnt/boot/vmlinuz-"${KERNEL_VERSION}")
echo "$sha1sum  /boot/vmlinuz-${KERNEL_VERSION}" | sudo -A tee -a /mnt/var/lib/initramfs-tools/"${KERNEL_VERSION}" >/dev/null;

# QUIRKS

cd ~

# % Fix WiFi
# % The Pi 4 version returns boardflags3=0x44200100
# % The Pi 3 version returns boardflags3=0x48200100cd
sudo sed -i "s:0x48200100:0x44200100:g" ~/firmware-build/brcm/brcmfmac43455-sdio.txt

# % Remove flash-kernel hooks to prevent firmware updater from overriding our custom firmware
sudo rm -f /mnt/etc/kernel/postinst.d/zz-flash-kernel
sudo rm -f /mnt/etc/kernel/postrm.d/zz-flash-kernel
sudo rm -f /mnt/etc/initramfs/post-update.d/flash-kernel

# % Disable ib_iser iSCSI cloud module to prevent an error during systemd-modules-load at boot
sudo sed -i "s/ib_iser/#ib_iser/g" /mnt/lib/modules-load.d/open-iscsi.conf
sudo sed -i "s/iscsi_tcp/#iscsi_tcp/g" /mnt/lib/modules-load.d/open-iscsi.conf

# % Fix update-initramfs mdadm.conf warning
grep "ARRAY devices" /mnt/etc/mdadm/mdadm.conf >/dev/null || echo "ARRAY devices=/dev/sda" | sudo -A tee -a /mnt/etc/mdadm/mdadm.conf >/dev/null;

# CHROOT

# % Copy QEMU bin file so we can chroot into arm64 from x86_64
sudo cp -f /usr/bin/qemu-aarch64-static /mnt/usr/bin

# % Install new kernel modules
sudo mkdir -p /mnt/run/systemd/resolve
cat /run/systemd/resolve/stub-resolv.conf | sudo -A tee /mnt/run/systemd/resolve/stub-resolv.conf >/dev/null;
#sudo touch /mnt/etc/modules-load.d/cups-filters.conf

# % Startup tweaks to fix bluetooth
sudo rm /mnt/etc/rc.local
cat << EOF | sudo tee /mnt/etc/rc.local
#!/bin/bash
#
# rc.local
#

# % Fix crackling sound
if [ -n "`which pulseaudio`" ]; then
  GrepCheck=$(cat /etc/pulse/default.pa | grep "load-module module-udev-detect tsched=0")
  if [ ! -n "$GrepCheck" ]; then
    sed -i "s:load-module module-udev-detect:load-module module-udev-detect tsched=0:g" /etc/pulse/default.pa
  fi
fi

# Enable bluetooth
if [ -n "`which hciattach`" ]; then
  echo "Attaching Bluetooth controller ..."
  hciattach /dev/ttyAMA0 bcm43xx 921600
fi

exit 0
EOF
sudo chmod +x /mnt/etc/rc.local

# % Enter Ubuntu image chroot
sudo chroot /mnt /bin/bash << EOF

# % Fix /lib/firmware permission and symlink
chown -R root /lib

# % Add symbolic link from /etc/firmware to /lib/firmware (fixes Bluetooth)
ln -s /lib/firmware /etc/firmware

#xargs -I % sudo add-apt-repository -y % << EOF
#  ppa:ubuntu-x-swat/updates
#  ppa:ubuntu-raspi2/ppa
#  ppa-ubuntu-raspi4
#EOF

# % Add updated mesa repository for video driver support
#add-apt-repository ppa:theremote/ppa-ubuntu-raspi4 -y

# % Add updated mesa repository for video driver support
add-apt-repository ppa:ubuntu-x-swat/updates -y

# % Add Raspberry Pi Userland repository
add-apt-repository ppa:ubuntu-raspi2/ppa -y

# % Hold Ubuntu packages that will break booting from the Pi 4
apt-mark hold flash-kernel linux-raspi2 linux-image-raspi2 linux-headers-raspi2 linux-firmware-raspi2

# % Remove linux-firmware-raspi2
# % Remove ureadahead, does not support arm and makes our bootup unclean when checking systemd status
apt remove linux-firmware-raspi2 ureadahead libnih1 --allow-change-held-packages -y

# % Install wireless tools and bluetooth
# % Install Raspberry Pi userland utilities via libraspberrypi-bin (vcgencmd, etc.)
# % INSTALL HAVAGED - prevents low entropy from making the Pi take a long time to start up.
# % Install raspi-config dependencies (libnewt0.52 whiptail parted triggerhappy lua5.1 alsa-utils)
apt update && apt install wireless-tools iw rfkill bluez libraspberrypi-bin haveged libnewt0.52 whiptail parted triggerhappy lua5.1 alsa-utils -y && apt dist-upgrade -y

# % Install raspi-config utility
wget https://archive.raspberrypi.org/debian/pool/main/r/raspi-config/raspi-config_20191005_all.deb
dpkg -i raspi-config_20191005_all.deb
rm raspi-config_20191005_all.deb
sed -i "s:/boot/config.txt:/boot/firmware/config.txt:g" /usr/bin/raspi-config
sed -i "s:/boot/cmdline.txt:/boot/firmware/cmdline.txt:g" /usr/bin/raspi-config
sed -i "s:armhf:arm64:g" /usr/bin/raspi-config
sed -i "s:/boot/overlays:/boot/firmware/overlays:g" /usr/bin/raspi-config
sed -i "s:/boot/start:/boot/firmware/start:g" /usr/bin/raspi-config
sed -i "s:/boot/arm:/boot/firmware/arm:g" /usr/bin/raspi-config
sed -i "s:/boot :/boot/firmware :g" /usr/bin/raspi-config
sed -i "s:\\/boot\.:\\/boot\\\/firmware\.:g" /usr/bin/raspi-config
sed -i "s:dtparam i2c_arm=$SETTING:dtparam -d /boot/firmware/overlays i2c_arm=$SETTING:g" /usr/bin/raspi-config
sed -i "s:dtparam spi=$SETTING:dtparam -d /boot/firmware/overlays spi=$SETTING:g" /usr/bin/raspi-config
sed -i "s:su pi:su $SUDO_USER:g" /usr/bin/dtoverlay-pre
sed -i "s:su pi:su $SUDO_USER:g" /usr/bin/dtoverlay-post

# % Update initramfs
update-initramfs -u

# % Clean up after ourselves and clean out package cache to keep the image small
apt autoremove -y && apt clean && apt autoclean

EOF

# % Set regulatory crda to enable 5 Ghz wireless
sudo rm /mnt/etc/default/crda
cat << EOF | sudo tee /mnt/etc/default/crda
# Set REGDOMAIN to a ISO/IEC 3166-1 alpha2 country code so that iw(8) may set
# the initial regulatory domain setting for IEEE 802.11 devices which operate
# on this system.
#
# Governments assert the right to regulate usage of radio spectrum within
# their respective territories so make sure you select a ISO/IEC 3166-1 alpha2
# country code suitable for your location or you may infringe on local
# legislature. See `/usr/share/zoneinfo/zone.tab' for a table of timezone
# descriptions containing ISO/IEC 3166-1 alpha2 country codes.

REGDOMAIN=US
EOF

# % Set loopback address in hosts to prevent slow bootup
sudo rm /mnt/etc/hosts
cat << EOF | sudo tee /mnt/etc/hosts
127.0.0.1 localhost
127.0.1.1 ubuntu

# The following lines are desirable for IPv6 capable hosts
::1 ip6-localhost ip6-loopback
fe00::0 ip6-localnet
ff00::0 ip6-mcastprefix
ff02::1 ip6-allnodes
ff02::2 ip6-allrouters
ff02::3 ip6-allhosts
EOF

# % Update fstab to allow fsck to run on rootfs
sudo rm /mnt/etc/fstab
cat << EOF | sudo tee /mnt/etc/fstab
LABEL=writable	/	 ext4	defaults	0 1
LABEL=system-boot       /boot/firmware  vfat    defaults        0       1
EOF

# % Remove any crash files generated during chroot
sudo rm /mnt/var/crash/*
sudo rm /mnt/var/run/*

# UNMOUNT
UnmountIMGPartitions

# Run fsck on image
sudo fsck.ext4 -pfv /dev/mapper/"$MountXZ"p2
sudo fsck.fat -av /dev/mapper/"$MountXZ"p1

sudo zerofree -v /dev/mapper/"$MountXZ"p2

# Save image
UnmountIMG

# Clean up loops
#sudo losetup -d /dev/"${MountXZ}"

