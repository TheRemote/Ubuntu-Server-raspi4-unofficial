#!/bin/bash
#
# More information available at:
# https://jamesachambers.com/raspberry-pi-4-ubuntu-server-desktop-18-04-3-image-unofficial/
# https://github.com/TheRemote/Ubuntu-Server-raspi4-unofficial

# CONFIGURATION

IMAGE_VERSION="15"

TARGET_IMGXZ="ubuntu-18.04.3-preinstalled-server-arm64+raspi4.img.xz"
TARGET_IMG="ubuntu-18.04.3-preinstalled-server-arm64+raspi4.img"
SOURCE_RELEASE="18.04.3"
SOURCE_IMGXZ="ubuntu-18.04.3-preinstalled-server-arm64+raspi3.img.xz"
SOURCE_IMG="ubuntu-18.04.3-preinstalled-server-arm64+raspi3.img"
RASPBIAN_IMG="2019-09-26-raspbian-buster-lite.img"
RASPICFG_PACKAGE="raspi-config_20191021_all.deb"

export SLEEP_SHORT="0.1"
export SLEEP_LONG="1"

export MOUNT_IMG=""
export KERNEL_VERSION="4.19.80-v8"

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

  # Enter chroot to remove some packages
  sudo cp -f /usr/bin/qemu-aarch64-static /mnt/usr/bin
  # % Remove incompatible RPI firmware / headers / modules
  sudo chroot /mnt /bin/bash << EOF
  apt purge linux-raspi2 linux-image-raspi2 linux-headers-raspi2 linux-firmware-raspi2 -y
