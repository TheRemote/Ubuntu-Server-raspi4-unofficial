#!/bin/bash
#
# More information available at:
# https://jamesachambers.com/raspberry-pi-4-ubuntu-server-desktop-18-04-3-image-unofficial/
# https://github.com/TheRemote/Ubuntu-Server-raspi4-unofficial

# CONFIGURATION

IMAGE_VERSION="14"

TARGET_IMGXZ="ubuntu-18.04.3-preinstalled-server-arm64+raspi4.img.xz"
TARGET_IMG="ubuntu-18.04.3-preinstalled-server-arm64+raspi4.img"
SOURCE_RELEASE="18.04.3"
SOURCE_IMGXZ="ubuntu-18.04.3-preinstalled-server-arm64+raspi3.img.xz"
SOURCE_IMG="ubuntu-18.04.3-preinstalled-server-arm64+raspi3.img"
RASPBIAN_IMG="2019-09-26-raspbian-buster-lite.img"

export SLEEP_SHORT="0.1"
export SLEEP_LONG="1"

export MOUNT_IMG=""
export KERNEL_VERSION="4.19.80-v8-james"

# FUNCTIONS
function PrepareIMG {
  while mountpoint -q /mnt/boot/firmware && ! sudo umount /mnt/boot/firmware; do
    echo "/mnt/boot/firmware still mounted -- unmounting"
    sync; sync
    sleep "$SLEEP_SHORT"
  done

  while mountpoint -q /mnt && ! sudo umount /mnt; do
    echo "/mnt still mounted -- unmounting"
    sync; sync
    sleep "$SLEEP_SHORT"
  done

  MountCheck=$(sudo losetup --list | grep "(deleted)" | awk 'NR==1{ print $1 }')
  while [ -n "$MountCheck" ]; do
    echo "Leftover image $MountCheck found -- removing"
    sudo rm -rf $MountCheck
    MountCheck=$(sudo losetup --list | grep "(deleted)" | awk 'NR==1{ print $1 }')
  done
}
function MountIMG {
   if [ -n "${MOUNT_IMG}" ]; then
    echo "An image is already mounted on ${MOUNT_IMG}"
    return 1
  fi
  if [ ! -e "${1}" ]; then
    echo "Image ${1} does not exist!"
    return 1
  fi

  echo "Mounting image ${1}"
  MountCheck=$(sudo kpartx -avs "${1}")
  echo "$MountCheck"
  export MOUNT_IMG=$(echo "$MountCheck" | awk 'NR==1{ print $3 }')
  export MOUNT_IMG="${MOUNT_IMG%p1}"

  if [ -n "${MOUNT_IMG}" ]; then
    sync; sync
    sleep "$SLEEP_SHORT"
    echo "Mounted ${1} on loop ${MOUNT_IMG}"
  else
    echo "Unable to mount ${1}: ${MOUNT_IMG} Check - $MountCheck"
    export MOUNT_IMG=""
  fi

  sync; sync
  sleep "$SLEEP_SHORT"
}

function MountIMGPartitions {
  echo "Mounting partitions"
  # % Mount the rootfs on /mnt (/)
  sudo mount "/dev/mapper/${1}p2" /mnt
 
  # % Mount the bootfs on /mnt/boot/firmware (/boot/firmware)
  sudo mount "/dev/mapper/${1}p1" /mnt/boot/firmware

  sync; sync
  sleep "$SLEEP_SHORT"
}

function UnmountIMGPartitions {
  sync; sync

  # % Unmount boot and root partitions
  echo "Unmounting /mnt/boot/firmware"
  while mountpoint -q /mnt/boot/firmware && ! sudo umount /mnt/boot/firmware; do
    sync; sync
    sleep "$SLEEP_SHORT"
  done

  echo "Unmounting /mnt"
  while mountpoint -q /mnt && ! sudo umount /mnt; do
    sync; sync
    sleep "$SLEEP_SHORT"
  done

  sync; sync
}