EOF

  sudo rm -rf /mnt/boot/firmware/*
  sudo rm -rf /mnt/boot/initrd*
  sudo rm -rf /mnt/boot/config*
  sudo rm -rf /mnt/boot/vmlinu*
  sudo rm -rf /mnt/boot/System.map*

  #sudo rm -rf /mnt/lib/firmware/*
  sudo rm -rf /mnt/lib/modules/*

  sudo rm -rf /mnt/usr/src/*
  sudo rm -rf /mnt/usr/lib/linux-firmware-raspi2

  sudo rm -rf /mnt/var/log/*.gz /mnt/var/log/*.log*
  sudo rm -rf /mnt/var/lib/initramfs-tools/*
  sudo rm -rf /mnt/var/lib/apt/lists/ports* /mnt/var/lib/apt/lists/*InRelease /mnt/var/lib/apt/lists/*-en /mnt/var/lib/apt/lists/*Packages

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

  # Remove any crash files generated
  sudo rm -rf /mnt/var/crash/*
  #sudo rm -rf /mnt/var/run/*
  sudo rm -rf /mnt/root/*

  sync; sync
  sleep "$SLEEP_LONG"
}

function AfterCleanIMG {
  echo "Cleaning IMG file (after)"

  # Clear apt cache
  sudo rm -rf /mnt/var/lib/apt/lists/ports* /mnt/var/lib/apt/lists/*InRelease /mnt/var/lib/apt/lists/*-en /mnt/var/lib/apt/lists/*Packages

  # Clear Python cache
  sudo find /mnt -regex '^.*\(__pycache__\|\.py[co]\)$' -delete

  # Remove any crash files generated
  sudo rm -rf /mnt/var/crash/*
  #sudo rm -rf /mnt/var/run/*
  sudo rm -rf /mnt/root/*

  sync; sync
  sleep "$SLEEP_LONG"
}

# Checks git to see if we have updates
function CheckGitUpdates {
  git remote update > /dev/null
  git pull > /dev/null

  if [ ! -z "$(git status --porcelain)" ]; then
    echo "Local files modified"
    return 0
  fi

  UPSTREAM=${1:-'@{u}'}
  LOCAL=$(git rev-parse @)
  REMOTE=$(git rev-parse "$UPSTREAM")
  BASE=$(git merge-base @ "$UPSTREAM")

  if [ $LOCAL = $REMOTE ]; then
    # Up to date
    echo "Up to date"
    return 1
  elif [ $LOCAL = $BASE ]; then
    # Need to pull
    echo "Need to pull"
    return 0
  elif [ $REMOTE = $BASE ]; then
    # Need to push
    echo "Need to push"
    return 0
  else
    echo "Diverged"
    # Diverged
    return 0
  fi
}

function SetGitTimestamps {
  for FILE in $(git ls-files); do     
    TIME=$(git log --pretty=format:%cd -n 1 --date=iso -- "$FILE");     
    TIME=$(date --date="$TIME" +%Y%m%d%H%M.%S);     
    touch -m -t "$TIME" "$FILE"; 
  done
}

# INSTALL DEPENDENCIES
echo "Installing dependencies"
#sudo apt-get install git curl unzip build-essential libgmp-dev libmpfr-dev libmpc-dev libssl-dev bison flex kpartx qemu-user-static -y

# PREPARE IMAGE
PrepareIMG

# % Get Raspberry Pi 3 Ubuntu source image 
if [ ! -f "$SOURCE_IMGXZ" ]; then
  wget http://cdimage.ubuntu.com/ubuntu/releases/$SOURCE_RELEASE/release/$SOURCE_IMGXZ
fi

# % Extract and compact our source image from the xz if the source image isn't present
if [ ! -f "$SOURCE_IMG" ]; then
  xzcat --threads=0 "$SOURCE_IMGXZ" > "$SOURCE_IMG"
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
truncate -s +809715200 "$TARGET_IMG"
sync; sync

# % Check for Raspbian image and download if not present
if [ ! -f "$RASPBIAN_IMG" ]; then
  curl -O -J -L https://downloads.raspberrypi.org/raspbian_lite_latest

  unzip raspbian_lite_latest
  rm -f raspbian_lite_latest
fi


# GET USERLAND
cd ~
if [ ! -d "userland" ]; then
  git clone https://github.com/raspberrypi/userland userland --single-branch --branch=master --depth=1
  cd userland
else
  cd userland
  if CheckGitUpdates; then
    git reset --hard origin/master
  fi
fi
./buildme --aarch64

# GET FIRMWARE NON-FREE
cd ~
if [ ! -d "firmware-nonfree" ]; then
  git clone https://github.com/RPi-Distro/firmware-nonfree firmware-nonfree --single-branch --branch=master
  cd firmware-nonfree
  SetGitTimestamps
else
  cd firmware-nonfree
  if CheckGitUpdates; then
    git reset --hard origin/master
    SetGitTimestamps
  fi
fi

# GET FIRMWARE
cd ~
if [ ! -d "firmware" ]; then
  git clone https://github.com/raspberrypi/firmware firmware --single-branch --branch=master
  cd firmware
  SetGitTimestamps
else
  cd firmware
  if CheckGitUpdates; then
    git reset --hard origin/master
    SetGitTimestamps
  fi
fi

# MAKE FIRMWARE BUILD DIR
cd ~
sudo rm -rf firmware-build
mkdir firmware-build
cp --recursive --update --archive --no-preserve=ownership ~/firmware-ubuntu-1910/* ~/firmware-build
cp --recursive --update --archive --no-preserve=ownership ~/firmware-nonfree/* ~/firmware-build
cp --recursive --update --archive --no-preserve=ownership ~/firmware-raspbian/* ~/firmware-build
sudo rm -rf ~/firmware-build/.git 
sudo rm -rf ~/firmware-build/.github
sudo rm -rf ~/firmware-build/raspberrypi
cd ~/firmware-ubuntu-1804
# Remove duplicate files that are already in 1804 and haven't changed
for f in $(find -L . -type f -print); do
  if [ -f "$f" ] && [ ! -L "$f" ]; then
    File1Hash=$(sha1sum "$f" | cut -d" " -f1 | xargs)
    if [ -f "../firmware-build/$f" ]; then
      File2Hash=$(sha1sum "../firmware-build/$f" | cut -d" " -f1 | xargs)
      if [ "$File1Hash" == "$File2Hash" ]; then
        rm -rf "../firmware-build/$f"
      fi
    fi
  fi
done
cd ~/firmware-build
# Remove empty folders
for f in $(find -L . -type d -empty -print); do
  if [ -d "$f" ] && [ ! -L "$f" ]; then
    rmdir "$f"
  fi
done
# Remove broken symbolic links
find . -xtype l -delete
cd ~


# BUILD KERNEL
cd ~
if [ ! -d "rpi-linux" ]; then
  # % Check out the 4.19.y kernel branch -- if building and future versions are available you can update which branch is checked out here
  git clone https://github.com/raspberrypi/linux.git rpi-linux --single-branch --branch rpi-4.19.y --depth 1
  cd ~/rpi-linux
  git checkout origin/rpi-4.19.y

  # CONFIGURE / MAKE
  PATH=/opt/cross-pi-gcc-9.1.0-64/bin:$PATH LD_LIBRARY_PATH=/opt/cross-pi-gcc-9.1.0-64/lib:$LD_LIBRARY_PATH make -j$(nproc) ARCH=arm64 CROSS_COMPILE=aarch64-linux-gnu- bcm2711_defconfig

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
  #rm -f .config
  #wget https://raw.githubusercontent.com/TheRemote/Ubuntu-Server-raspi4-unofficial/master/.config

  # % Run prepare to register all our .config changes
  cd ~/rpi-linux
  PATH=/opt/cross-pi-gcc-9.1.0-64/bin:$PATH LD_LIBRARY_PATH=/opt/cross-pi-gcc-9.1.0-64/lib:$LD_LIBRARY_PATH make -j$(nproc) ARCH=arm64 CROSS_COMPILE=aarch64-linux-gnu- prepare

  # % Prepare and build the rpi-linux source - create debian packages to make it easy to update the image
  PATH=/opt/cross-pi-gcc-9.1.0-64/bin:$PATH LD_LIBRARY_PATH=/opt/cross-pi-gcc-9.1.0-64/lib:$LD_LIBRARY_PATH make -j$(nproc) ARCH=arm64 CROSS_COMPILE=aarch64-linux-gnu- DTC_FLAGS="-@ -H epapr" LOCALVERSION=-james KDEB_PKGVERSION="${IMAGE_VERSION}" deb-pkg
  
  # % Build kernel modules
  PATH=/opt/cross-pi-gcc-9.1.0-64/bin:$PATH LD_LIBRARY_PATH=/opt/cross-pi-gcc-9.1.0-64/lib:$LD_LIBRARY_PATH sudo make -j$(nproc) ARCH=arm64 CROSS_COMPILE=aarch64-linux-gnu- DEPMOD=echo MODLIB=./lib/modules/"${KERNEL_VERSION}" INSTALL_FW_PATH=./lib/firmware modules_install
  sudo depmod --basedir . "${KERNEL_VERSION}"
  sudo chown -R "$SUDO_USER" .

  echo `cat ./include/generated/utsrelease.h | sed -e 's/.*"\(.*\)".*/\1/'`
fi

# PREPARE DISTRIBUTED SOURCE TREE
cd ~
if [ ! -d "rpi-source" ]; then
  tar -xf *.orig.tar.gz
  mv linux*-james/ rpi-source
  cp -f ~/rpi-linux/.config .config
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
mkdir -p ~/updates/rootfs/home
mkdir -p ~/updates/rootfs/usr/bin
mkdir -p ~/updates/rootfs/usr/lib/aarch64-linux-gnu
mkdir -p ~/updates/rootfs/usr/lib/"${KERNEL_VERSION}"/overlays
mkdir -p ~/updates/rootfs/usr/lib/"${KERNEL_VERSION}"/broadcom
mkdir -p ~/updates/rootfs/lib/firmware
mkdir -p ~/updates/rootfs/lib/modules/"${KERNEL_VERSION}"
mkdir -p ~/updates/rootfs/include/interface/vcos/generic
mkdir -p ~/updates/rootfs/usr/src/rpi-linux-"${KERNEL_VERSION}"
cp --recursive --update --archive --no-preserve=ownership ~/firmware-build/* ~/updates/rootfs/lib/firmware
cp --recursive --update --archive --no-preserve=ownership ~/rpi-linux/lib/modules/* ~/updates/rootfs/lib/modules
cp --recursive --update --archive --no-preserve=ownership ~/rpi-source/* ~/updates/rootfs/usr/src/rpi-linux-"${KERNEL_VERSION}"

sync; sync
sleep "$SLEEP_SHORT"

# % Copy overlays / image / firmware
cp -rf ~/rpi-linux/arch/arm64/boot/dts/broadcom/*.dtb ~/updates/bootfs
cp -rf ~/rpi-linux/arch/arm64/boot/dts/overlays/*.dtb* ~/updates/bootfs/overlays
cp -rf ~/rpi-linux/arch/arm64/boot/dts/broadcom/*.dtb ~/updates/rootfs/usr/lib/"${KERNEL_VERSION}"/overlays
cp -rf ~/rpi-linux/arch/arm64/boot/dts/overlays/*.dtb* ~/updates/rootfs/usr/lib/"${KERNEL_VERSION}"/broadcom

# % Unmount and copy firmware copy to overlapping firmware folder
while mountpoint -q /mnt/boot/firmware && ! sudo umount /mnt/boot/firmware; do
  sync; sync
  sleep "$SLEEP_SHORT"
done
sudo cp -rf ~/firmware/boot/*.elf /mnt/boot/firmware/
sudo cp -rf ~/firmware/boot/*.dat /mnt/boot/firmware/
sudo mount "/dev/mapper/${MOUNT_IMG}p1" /mnt/boot/firmware

cp -rf ~/rpi-linux/arch/arm64/boot/Image ~/updates/rootfs/boot/kernel8.img
cp -rf ~/rpi-linux/vmlinux ~/updates/rootfs/boot/vmlinux-"${KERNEL_VERSION}"
cp -rf ~/rpi-linux/System.map ~/updates/rootfs/boot/System.map-"${KERNEL_VERSION}"
cp -rf ~/rpi-linux/Module.symvers ~/updates/rootfs/boot/Module.symvers-"${KERNEL_VERSION}"
cp -rf ~/rpi-linux/Module.symvers ~/updates/rootfs/usr/src/rpi-linux-"${KERNEL_VERSION}"/Module.symvers
cp -rf ~/rpi-linux/.config ~/updates/rootfs/boot/config-"${KERNEL_VERSION}"
sync; sync
sleep "$SLEEP_SHORT"

# % Copy the new kernel modules
echo "Installing kernel modules ..."
cp -rf ~/rpi-linux/lib/modules/* ~/updates/rootfs/lib/modules
cp -rf ~/rpi-linux/arch/arm64/boot/dts/broadcom/*.dtb ~/updates/bootfs
cp -rf ~/rpi-linux/arch/arm64/boot/dts/overlays/*.dtb* ~/updates/bootfs/overlays

# % Copy new Raspberry Pi userland
cp -rf ~/userland/build/bin/* ~/updates/rootfs/usr/bin
cp -rf ~/userland/build/lib/* ~/updates/rootfs/usr/lib/aarch64-linux-gnu
cp -rf ~/userland/build/inc/* ~/updates/rootfs/include

# % Copy kernel and gpu firmware start*.elf and fixup*.dat files
cp -rf ~/firmware/boot/*.elf ~/updates/bootfs
cp -rf ~/firmware/boot/*.dat ~/updates/bootfs

cp -rf ~/rpi-linux/arch/arm64/boot/Image ~/updates/bootfs/kernel8.img
sync; sync
sleep "$SLEEP_SHORT"

# % Copy updater script into home folder
sudo cp -f ~/Updater.sh ~/updates/rootfs/home/Updater.sh

# % Create cmdline.txt
cat << EOF | tee ~/updates/bootfs/cmdline.txt
snd_bcm2835.enable_headphones=1 snd_bcm2835.enable_hdmi=1 snd_bcm2835.enable_compat_alsa=0 dwc_otg.lpm_enable=0 console=serial0,115200 console=tty1 fsck.repair=yes fsck.mode=auto root=/dev/mmcblk0p2 rootfstype=ext4 elevator=deadline rootwait
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

# Uncomment some or all of these to enable the optional hardware interfaces
dtparam=i2c_arm=on
dtparam=spi=on
#dtparam=i2s=on

# Uncomment this to enable infrared communication.
#dtoverlay=gpio-ir,gpio_pin=17
#dtoverlay=gpio-ir-tx,gpio_pin=18

# Enable audio (loads snd_bcm2835)
dtparam=audio=on

[pi4]
dtoverlay=vc4-fkms-v3d
max_framebuffers=2
arm_64bit=1
#device_tree_address=0x03000000

[all]
#dtoverlay=vc4-fkms-v3d
EOF

# % Copy bootfs and rootfs
sudo cp -rf ~/updates/bootfs/* /mnt/boot/firmware
sudo cp -rf ~/updates/rootfs/* /mnt
sync; sync
sleep "$SLEEP_SHORT"

# % Remove initramfs actions for invalid existing kernels, then create a new link to our new custom kernel
sha1sum=$(sha1sum /mnt/boot/vmlinux-"${KERNEL_VERSION}")
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
#sudo grep "ARRAY devices" /mnt/etc/mdadm/mdadm.conf >/dev/null || echo "ARRAY devices=/dev/sda" | sudo tee -a /mnt/etc/mdadm/mdadm.conf >/dev/null;

# % Copy resolv.conf from local host so we have networking in our chroot
sudo mkdir -p /mnt/run/systemd/resolve
sudo touch /mnt/run/systemd/resolve/stub-resolv.conf
sudo cat /run/systemd/resolve/stub-resolv.conf | sudo tee /mnt/run/systemd/resolve/stub-resolv.conf >/dev/null;

# Add proposed apt archive
cat << EOF | sudo tee /mnt/etc/apt/sources.list
deb http://ports.ubuntu.com/ubuntu-ports bionic-proposed main restricted multiverse universe
deb http://ports.ubuntu.com/ubuntu-ports bionic main restricted multiverse universe
deb http://ports.ubuntu.com/ubuntu-ports bionic-security main restricted multiverse universe
deb http://ports.ubuntu.com/ubuntu-ports bionic-updates main restricted multiverse universe
deb http://ports.ubuntu.com/ubuntu-ports bionic-backports main restricted multiverse universe
EOF

sudo touch /mnt/etc/apt/preferences.d/proposed-updates 
cat << EOF | sudo tee /mnt/etc/apt/preferences.d/proposed-updates 
Package: *
Pin: release a=bionic-proposed
Pin-Priority: 400
EOF

# Fix netplan
sudo rm -f /mnt/etc/netplan/50-cloud-init.yaml
sudo touch /mnt/etc/netplan/50-cloud-init.yaml
cat << EOF | sudo tee /mnt/etc/netplan/50-cloud-init.yaml
network:
    ethernets:
        eth0:
            dhcp4: true
            optional: true
    version: 2
EOF

# Add proposed apt archive
cat << EOF | sudo tee /mnt/etc/apt/sources.list
deb http://ports.ubuntu.com/ubuntu-ports bionic-proposed main restricted multiverse universe
deb http://ports.ubuntu.com/ubuntu-ports bionic main restricted multiverse universe
deb http://ports.ubuntu.com/ubuntu-ports bionic-security main restricted multiverse universe
deb http://ports.ubuntu.com/ubuntu-ports bionic-updates main restricted multiverse universe
deb http://ports.ubuntu.com/ubuntu-ports bionic-backports main restricted multiverse universe
EOF

sudo touch /mnt/etc/apt/preferences.d/proposed-updates
cat << EOF | sudo tee -a /mnt/etc/apt/preferences.d/proposed-updates 
Package: *
Pin: release a=bionic-proposed
Pin-Priority: 400
EOF

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
sudo rm -f config
sudo ln -s initrd.img-"${KERNEL_VERSION}" initrd.img
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
#add-apt-repository ppa:ubuntu-raspi2/ppa -ynr


# % Install wireless tools and bluetooth (wireless-tools, iw, rfkill, bluez)
# % Install haveged - prevents low entropy issues from making the Pi take a long time to start up
# % Install raspi-config dependencies (libnewt0.52 whiptail parted triggerhappy lua5.1 alsa-utils)
# % Install dependencies to build Pi modules (git build-essential bc bison flex libssl-dev device-tree-compiler)
# % Install curl and unzip utilities
apt update && apt install curl unzip wireless-tools iw rfkill bluez haveged libnewt0.52 whiptail parted triggerhappy lua5.1 alsa-utils git bc bison flex libssl-dev -y && apt dist-upgrade -y

# % Install raspi-config utility
rm -f "$RASPICFG_PACKAGE"
wget "https://archive.raspberrypi.org/debian/pool/main/r/raspi-config/${RASPICFG_PACKAGE}"
dpkg -i "$RASPICFG_PACKAGE"
rm -f "raspi-config_20191021_all.deb"
sed -i "s:/boot/config.txt:/boot/firmware/config.txt:g" /usr/bin/raspi-config
sed -i "s:/boot/cmdline.txt:/boot/firmware/cmdline.txt:g" /usr/bin/raspi-config
sed -i "s:armhf:arm64:g" /usr/bin/raspi-config
sed -i "s:/boot/overlays:/boot/firmware/overlays:g" /usr/bin/raspi-config
sed -i "s:/boot/start:/boot/firmware/start:g" /usr/bin/raspi-config
sed -i "s:/boot/arm:/boot/firmware/arm:g" /usr/bin/raspi-config
sed -i "s:/boot :/boot/firmware :g" /usr/bin/raspi-config
sed -i "s:\\/boot\.:\\/boot\\\/firmware\.:g" /usr/bin/raspi-config
sed -i 's:dtparam i2c_arm=$SETTING:dtparam -d /boot/firmware/overlays i2c_arm=$SETTING:g' /usr/bin/raspi-config
sed -i 's:dtparam spi=$SETTING:dtparam -d /boot/firmware/overlays spi=$SETTING:g' /usr/bin/raspi-config
sed -i "s:/boot/cmdline.txt:/boot/firmware/cmdline.txt:g" /usr/lib/raspi-config/init_resize.sh
sed -i "s:/boot/config.txt:/boot/firmware/config.txt:g" /usr/lib/raspi-config/init_resize.sh
sed -i "s: /boot/ : /boot/firmware/ :g" /usr/lib/raspi-config/init_resize.sh
sed -i "s:mount /boot:mount /boot/firmware:g" /usr/lib/raspi-config/init_resize.sh
sed -i "s:su pi:su $SUDO_USER:g" /usr/bin/dtoverlay-pre
sed -i "s:su pi:su $SUDO_USER:g" /usr/bin/dtoverlay-post

# % Apply modified netplan settings
sudo netplan generate 
sudo netplan --debug apply

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
LABEL=writable   /   ext4   defaults   0    1
LABEL=system-boot       /boot/firmware  vfat    defaults        0       1
EOF

# % Startup tweaks to fix bluetooth and sound issues
sudo touch /mnt/etc/rc.local
cat << EOF | sudo tee /mnt/etc/rc.local
#!/bin/bash
#
# rc.local
#

# Fix sound
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
sudo touch /mnt/etc/imgrelease
echo "$IMAGE_VERSION" | sudo tee /mnt/etc/imgrelease >/dev/null;

# Run the after clean function
AfterCleanIMG

# Run fsck on image then unmount and remount
UnmountIMGPartitions
sudo fsck.ext4 -pfv "/dev/mapper/${MOUNT_IMG}p2"
sudo fsck.fat -av "/dev/mapper/${MOUNT_IMG}p1"
UnmountIMG "$TARGET_IMG"
CompactIMG "$TARGET_IMG"

# Compress img into xz file
echo "Compressing final img.xz file ..."
sleep "$SLEEP_SHORT"
sudo rm -f "$TARGET_IMGXZ"
xz -9 --extreme --force --keep --threads=0 --quiet "$TARGET_IMG"

# Compress our updates used for the autoupdater
echo "Compressing updates.tar.gz ..."
sudo rm -f ~/updates.tar.gz
tar -cpJf updates.tar.xz updates/

echo "Build completed"