function UnmountIMG {
  # % Unmount image and save changes
  sync; sync

  # % Check if image is mounted first
  MountCheck=$(sudo losetup --list | grep "${1}")
  if [ ! -n "$MountCheck" ]; then
    echo "Unable to unmount $1 (not in losetup --list)"
    UnmountIMGPartitions
    export MOUNT_IMG=""
    return
  fi

  echo "Unmounting $1"
  UnmountIMGPartitions
  sudo kpartx -dvs "$1"
  sync; sync
  sleep "$SLEEP_LONG"

  # % Wait for loop to disappear from list before continuing
  WaitLoops=0
  while [ -n "$(sudo losetup --list | grep ${1})" ]; do
    WaitLoops=$((WaitLoops+1))
    if (( WaitLoops > 50 )); then
      echo "Exceeded maximum wait time -- trying to force close"
      sudo kpartx -dvs "${1}"
      sudo losetup -D
    fi
    sync; sync
    sleep "$SLEEP_SHORT"
  done

  export MOUNT_IMG=""
}

function CompactIMG {
  echo "Compacting IMG file ${1}"
  sudo rm -f "${1}.2"
  sudo virt-sparsify "${1}" "${1}.2"
  sync; sync
  sleep "$SLEEP_SHORT"
  
  sudo rm -f "${1}"
  mv "${1}.2" "${1}"
  sync; sync
  sleep "$SLEEP_SHORT"
}

function BeforeCleanIMG {
  echo "Cleaning IMG file (before)"

  sudo rm -rf /mnt/boot/firmware/*
  sudo rm -rf /mnt/boot/initrd*
  sudo rm -rf /mnt/boot/config*
  sudo rm -rf /mnt/boot/vmlinu*
  sudo rm -rf /mnt/boot/System.map*

  sudo rm -rf /mnt/lib/firmware/4.15.0-1041-raspi2
  sudo rm -rf /mnt/lib/modules/*

  sudo rm -rf /mnt/usr/src/*
  sudo rm -rf /mnt/usr/lib/linux-firmware-raspi2

  sudo rm -rf /mnt/var/log/*.gz 
  sudo rm -rf /mnt/var/lib/initramfs-tools/*
  sudo rm -rf /mnt/var/lib/apt/ports* /mnt/var/lib/apt/*InRelease /mnt/var/lib/apt/*-en /mnt/var/lib/apt/*Packages

  # % Remove flash-kernel hooks to prevent firmware updater from overriding our custom firmware
  sudo rm -f /mnt/etc/kernel/postinst.d/zz-flash-kernel
  sudo rm -f /mnt/etc/kernel/postrm.d/zz-flash-kernel
  sudo rm -f /mnt/etc/initramfs/post-update.d/flash-kernel

  # % Remove old configuration files that we are replacing with our new ones
  sudo rm -f /mnt/etc/rc.local
  sudo rm -f /mnt/etc/fstab
  #sudo rm -f /mnt/etc/resolv.conf
  sudo rm -f /mnt/etc/default/crda
  sudo rm -f /mnt/etc/hosts

  # Clear Python cache
  sudo find /mnt -regex '^.*\(__pycache__\|\.py[co]\)$' -delete

  sudo rm -rf /mnt/var/crash/*
  #sudo rm -rf /mnt/var/run/*

  sync; sync
  sleep "$SLEEP_LONG"
}

function AfterCleanIMG {
  echo "Cleaning IMG file (after)"

  # Clear Python cache
  sudo find /mnt -regex '^.*\(__pycache__\|\.py[co]\)$' -delete

  # % Remove any crash files generated
  sudo rm -rf /mnt/var/crash/*
  #sudo rm -rf /mnt/var/run/*

  # % Clear apt cache
  sudo rm -rf /mnt/var/lib/apt/ports* /mnt/var/lib/apt/*InRelease /mnt/var/lib/apt/*-en /mnt/var/lib/apt/*Packages
  
  sync; sync
  sleep "$SLEEP_LONG"
}

# INSTALL DEPENDENCIES
echo "Installing dependencies"
sudo apt-get update && sudo apt-get install git curl unzip build-essential libgmp-dev libmpfr-dev libmpc-dev libssl-dev bison flex kpartx qemu-user-static -y

PrepareIMG

# % Get Raspberry Pi 3 Ubuntu source image 
if [ ! -f "$SOURCE_IMGXZ" ]; then
  wget http://cdimage.ubuntu.com/ubuntu/releases/$SOURCE_RELEASE/release/$SOURCE_IMGXZ
fi

# % Extract and compact our source image from the xz if the source image isn't present
if [ ! -f "$SOURCE_IMG" ]; then
  xzcat "$SOURCE_IMGXZ" > "$SOURCE_IMG"
  MountIMG "$SOURCE_IMG"
  MountIMGPartitions "${MOUNT_IMG}"
  BeforeCleanIMG
  UnmountIMG "$SOURCE_IMG"
  CompactIMG "$SOURCE_IMG"
fi

# % Copy fresh copy of our source image to be our target image
if [ ! -f "$TARGET_IMG" ]; then
  sudo rm -f "$TARGET_IMG"
fi
cp -vf "$SOURCE_IMG" "$TARGET_IMG"
# % Expands the target image by approximately 300MB to help us not run out of space and encounter errors
truncate -s +609715200 "$TARGET_IMG"
sync; sync

# % Check for Raspbian image and download if not present
if [ ! -f "$RASPBIAN_IMG" ]; then
  curl -O -J -L https://downloads.raspberrypi.org/raspbian_lite_latest

  unzip raspbian_lite_latest
  rm -f raspbian_lite_latest
fi


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
  wget https://ftp.gnu.org/gnu/binutils/binutils-2.32.tar.bz2
  tar -xf binutils-2.32.tar.bz2
  mkdir binutils-2.32-build
  cd binutils-2.32-build
  ../binutils-2.32/configure --prefix="$TOOLCHAIN" --target=aarch64-linux-gnu --disable-nls
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
  git fetch --all
  git reset --hard origin/master
fi

# GET FIRMWARE
cd ~
if [ ! -d "firmware" ]; then
  git clone https://github.com/raspberrypi/firmware firmware --depth 1
else
  cd firmware
  git fetch --all
  git reset --hard origin/master
fi

# MAKE FIRMWARE BUILD DIR
cd ~
sudo rm -rf firmware-build
mkdir firmware-build
cp --recursive --update --archive --no-preserve=ownership ~/firmware-nonfree/* ~/firmware-build
cp --recursive --update --archive --no-preserve=ownership ~/firmware-raspbian/* ~/firmware-build
sudo rm -rf ~/firmware-build/.git 
sudo rm -rf ~/firmware-build/.github


# BUILD KERNEL
cd ~
if [ ! -d "rpi-linux" ]; then
  # % Check out the 4.19.y kernel branch -- if building and future versions are available you can update which branch is checked out here
  git clone https://github.com/raspberrypi/linux.git rpi-linux --single-branch --branch rpi-4.19.y --depth 1
  cd ~/rpi-linux
  git checkout origin/rpi-4.19.y
  rm -rf .git .git* .tmp_versions

  # CONFIGURE / MAKE
  PATH=$PATH:$TOOLCHAIN/bin make -j$(nproc) ARCH=arm64 CROSS_COMPILE=aarch64-linux-gnu- bcm2711_defconfig

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
  PATH=$PATH:$TOOLCHAIN/bin make -j$(nproc) ARCH=arm64 CROSS_COMPILE=aarch64-linux-gnu- prepare

  # % Prepare and build the rpi-linux source - create debian packages to make it easy to update the image
  PATH=$PATH:$TOOLCHAIN/bin make -j$(nproc) ARCH=arm64 CROSS_COMPILE=aarch64-linux-gnu- DTC_FLAGS="-@ -H epapr" LOCALVERSION=-james KDEB_PKGVERSION="${IMAGE_VERSION}" deb-pkg
  
  # % Build kernel modules
  PATH=$PATH:$TOOLCHAIN/bin make -j$(nproc) ARCH=arm64 CROSS_COMPILE=aarch64-linux-gnu- DEPMOD=echo MODLIB=./lib/modules/"${KERNEL_VERSION}" INSTALL_FW_PATH=./lib/firmware modules_install
  depmod --basedir . "${KERNEL_VERSION}"

  echo `cat ./include/generated/utsrelease.h | sed -e 's/.*"\(.*\)".*/\1/'`
fi


# PREPARE IMAGE
cd ~
MountIMG "$TARGET_IMG"

# Run fdisk
# % Get the starting offset of the root partition
PART_START=$(sudo parted "/dev/${MOUNT_IMG}" -ms unit s p | grep ":ext4" | cut -f 2 -d: | sed 's/[^0-9]//g')
# % Perform fdisk to correct the partition table
sudo fdisk "/dev/${MOUNT_IMG}" << EOF
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

UnmountIMG "$TARGET_IMG"
MountIMG "$TARGET_IMG"

# Run e2fsck
sudo e2fsck -fva "/dev/mapper/${MOUNT_IMG}p2"
sync; sync
sleep "$SLEEP_SHORT"
UnmountIMG "$TARGET_IMG"
MountIMG "$TARGET_IMG"

# Run resize2fs
sudo resize2fs "/dev/mapper/${MOUNT_IMG}p2"
sync; sync
sleep "$SLEEP_SHORT"
UnmountIMG "$TARGET_IMG"

# Compact image after our file operations
CompactIMG "$TARGET_IMG"
MountIMG "$TARGET_IMG"
MountIMGPartitions "${MOUNT_IMG}"


# CREATE FILES FOR UPDATER
cd ~
sudo rm -rf ~/updates
mkdir -p ~/updates/bootfs/overlays
mkdir -p ~/updates/rootfs/boot
mkdir -p ~/updates/rootfs/lib/firmware
mkdir -p ~/updates/rootfs/lib/modules/"${KERNEL_VERSION}"
mkdir -p ~/updates/rootfs/usr/src/rpi-linux-"${KERNEL_VERSION}"
cp --recursive --update --archive --no-preserve=ownership ~/firmware-build/* ~/updates/rootfs/lib/firmware
cp --recursive --update --archive --no-preserve=ownership ~/rpi-linux/lib/modules/* ~/updates/rootfs/lib/modules
cp --recursive --update --archive --no-preserve=ownership ~/rpi-source/* ~/updates/rootfs/usr/src/rpi-linux-"${KERNEL_VERSION}"
sync; sync
sleep "$SLEEP_SHORT"

# % Create cmdline.txt
cat << EOF | tee ~/updates/bootfs/cmdline.txt
snd_bcm2835.enable_headphones=1 snd_bcm2835.enable_hdmi=1 snd_bcm2835.enable_compat_alsa=0 dwc_otg.fiq_fix_enable=2 console=serial0,115200 console=tty1 root=/dev/mmcblk0p2 rootfstype=ext4 fsck.repair=yes fsck.mode=force rootwait
EOF

# % Create config.txt
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
cp --update --archive --no-preserve=ownership ~/rpi-linux/arch/arm64/boot/dts/broadcom/*.dtb ~/updates/bootfs
cp --update --archive --no-preserve=ownership ~/rpi-linux/arch/arm64/boot/dts/overlays/*.dtb* ~/updates/bootfs/overlays
cp -rf ~/rpi-linux/arch/arm64/boot/Image ~/updates/rootfs/boot/kernel8.img
cp -rf ~/rpi-linux/vmlinux ~/updates/rootfs/boot/vmlinux-"${KERNEL_VERSION}"
cp -rf ~/rpi-linux/System.map ~/updates/rootfs/boot/System.map-"${KERNEL_VERSION}"
cp -rf ~/rpi-linux/Module.symvers ~/updates/rootfs/boot/Module.symvers-"${KERNEL_VERSION}"
cp -vf ~/rpi-linux/.config ~/updates/rootfs/boot/config-"${KERNEL_VERSION}"
sync; sync
sleep "$SLEEP_SHORT"

# % Copy the new kernel modules
mkdir -p ~/updates/rootfs/lib/modules/"${KERNEL_VERSION}"
cp --update --archive --no-preserve=ownership ~/rpi-linux/lib/modules/* ~/updates/rootfs/lib/modules

# % Copy kernel and gpu firmware start*.elf and fixup*.dat files
cp --update --archive --no-preserve=ownership ~/firmware/boot/*.elf ~/updates/bootfs
cp --update --archive --no-preserve=ownership ~/firmware/boot/*.dat ~/updates/bootfs
cp --archive --no-preserve=ownership ~/rpi-linux/arch/arm64/boot/Image ~/updates/bootfs/kernel8.img
sync; sync
sleep "$SLEEP_SHORT"

# % Copy bootfs and rootfs
sudo cp --archive --no-preserve=ownership ~/updates/bootfs/* /mnt/boot/firmware
sudo cp --archive --no-preserve=ownership ~/updates/rootfs/* /mnt
sync; sync
sleep "$SLEEP_SHORT"

# % Remove initramfs actions for invalid existing kernels, then create a new link to our new custom kernel
sha1sum=$(sha1sum /mnt/boot/vmlinux)
sudo mkdir -p /mnt/var/lib/initramfs-tools
echo "$sha1sum  /boot/vmlinux-${KERNEL_VERSION}" | sudo tee -a /mnt/var/lib/initramfs-tools/"${KERNEL_VERSION}" >/dev/null;

# QUIRKS
cd ~

# % Fix WiFi
# % The Pi 4 version returns boardflags3=0x44200100
# % The Pi 3 version returns boardflags3=0x48200100cd
sudo sed -i "s:0x48200100:0x44200100:g" /mnt/lib/firmware/brcm/brcmfmac43455-sdio.txt

# % Disable ib_iser iSCSI cloud module to prevent an error during systemd-modules-load at boot
sudo sed -i "s/ib_iser/#ib_iser/g" /mnt/lib/modules-load.d/open-iscsi.conf
sudo sed -i "s/iscsi_tcp/#iscsi_tcp/g" /mnt/lib/modules-load.d/open-iscsi.conf

# % Fix update-initramfs mdadm.conf warning
sudo grep "ARRAY devices" /mnt/etc/mdadm/mdadm.conf >/dev/null || echo "ARRAY devices=/dev/sda" | sudo tee -a /mnt/etc/mdadm/mdadm.conf >/dev/null;

# CHROOT
# % Copy QEMU bin file so we can chroot into arm64 from x86_64
sudo cp -f /usr/bin/qemu-aarch64-static /mnt/usr/bin

# % Copy resolv.conf from local host so we have networking in our chroot
sudo mkdir -p /mnt/run/systemd/resolve
sudo touch /mnt/run/systemd/resolve/stub-resolv.conf
sudo cat /run/systemd/resolve/stub-resolv.conf | sudo tee /mnt/run/systemd/resolve/stub-resolv.conf >/dev/null;

# % Enter Ubuntu image chroot
echo "Entering chroot of IMG file"
sudo chroot /mnt /bin/bash << EOF

# % Pull kernel version from /lib/modules folder
export KERNEL_VERSION="$(ls /lib/modules)"

# % Fix /lib/firmware permission and symlink (fixes Bluetooth and firmware issues)
chown -R root:root /lib
ln -s /lib/firmware /etc/firmware

# % Create kernel and component symlinks
cd /boot
sudo rm -f vmlinux
sudo rm -f System.map
sudo rm -f Module.symvers
sudo ln -s vmlinux-"${KERNEL_VERSION}" vmlinux
sudo ln -s System.map-"${KERNEL_VERSION}" System.map
sudo ln -s Module.symvers-"${KERNEL_VERSION}" Module.symvers
sudo ln -s config-"${KERNEL_VERSION}" config

# % Create kernel header symlink
sudo rm -rf /lib/modules/"${KERNEL_VERSION}"/build 
sudo rm -rf /lib/modules/"${KERNEL_VERSION}"/source
sudo ln -s /usr/src/rpi-linux-"${KERNEL_VERSION}"/ /lib/modules/"${KERNEL_VERSION}"/build
sudo ln -s /usr/src/rpi-linux-"${KERNEL_VERSION}"/ /lib/modules/"${KERNEL_VERSION}"/source
cd /

# % Add updated mesa repository for video driver support
add-apt-repository ppa:ubuntu-x-swat/updates -yn

# % Add Raspberry Pi Userland repository
add-apt-repository ppa:ubuntu-raspi2/ppa -yn

# % Hold Ubuntu packages that will break booting from the Pi 4
apt-mark hold flash-kernel linux-raspi2 linux-image-raspi2 linux-headers-raspi2 linux-firmware-raspi2

# % Remove ureadahead, does not support arm and makes our bootup unclean when checking systemd status
apt remove ureadahead libnih1

# % Install wireless tools and bluetooth (wireless-tools, iw, rfkill, bluez)
# % Install Raspberry Pi userland utilities via libraspberrypi-bin (vcgencmd, etc.)
# % Install haveged - prevents low entropy issues from making the Pi take a long time to start up
# % Install raspi-config dependencies (libnewt0.52 whiptail parted triggerhappy lua5.1 alsa-utils)
# % Install dependencies to build Pi modules (git build-essential bc bison flex libssl-dev)
apt update && apt install wireless-tools iw rfkill bluez libraspberrypi-bin haveged libnewt0.52 whiptail parted triggerhappy lua5.1 alsa-utils build-essential git bc bison flex libssl-dev -y && apt dist-upgrade -y

# % Install raspi-config utility
wget "https://archive.raspberrypi.org/debian/pool/main/r/raspi-config/raspi-config_20191021_all.deb"
dpkg -i "raspi-config_20191021_all.deb"
rm "raspi-config_20191021_all.deb"
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
echo "The chroot container has exited"

# % Clean up after ourselves and remove qemu static binary
sudo rm -f /mnt/usr/bin/qemu-aarch64-static

# % Set regulatory crda to enable 5 Ghz wireless
sudo mkdir -p /mnt/etc/default
sudo touch /mnt/etc/default/crda
cat << EOF | sudo tee /mnt/etc/default/crda
# Set REGDOMAIN to a ISO/IEC 3166-1 alpha2 country code so that iw(8) may set
# the initial regulatory domain setting for IEEE 802.11 devices which operate
# on this system.
#
# Governments assert the right to regulate usage of radio spectrum within
# their respective territories so make sure you select a ISO/IEC 3166-1 alpha2
# country code suitable for your location or you may infringe on local
# legislature. See /usr/share/zoneinfo/zone.tab for a table of timezone
# descriptions containing ISO/IEC 3166-1 alpha2 country codes.

REGDOMAIN=US
EOF

# % Set loopback address in hosts to prevent slow bootup
sudo touch /mnt/etc/hosts
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
sudo touch /mnt/etc/fstab
cat << EOF | sudo tee /mnt/etc/fstab
LABEL=writable	/	 ext4	defaults	0 1
LABEL=system-boot       /boot/firmware  vfat    defaults        0       1
EOF

# % Startup tweaks to fix bluetooth and sound issues
sudo touch /mnt/etc/rc.local
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

# % Store current release in home folder
sudo echo "$IMAGE_VERSION" > /mnt/etc/imgrelease

# Run the after clean function
AfterCleanIMG

# Run fsck on image then unmount and remount
UnmountIMGPartitions
sudo fsck.ext4 -pfv "/dev/mapper/${MOUNT_IMG}p2"
sudo fsck.fat -av "/dev/mapper/${MOUNT_IMG}p1"
UnmountIMG "$TARGET_IMG"
CompactIMG "$TARGET_IMG"

# Clean up build directory
#sudo rm -rf updates firmware-build tmp
echo "Build completed"

