#!/bin/bash
#
# WARNING: This script is meant to be ran in a *throwaway* Ubuntu 18.04.3 Virtual Machine (VM)
# - Absolutely no steps have been taken to make the process "secure" or "safe" for your main machine
# - It assumes the home directory is safe to build in (it's not on a main system)
# - It installs hundreds of development packages that you only need to build the image (would bog down a main system)
# - It chroots into at least 4 different images during the build and chroots leak (causing instability/security concerns)
# - If things go wrong with the type of commands used in the script your system can get borked *real quick* (like instantly)
# As long as you follow this warning the script is fairly painless to work with!
#
# More information available at:
# https://jamesachambers.com/raspberry-pi-4-ubuntu-server-desktop-18-04-3-image-unofficial/
# https://github.com/TheRemote/Ubuntu-Server-raspi4-unofficial

# CONFIGURATION

IMAGE_VERSION="25"
SOURCE_RELEASE="18.04.3"

TARGET_IMG="ubuntu-18.04.3-preinstalled-server-arm64+raspi4.img"
TARGET_IMGXZ="ubuntu-18.04.3-preinstalled-server-arm64+raspi4.img.xz"
DESKTOP_IMGXZ="ubuntu-18.04.3-preinstalled-desktop-arm64+raspi4.img.xz"
DESKTOP_IMG="ubuntu-18.04.3-preinstalled-desktop-arm64+raspi4.img"
SOURCE_IMG="ubuntu-18.04.3-preinstalled-server-arm64+raspi3.img"
SOURCE_IMGXZ="ubuntu-18.04.3-preinstalled-server-arm64+raspi3.img.xz"
RASPBIAN_IMG="2019-09-26-raspbian-buster-lite.img"
RASPBIAN_IMGZIP="2019-09-26-raspbian-buster-lite.img.zip"
UBUNTU_IMG="ubuntu-19.10-preinstalled-server-arm64+raspi3.img"
UBUNTU_IMGXZ="ubuntu-19.10-preinstalled-server-arm64+raspi3.img.xz"

export SLEEP_SHORT="0.1"
export SLEEP_LONG="1"

export MOUNT_IMG=""
export KERNEL_VERSION=""

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
  if [ -d "/mnt/boot/firmware" ]; then
    sudo mount "/dev/mapper/${1}p1" /mnt/boot/firmware
  else
    sudo mount "/dev/mapper/${1}p1" /mnt/boot
  fi

  sync; sync
  sleep "$SLEEP_SHORT"
}

function UnmountIMGPartitions {
  sync; sync

  # % Unmount boot and root partitions
  echo "Unmounting partitions ..."
  while mountpoint -q /mnt/boot/firmware && ! sudo umount /mnt/boot/firmware; do
    sync; sync
    sleep "$SLEEP_SHORT"
  done

  while mountpoint -q /mnt/boot && ! sudo umount /mnt/boot; do
    sync; sync
    sleep "$SLEEP_SHORT"
  done

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
  sudo rm -rf "${1}.2"
  sudo virt-sparsify "${1}" "${1}.2"
  sync; sync
  sleep "$SLEEP_SHORT"
  
  sudo rm -rf "${1}"
  mv "${1}.2" "${1}"
  sync; sync
  sleep "$SLEEP_SHORT"
}

function BeforeCleanIMG {
  echo "Cleaning IMG file (before)"

  # % Remove flash-kernel hooks to prevent firmware updater from overriding our custom firmware
  sudo rm -rf /mnt/etc/kernel/postinst.d/zz-flash-kernel
  sudo rm -rf /mnt/etc/kernel/postrm.d/zz-flash-kernel
  sudo rm -rf /mnt/etc/initramfs/post-update.d/flash-kernel

  # Copy resolv.conf for chroot
  sudo mkdir -p /mnt/run/systemd/resolve
  sudo touch /mnt/run/systemd/resolve/stub-resolv.conf
  sudo cat /run/systemd/resolve/stub-resolv.conf | sudo tee /mnt/run/systemd/resolve/stub-resolv.conf >/dev/null;

  # Prepare chroot
  sudo cp -f /usr/bin/qemu-aarch64-static /mnt/usr/bin
  
  # % Remove incompatible RPI firmware / headers / modules
  sudo chroot /mnt /bin/bash << EOF
  apt purge linux-raspi2 linux-image-raspi2 linux-headers-raspi2 linux-firmware-raspi2 ureadahead libnih1 -y
  apt update && apt dist-upgrade -y
EOF

  sudo rm -rf /mnt/boot/firmware/*
  sudo rm -rf /mnt/boot/initrd*
  sudo rm -rf /mnt/boot/config*
  sudo rm -rf /mnt/boot/vmlinu*
  sudo rm -rf /mnt/boot/System.map*

  sudo rm -rf /mnt/lib/firmware/*
  sudo rm -rf /mnt/lib/modules/*

  sudo rm -rf /mnt/usr/src/*
  sudo rm -rf /mnt/usr/lib/linux-firmware-raspi2

  sudo rm -rf /mnt/var/log/*.gz /mnt/var/log/*.log*
  sudo rm -rf /mnt/var/lib/initramfs-tools/*
  sudo rm -rf /mnt/var/lib/apt/lists/ports* /mnt/var/lib/apt/lists/*InRelease /mnt/var/lib/apt/lists/*-en /mnt/var/lib/apt/lists/*Packages

  # % Remove old configuration files that we are replacing with our new ones
  sudo rm -rf /mnt/etc/rc.local
  sudo rm -rf /mnt/etc/fstab
  sudo rm -rf /mnt/etc/default/crda
  sudo rm -rf /mnt/etc/hosts

  # Clear Python cache
  sudo find /mnt -regex '^.*\(__pycache__\|\.py[co]\)$' -delete

  # Remove any crash files generated
  sudo rm -rf /mnt/var/crash/*
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
  sudo rm -rf /mnt/root/*

  # Remove machine ID so all clones don't have the same one
  sudo rm -rf /mnt/etc/machine-id
  sudo touch /mnt/etc/machine-id

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

function UpdateIMG {
  # % Remove flash-kernel hooks to prevent update failure for "Unsupported Platform"
  sudo rm -rf /mnt/etc/kernel/postinst.d/zz-flash-kernel
  sudo rm -rf /mnt/etc/kernel/postrm.d/zz-flash-kernel
  sudo rm -rf /mnt/etc/initramfs/post-update.d/flash-kernel

  # Copy resolv.conf for chroot
  sudo mkdir -p /mnt/run/systemd/resolve
  sudo touch /mnt/run/systemd/resolve/stub-resolv.conf
  sudo cat /run/systemd/resolve/stub-resolv.conf | sudo tee /mnt/run/systemd/resolve/stub-resolv.conf >/dev/null;

  # Prepare chroot
  if [ -d "/mnt/boot/firmware" ]; then
    sudo cp -f /usr/bin/qemu-aarch64-static /mnt/usr/bin
  else
    sudo cp -f /usr/bin/qemu-arm-static /mnt/usr/bin
  fi
  
  # % Remove incompatible RPI firmware / headers / modules
  sudo chroot /mnt /bin/bash << EOF
  apt update && apt dist-upgrade -y
EOF
}

function ShrinkIMG {
  MountIMG $1

  tune2fs_output=$(sudo tune2fs -l "/dev/mapper/${MOUNT_IMG}p2")
  currentsize=$(echo "$tune2fs_output" | grep '^Block count:' | tr -d ' ' | cut -d ':' -f 2)
  blocksize=$(echo "$tune2fs_output" | grep '^Block size:' | tr -d ' ' | cut -d ':' -f 2)
  minsize=$(sudo resize2fs -P "/dev/mapper/${MOUNT_IMG}p2" | tr -d ' ' | cut -d ':' -f 2)
  extra_space=$(($currentsize - $minsize))

  beforesize=$(ls -lh "$1" | cut -d ' ' -f 5)
  parted_output=$(sudo parted -ms "$1" unit B print | tail -n 1)
  partnum=$(echo "$parted_output" | cut -d ':' -f 1)
  partstart=$(echo "$parted_output" | cut -d ':' -f 2 | tr -d 'B')
  
  # Add 10000 blocks of free space
  minsize=$(( $minsize + 10000 ))

  sudo resize2fs -fp "/dev/mapper/${MOUNT_IMG}p2" $minsize

  UnmountIMG "$1"

  partnewsize=$(($minsize * $blocksize))
  newpartend=$(($partstart + $partnewsize))

  if ! sudo parted -s -a minimal "$1" rm "$partnum"; then
    rc=$?
    echo "parted failed: $rc"
    return
  fi

  if ! sudo parted -s "$1" unit B mkpart primary "$partstart" "$newpartend"; then
    rc=$?
    echo "parted failed: $rc"
    return
  fi

  #Truncate the file
  if ! endresult=$(sudo parted -ms "$1" unit B print free); then
    rc=$?
    echo "parted failed: $rc"
    return
  fi

  endresult=$(tail -1 <<< "$endresult" | cut -d ':' -f 2 | tr -d 'B')
  if ! sudo truncate -s "$endresult" "$1"; then
    rc=$?
    echo "truncate failed: $rc"
    return
  fi

  MountIMG "$1"

  # Run e2fsck
  echo "Running e2fsck"
  sudo fsck.ext4 -pfv "/dev/mapper/${MOUNT_IMG}p2"
  sync; sync
  sleep "$SLEEP_SHORT"
  UnmountIMG "$1"

  CompactIMG $1
}

##################################################################################################################

# Get crosschain toolkit
cd ~
if [ ! -d "/opt/cross-pi-gcc-9.2.0-64" ]; then
  # Install dependencies
  echo "Installing dependencies"
  sudo apt-get install git curl unzip build-essential libgmp-dev libmpfr-dev libmpc-dev libssl-dev bison flex kpartx libguestfs-tools gawk gcc g++ gfortran cmake texinfo libncurses-dev pkg-config -y

  curl --location "https://sourceforge.net/projects/raspberry-pi-cross-compilers/files/latest/download" --output "cross-pi-gcc-9.2.0-64.tar.gz"
  tar -xf "cross-pi-gcc-9.2.0-64.tar.gz"
  rm -rf "cross-pi-gcc-9.2.0-64.tar.gz"
  sudo mv cross-pi-gcc-9.2.0-64 /opt
fi

# Get latest QEMU
cd ~
if [ ! -d "qemu" ]; then
  sudo apt-get build-dep qemu -y
  git clone https://git.qemu.org/git/qemu.git --single-branch --depth=1
  cd ~/qemu
  git submodule init
  git submodule update --recursive
  ./configure --static --target-list=aarch64-linux-user,arm-linux-user
  make -j$(nproc)
  cd aarch64-linux-user
  sudo cp -f qemu-aarch64 qemu-aarch64-static
  sudo cp -f qemu-aarch64-static /usr/bin
  cd ..
  cd arm-linux-user
  sudo cp -f qemu-arm qemu-arm-static
  sudo cp -f qemu-arm-static /usr/bin
fi

# PREPARE IMAGE
cd ~
PrepareIMG

# % Get Raspberry Pi 3 Ubuntu source image 
if [ ! -f "$SOURCE_IMGXZ" ]; then
  echo "Retrieving Ubuntu 18.04.3 source image ..."
  wget http://cdimage.ubuntu.com/ubuntu/releases/"$SOURCE_RELEASE"/release/"$SOURCE_IMGXZ"
fi

# % Get Ubuntu source image 
if [ ! -f "$UBUNTU_IMGXZ" ]; then
  echo "Retrieving Ubuntu 19.10 source image ..."
  wget http://cdimage.ubuntu.com/releases/eoan/release/ubuntu-19.10-preinstalled-server-arm64+raspi3.img.xz
fi

if [ ! -f "$RASPBIAN_IMGZIP" ]; then
  echo "Retrieving Raspbian source image ..."
  curl --location "https://downloads.raspberrypi.org/raspbian_lite_latest" --output "$RASPBIAN_IMGZIP"
fi

# % Extract and compact our source image from the xz if the source image isn't present
if [ ! -f "$UBUNTU_IMG" ]; then
  echo "Extracting Ubuntu 19.10 source image ..."
  xzcat --threads=0 "$UBUNTU_IMGXZ" > "$UBUNTU_IMG"
  MountIMG "$UBUNTU_IMG"
  MountIMGPartitions "${MOUNT_IMG}"
  UpdateIMG
  sudo rm -rf ~/firmware-ubuntu-1910
  sudo mkdir ~/firmware-ubuntu-1910
  sudo cp -raf /mnt/lib/firmware/* ~/firmware-ubuntu-1910
  sudo chown -R "$USER" ~/firmware-ubuntu-1910
  UnmountIMG "$UBUNTU_IMG"
fi

# % Extract and compact our Raspbian image if not present
if [ ! -f "$RASPBIAN_IMG" ]; then
  echo "Extracting Raspbian source image ..."
  unzip $RASPBIAN_IMGZIP
  MountIMG "$RASPBIAN_IMG"
  MountIMGPartitions "${MOUNT_IMG}"
  UpdateIMG
  sudo rm -rf ~/firmware-raspbian
  sudo mkdir ~/firmware-raspbian
  sudo cp -raf /mnt/lib/firmware/* ~/firmware-raspbian
  sudo chown -R "$USER" ~/firmware-raspbian
  UnmountIMG "$RASPBIAN_IMG"
fi

# % Extract and compact our source image from the xz if the source image isn't present
cd ~
if [ ! -f "$SOURCE_IMG" ]; then
  echo "Extracting Ubuntu 18.04.3 source image ..."
  xzcat --threads=0 "$SOURCE_IMGXZ" > "$SOURCE_IMG"
  MountIMG "$SOURCE_IMG"
  MountIMGPartitions "${MOUNT_IMG}"
  sudo rm -rf ~/firmware-ubuntu-1804
  sudo mkdir ~/firmware-ubuntu-1804
  sudo cp -raf /mnt/lib/firmware/* ~/firmware-ubuntu-1804
  sudo chown -R "$USER" ~/firmware-ubuntu-1804
  BeforeCleanIMG
  UpdateIMG
  UnmountIMG "$SOURCE_IMG"
  CompactIMG "$SOURCE_IMG"
fi

# % Create target image from Ubuntu 18.04.3 image
echo "Creating target image ..."
if [ -f "$TARGET_IMG" ]; then
  sudo rm -rf "$TARGET_IMG"
fi
if [ -f "$DESKTOP_IMG" ]; then
  sudo rm -rf "$DESKTOP_IMG"
fi
cp -vf "$SOURCE_IMG" "$TARGET_IMG"
# % Expands the target image by approximately 300MB to help us not run out of space and encounter errors
echo "Expanding target image free space ..."
truncate -s +1009715200 "$TARGET_IMG"
sync; sync


# GET USERLAND
cd ~
if [ ! -d "userland" ]; then
  echo "Building userland ..."
  git clone https://github.com/raspberrypi/userland userland --single-branch --branch=master --depth=1
  cd userland
  PATH=/opt/cross-pi-gcc-9.2.0-64/bin:$PATH LD_LIBRARY_PATH=/opt/cross-pi-gcc-9.2.0-64/lib:$LD_LIBRARY_PATH ./buildme --aarch64
  cd build/arm-linux/release
  sudo make package
  sudo chown -R "$USER" . 
  tar -xf vmcs_host_apps-1.0.pre-1-Linux.tar.gz
  SetGitTimestamps
fi


# GET FIRMWARE NON-FREE
cd ~
echo "Building firmware-nonfree ..."
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
echo "Building rpi-firmware ..."
if [ ! -d "firmware" ]; then
  git clone https://github.com/raspberrypi/firmware firmware --single-branch --branch=master --depth=1
  cd firmware
else
  cd firmware
  if CheckGitUpdates; then
    git reset --hard origin/master
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

# % Remove unneeded firmware folders
sudo rm -rf ~/firmware-build/LICEN*
sudo rm -rf ~/firmware-build/WHENCE
sudo rm -rf ~/firmware-build/check_whence.py
sudo rm -rf ~/firmware-build/Makefile
sudo rm -rf ~/firmware-build/copy-firmware.sh
sudo rm -rf ~/firmware-build/PLUS.txt
sudo rm -rf ~/firmware-build/netronome
sudo rm -rf ~/firmware-build/amdgpu
sudo rm -rf ~/firmware-build/radeon
sudo rm -rf ~/firmware-build/raspberrypi
sudo rm -rf ~/firmware-build/debian
sudo rm -rf ~/firmware-build/*-raspi2

# BUILD KERNEL
cd ~
echo "Building kernel ..."
if [ ! -d "rpi-linux" ]; then
  # Check out the 4.19.y kernel branch -- if building and future versions are available you can update which branch is checked out here
  git clone https://github.com/raspberrypi/linux.git rpi-linux --single-branch --branch rpi-4.19.y --depth 1
  cd ~/rpi-linux
  git checkout origin/rpi-4.19.y

  # Make copy of source code if not present
  if [ ! -d "~/rpi-source" ]; then
    mkdir -p ~/rpi-source
    cp -rf ~/rpi-linux/* ~/rpi-source
    rm ~/rpi-source/.git ~/rpi-source/.github
  fi

  # CONFIGURE / MAKE
  PATH=/opt/cross-pi-gcc-9.2.0-64/bin:$PATH LD_LIBRARY_PATH=/opt/cross-pi-gcc-9.2.0-64/lib:$LD_LIBRARY_PATH make -j$(nproc) ARCH=arm64 CROSS_COMPILE=aarch64-linux-gnu- bcm2711_defconfig

  # % Run conform_config scripts which fix kernel flags to work correctly in arm64
  wget https://raw.githubusercontent.com/sakaki-/bcm2711-kernel-bis/master/conform_config.sh
  chmod +x conform_config.sh
  ./conform_config.sh
  rm -rf conform_config.sh
  wget https://raw.githubusercontent.com/TheRemote/Ubuntu-Server-raspi4-unofficial/master/conform_config_jamesachambers.sh
  chmod +x conform_config_jamesachambers.sh
  ./conform_config_jamesachambers.sh
  rm -rf conform_config_jamesachambers.sh

  # % This pulls the latest config from the repository -- if building yourself/customizing comment out
  #rm -rf .config
  #wget https://raw.githubusercontent.com/TheRemote/Ubuntu-Server-raspi4-unofficial/master/.config

  # % Run prepare to register all our .config changes
  cd ~/rpi-linux
  PATH=/opt/cross-pi-gcc-9.2.0-64/bin:$PATH LD_LIBRARY_PATH=/opt/cross-pi-gcc-9.2.0-64/lib:$LD_LIBRARY_PATH make -j$(nproc) ARCH=arm64 CROSS_COMPILE=aarch64-linux-gnu- prepare dtbs

  # % Prepare and build the rpi-linux source - create debian packages to make it easy to update the image
  PATH=/opt/cross-pi-gcc-9.2.0-64/bin:$PATH LD_LIBRARY_PATH=/opt/cross-pi-gcc-9.2.0-64/lib:$LD_LIBRARY_PATH make -j$(nproc) ARCH=arm64 CROSS_COMPILE=aarch64-linux-gnu- DTC_FLAGS="-@ -H epapr" LOCALVERSION=-"${IMAGE_VERSION}" KDEB_PKGVERSION="${IMAGE_VERSION}" deb-pkg
  
  export KERNEL_VERSION=`cat ~/rpi-linux/include/generated/utsrelease.h | sed -e 's/.*"\(.*\)".*/\1/'`

  # % Make DTBOs
  # % Build kernel modules
  PATH=/opt/cross-pi-gcc-9.2.0-64/bin:$PATH LD_LIBRARY_PATH=/opt/cross-pi-gcc-9.2.0-64/lib:$LD_LIBRARY_PATH sudo make -j$(nproc) ARCH=arm64 CROSS_COMPILE=aarch64-linux-gnu- DEPMOD=echo MODLIB=./lib/modules/"${KERNEL_VERSION}" INSTALL_FW_PATH=./lib/firmware modules_install
  sudo depmod --basedir . "${KERNEL_VERSION}"
  sudo chown -R "$USER" .
else
  export KERNEL_VERSION=`cat ~/rpi-linux/include/generated/utsrelease.h | sed -e 's/.*"\(.*\)".*/\1/'`
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
echo "Running e2fsck"
sudo e2fsck -fva "/dev/mapper/${MOUNT_IMG}p2"
sync; sync
sleep "$SLEEP_SHORT"
UnmountIMG "$TARGET_IMG"
MountIMG "$TARGET_IMG"

# Run resize2fs
echo "Running resize2fs"
sudo resize2fs -p "/dev/mapper/${MOUNT_IMG}p2"
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
mkdir -p ~/updates/rootfs/usr/src/"${KERNEL_VERSION}"
cp --recursive --update --archive --no-preserve=ownership ~/firmware-build/* ~/updates/rootfs/lib/firmware
cp --recursive --update --archive --no-preserve=ownership ~/rpi-linux/lib/modules/* ~/updates/rootfs/lib/modules
cp --recursive --update --archive --no-preserve=ownership ~/rpi-source/* ~/updates/rootfs/usr/src/"${KERNEL_VERSION}"

sync; sync
sleep "$SLEEP_SHORT"

# % Copy overlays / image / firmware
cp -rf ~/rpi-linux/arch/arm64/boot/dts/broadcom/*.dtb ~/updates/bootfs
cp -rf ~/rpi-linux/arch/arm64/boot/dts/overlays/*.dtb* ~/updates/bootfs/overlays
cp -rf ~/rpi-linux/arch/arm64/boot/dts/overlays/README ~/updates/bootfs/overlays
cp -rf ~/rpi-linux/arch/arm64/boot/dts/broadcom/*.dtb ~/updates/rootfs/usr/lib/"${KERNEL_VERSION}"/overlays
cp -rf ~/rpi-linux/arch/arm64/boot/dts/overlays/*.dtb* ~/updates/rootfs/usr/lib/"${KERNEL_VERSION}"/broadcom
cp -rf ~/rpi-linux/arch/arm64/boot/dts/overlays/README ~/updates/rootfs/usr/lib/"${KERNEL_VERSION}"/overlays

# % Unmount and copy firmware copy to overlapping firmware folder
while mountpoint -q /mnt/boot/firmware && ! sudo umount /mnt/boot/firmware; do
  sync; sync
  sleep "$SLEEP_SHORT"
done
sudo cp -rf ~/firmware/boot/*.elf /mnt/boot/firmware/
sudo cp -rf ~/firmware/boot/*.dat /mnt/boot/firmware/
sudo cp -rf ~/firmware/boot/*.bin /mnt/boot/firmware/
sudo mount "/dev/mapper/${MOUNT_IMG}p1" /mnt/boot/firmware

cp -rf ~/rpi-linux/arch/arm64/boot/Image ~/updates/rootfs/boot/kernel8.img
cp -rf ~/rpi-linux/vmlinux ~/updates/rootfs/boot/vmlinux-"${KERNEL_VERSION}"
cp -rf ~/rpi-linux/System.map ~/updates/rootfs/boot/System.map-"${KERNEL_VERSION}"
cp -rf ~/rpi-linux/Module.symvers ~/updates/rootfs/boot/Module.symvers-"${KERNEL_VERSION}"
cp -rf ~/rpi-linux/Module.symvers ~/updates/rootfs/usr/src/"${KERNEL_VERSION}"/Module.symvers
cp -rf ~/rpi-linux/.config ~/updates/rootfs/boot/config-"${KERNEL_VERSION}"
sync; sync
sleep "$SLEEP_SHORT"

# % Copy the new kernel modules
echo "Installing kernel modules ..."
cp -rf ~/rpi-linux/lib/modules/* ~/updates/rootfs/lib/modules
cp -rf ~/rpi-linux/arch/arm64/boot/dts/broadcom/*.dtb ~/updates/bootfs
cp -rf ~/rpi-linux/arch/arm64/boot/dts/overlays/*.dtb* ~/updates/bootfs/overlays

# % Copy new Raspberry Pi userland
cp -rf ~/userland/build/arm-linux/release/vmcs_host_apps-1.0.pre-1-Linux/bin/* ~/updates/rootfs/usr/bin
cp -rf ~/userland/build/arm-linux/release/vmcs_host_apps-1.0.pre-1-Linux/lib/* ~/updates/rootfs/usr/lib/aarch64-linux-gnu
cp -rf ~/userland/build/arm-linux/release/vmcs_host_apps-1.0.pre-1-Linux/include/* ~/updates/rootfs/usr/include

# % Copy kernel and gpu firmware start*.elf, fixup*.dat and bootcode.bin files
cp -rf ~/firmware/boot/*.elf ~/updates/bootfs
cp -rf ~/firmware/boot/*.dat ~/updates/bootfs
cp -rf ~/firmware/boot/*.bin ~/updates/bootfs

cp -rf ~/rpi-linux/arch/arm64/boot/Image ~/updates/bootfs/kernel8.img
sync; sync
sleep "$SLEEP_SHORT"

# % Copy updater script into home folder
cp -f ~/Updater.sh ~/updates/rootfs/home/Updater.sh
cp -f ~/raspi-config ~/updates/rootfs/usr/bin/raspi-config

# % Create cmdline.txt
cat << EOF | tee ~/updates/bootfs/cmdline.txt >/dev/null
snd_bcm2835.enable_headphones=1 snd_bcm2835.enable_hdmi=1 snd_bcm2835.enable_compat_alsa=0 dwc_otg.lpm_enable=0 console=serial0,115200 console=tty1 fsck.repair=yes fsck.mode=auto root=/dev/mmcblk0p2 rootfstype=ext4 elevator=deadline rootwait
EOF

# % Create config.txt
cat << EOF | tee ~/updates/bootfs/config.txt >/dev/null
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
hdmi_force_hotplug=1

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
#dtparam=spi=on
#dtparam=i2s=on
#dtparam=i2c_arm=on
#dtparam=i2c1=on
#dtparam=i2c0=on

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

# % Add udev rule so users can use vcgencmd without sudo
sudo touch /mnt/etc/udev/rules.d/10-local-rpi.rules
echo "SUBSYSTEM==\"vchiq\", GROUP=\"video\", MODE=\"0660\"" | sudo tee /mnt/etc/udev/rules.d/10-local-rpi.rules >/dev/null


# % Startup tweaks to fix common issues
sudo touch /mnt/etc/ubuntufixes.sh
cat << \EOF | sudo tee /mnt/etc/ubuntufixes.sh >/dev/null
#!/bin/bash
#
# Ubuntu Fixes
# More information available at:
# https://jamesachambers.com/raspberry-pi-4-ubuntu-server-desktop-18-04-3-image-unofficial/
# https://github.com/TheRemote/Ubuntu-Server-raspi4-unofficial
#

echo "Running Ubuntu fixes ..."

# Fix sound by setting tsched = 0 and disabling analog mapping so Pulse maps the devices in stereo
if [ -n "`which pulseaudio`" ]; then
  GrepCheck=$(cat /etc/pulse/default.pa | grep "tsched=0")
  if [ -z "$GrepCheck" ]; then
    echo "Fixing PulseAudio ..."
    sed -i "s:load-module module-udev-detect:load-module module-udev-detect tsched=0:g" /etc/pulse/default.pa
    systemctl restart systemd-modules-load
  else
    GrepCheck=$(cat /etc/pulse/default.pa | grep "tsched=0 tsched=0")
    if [ ! -z "$GrepCheck" ]; then
        sed -i 's/tsched=0//g' /etc/pulse/default.pa
        sed -i "s:load-module module-udev-detect:load-module module-udev-detect tsched=0:g" /etc/pulse/default.pa
        systemctl restart systemd-modules-load
    fi
  fi

  GrepCheck=$(cat /usr/share/pulseaudio/alsa-mixer/profile-sets/default.conf | grep "device-strings = fake")
  if [ -z "$GrepCheck" ]; then
    sed -i '/^\[Mapping analog-mono\]/,+1s/device-strings = hw\:\%f.*/device-strings = fake\:\%f/' /usr/share/pulseaudio/alsa-mixer/profile-sets/default.conf
    sed -i '/^\[Mapping multichannel-output\]/,+1s/device-strings = hw\:\%f.*/device-strings = fake\:\%f/' /usr/share/pulseaudio/alsa-mixer/profile-sets/default.conf
    pulseaudio -k
    pulseaudio --start
  fi
fi

# Fix cups
if [ -f /etc/modules-load.d/cups-filters.conf ]; then
  echo "Fixing cups ..."
  rm -f /etc/modules-load.d/cups-filters.conf
fi

# Makes udev mounts visible
if [ "$(systemctl show systemd-udevd | grep 'MountFlags' | cut -d = -f 2)" != "shared" ]; then
  if [ ! -d "/etc/systemd/system/systemd-udevd.service.d/" ]; then
    mkdir -p "/etc/systemd/system/systemd-udevd.service.d/"
  fi
  OverrideFile=/etc/systemd/system/systemd-udevd.service.d/override.conf
  read -r -d '' Override << EOF2
[Service]
MountFlags=shared
EOF2

  if [ -f "$OverrideFile" ]; then
    echo "$OverrideFile exists..."
    if grep -q 'MountFlags' $OverrideFile; then
      echo "Applying udev MountFlags fix to existing $OverrideFile"
      sed -i 's/MountFlags=.*/MountFlags=shared/g' $OverrideFile
    else
      echo "Appending udev MountFlags fix to $OverrideFile"
      cat << EOF2 >> "$OverrideFile"
$Override
EOF2
    fi
  else
    echo "Creating $OverrideFile to apply udev MountFlags fix"
    cat << EOF2 > "$OverrideFile"
$Override
EOF2
  fi

  systemctl daemon-reload
  service systemd-udevd --full-restart

  unset Override
  unset OverrideFile
fi

# Remove triggerhappy bugged socket that causes problems for udev on Pis
if [ -f /lib/systemd/system/triggerhappy.socket ]; then
  echo "Fixing triggerhappy ..."
  sudo rm -rf /lib/systemd/system/triggerhappy.socket
  systemctl daemon-reload
fi


# Add proposed apt archive
GrepCheck=$(cat /etc/apt/sources.list | grep "ubuntu-ports bionic-proposed")
if [ -z "$GrepCheck" ]; then
    cat << EOF2 | tee -a /etc/apt/sources.list >/dev/null
deb http://ports.ubuntu.com/ubuntu-ports bionic-proposed restricted main multiverse universe
EOF2
touch /etc/apt/preferences.d/proposed-updates 
cat << EOF2 | tee /etc/apt/preferences.d/proposed-updates >/dev/null
Package: *
Pin: release a=bionic-proposed
Pin-Priority: 400
EOF2
fi

# Fix Cannot access /dev/virtio-ports/com.redhat.spice.0
if [ -f "/usr/share/gdm/autostart/LoginWindow/spice-vdagent.desktop" ]; then
  GrepCheck=$(cat /usr/share/gdm/autostart/LoginWindow/spice-vdagent.desktop | grep "X-GNOME-Autostart-enabled=false")
  if [ -z "$GrepCheck" ]; then
    echo "Fixing spice-vdagent ..."
    echo 'X-GNOME-Autostart-enabled=false' | tee -a /usr/share/gdm/autostart/LoginWindow/spice-vdagent.desktop >/dev/null
    echo 'X-GNOME-Autostart-enabled=false' | tee -a /etc/xdg/autostart/spice-vdagent.desktop >/dev/null
    systemctl stop spice-vdagentd
    systemctl disable spice-vdagentd
    systemctl daemon-reload
  fi
fi

# Fix WiFi
sed -i "s:0x48200100:0x44200100:g" /lib/firmware/brcm/brcmfmac43455-sdio.txt

# Disable ib_iser iSCSI cloud module to prevent an error during systemd-modules-load at boot
if [ -f "/lib/modules-load.d/open-iscsi.conf" ]; then
  GrepCheck=$(cat /lib/modules-load.d/open-iscsi.conf | grep "#ib_iser")
  if [ -z "$GrepCheck" ]; then
    echo "Fixing open-iscsi ..."
    sed -i "s/ib_iser/#ib_iser/g" /lib/modules-load.d/open-iscsi.conf
    sed -i "s/iscsi_tcp/#iscsi_tcp/g" /lib/modules-load.d/open-iscsi.conf
    systemctl restart systemd-modules-load
  fi
fi

# Fix update-initramfs mdadm.conf warning
grep "ARRAY devices" /etc/mdadm/mdadm.conf >/dev/null || echo "ARRAY devices=/dev/sda" | tee -a /etc/mdadm/mdadm.conf >/dev/null;

# Remove annoying crash messages that never go away
sudo rm -rf /var/crash/*
GrepCheck=$(cat /etc/default/apport | grep "enabled=0")
if [ -z "$GrepCheck" ]; then
  sed -i "s/enabled=1/enabled=0/g" /etc/default/apport
fi

# Attach bluetooth
if [ -n "`which hciattach`" ]; then
  echo "Attaching Bluetooth controller ..."
  hciattach /dev/ttyAMA0 bcm43xx 921600
fi

# Fix xubuntu-desktop/lightdm if present
if [ -n "`which lightdm`" ]; then
  if [ ! -f "/etc/X11/xorg.conf" ]; then
    echo "Fixing LightDM ..."
    cat << EOF2 | tee /etc/X11/xorg.conf >/dev/null
Section "Device"
Identifier "Card0"
Driver "modesetting"
EndSection
EOF2
    systemctl restart lightdm
  fi
fi

echo "Ubuntu fixes complete ..."

exit 0
EOF
sudo chmod +x /mnt/etc/ubuntufixes.sh

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
ln -s /boot/firmware/overlays /boot/overlays

# % Create kernel and component symlinks
cd /boot
rm -rf vmlinux
rm -rf System.map
rm -rf Module.symvers
rm -rf config
ln -s initrd.img-"${KERNEL_VERSION}" initrd.img
ln -s vmlinux-"${KERNEL_VERSION}" vmlinux
ln -s System.map-"${KERNEL_VERSION}" System.map
ln -s Module.symvers-"${KERNEL_VERSION}" Module.symvers
ln -s config-"${KERNEL_VERSION}" config
cd /

# % Add updated mesa repository for video driver support
add-apt-repository ppa:oibaf/graphics-drivers -yn

# % Install wireless tools (wireless-tools, iw, rfkill)
# % Install raspi-config dependencies (libnewt0.52 whiptail lua5.1)
# % Install dependencies to build Pi modules (git build-essential bc bison flex libssl-dev device-tree-compiler)
# % Install curl and unzip utilities
# % Install missing libblockdev-mdraid
apt update && apt install haveged libblockdev-mdraid2 wireless-tools iw rfkill bluez libnewt0.52 whiptail lua5.1 git bc curl unzip build-essential libgmp-dev libmpfr-dev libmpc-dev libssl-dev bison flex -y && apt dist-upgrade -y

# % Clean up after ourselves and clean out package cache to keep the image small
apt autoremove -y && apt clean && apt autoclean

# % Prepare source code to be able to build modules
cd /usr/src/"${KERNEL_VERSION}"
make -j4 bcm2711_defconfig
cp -f /boot/config .config
make -j4 prepare
make -j4 modules_prepare

# % Create kernel header/source symlink
rm -rf /lib/modules/"${KERNEL_VERSION}"/build 
rm -rf /lib/modules/"${KERNEL_VERSION}"/source
ln -s /usr/src/"${KERNEL_VERSION}"/ /lib/modules/"${KERNEL_VERSION}"/build
ln -s /usr/src/"${KERNEL_VERSION}"/ /lib/modules/"${KERNEL_VERSION}"/source

sudo touch /etc/init.d/ubuntufixes
cat << \EOF2 | sudo tee /etc/init.d/ubuntufixes >/dev/null
#!/bin/bash
# /etc/init.d/ubuntufixes

### BEGIN INIT INFO
# Provides:          ubuntufixes
# Required-Start:    $remote_fs $syslog
# Required-Stop:     $remote_fs $syslog
# Default-Start:     2 3 4 5
# Default-Stop:      0 1 6
# Short-Description: Runs ubuntu fixes on startup/shutdown
# Description:       Runs ubuntu fixes on startup/shutdown
### END INIT INFO

/bin/bash /etc/ubuntufixes.sh

exit 0
EOF2
sudo chmod +x /etc/init.d/ubuntufixes
sudo update-rc.d ubuntufixes defaults
/bin/bash /etc/ubuntufixes.sh

rm -rf /etc/netplan/50-cloud-init.yaml	
touch /etc/netplan/50-cloud-init.yaml	
cat << EOF2 | tee /etc/netplan/50-cloud-init.yaml >/dev/null	
network:	
  ethernets:	
      eth0:	
          dhcp4: true	
          optional: true	
  version: 2	
EOF2
netplan generate
netplan --debug apply

EOF
echo "The chroot container has exited"

# % Grab our updated built source code for updates.tar.gz
cp -rf /mnt/usr/src/"${KERNEL_VERSION}"/* ~/rpi-source

# % Set regulatory crda to enable 5 Ghz wireless
sudo mkdir -p /mnt/etc/default
sudo touch /mnt/etc/default/crda
cat << EOF | sudo tee /mnt/etc/default/crda >/dev/null
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
cat << EOF | sudo tee /mnt/etc/hosts >/dev/null
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
cat << EOF | sudo tee /mnt/etc/fstab >/dev/null
LABEL=writable   /   ext4   defaults   0    1
LABEL=system-boot       /boot/firmware  vfat    defaults        0       1
EOF

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

# Build desktop image
echo "Creating desktop image ..."
if [ -f "$DESKTOP_IMG" ]; then
  sudo rm -rf "$DESKTOP_IMG"
fi
cp -vf "$TARGET_IMG" "$DESKTOP_IMG"
# % Expands the target image by approximately 2GB to help us not run out of space and encounter errors
echo "Expanding desktop image free space ..."
truncate -s +4009715200 "$DESKTOP_IMG"
sync; sync

MountIMG "$DESKTOP_IMG"

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

UnmountIMG "$DESKTOP_IMG"
MountIMG "$DESKTOP_IMG"

# Run e2fsck
echo "Running e2fsck"
sudo e2fsck -fva "/dev/mapper/${MOUNT_IMG}p2"
sync; sync
sleep "$SLEEP_SHORT"
UnmountIMG "$DESKTOP_IMG"
MountIMG "$DESKTOP_IMG"

# Run resize2fs
echo "Running resize2fs"
sudo resize2fs -p "/dev/mapper/${MOUNT_IMG}p2"
sync; sync
sleep "$SLEEP_SHORT"
UnmountIMG "$DESKTOP_IMG"

# Compact image after our file operations
CompactIMG "$DESKTOP_IMG"
MountIMG "$DESKTOP_IMG"
MountIMGPartitions "${MOUNT_IMG}"

sudo chroot /mnt /bin/bash << EOF
apt update && apt install ubuntu-desktop -y
/bin/bash /etc/ubuntufixes.sh
apt dist-upgrade -y
/bin/bash /etc/ubuntufixes.sh
EOF

# Run the after clean function
AfterCleanIMG

# Run fsck on image then unmount and remount
UnmountIMGPartitions
sudo fsck.ext4 -pfv "/dev/mapper/${MOUNT_IMG}p2"
sudo fsck.fat -av "/dev/mapper/${MOUNT_IMG}p1"
UnmountIMG "$DESKTOP_IMG"
CompactIMG "$DESKTOP_IMG"

# Clean firmware
# % Remove files that haven't changed from the base 18.04.3 files
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

# Shrink images
ShrinkIMG "$DESKTOP_IMG"
ShrinkIMG "$TARGET_IMG"

# Compress img into xz file
echo "Compressing final server img.xz file ..."
sleep "$SLEEP_SHORT"
sudo rm -rf "$TARGET_IMGXZ"
xz -9e --force --keep --threads=0 --quiet "$TARGET_IMG"

echo "Compressing final desktop img.xz file ..."
sleep "$SLEEP_SHORT"
sudo rm -rf "$DESKTOP_IMGXZ"
xz -9e --force --keep --threads=0 --quiet "$DESKTOP_IMG"

# Compress our updates used for the autoupdater
echo "Compressing updates.tar.xz ..."
# Prevent overwriting the updater running the updates since it's probably newer than us
sudo rm -rf ~/updates/rootfs/home/Updater.sh
sudo rm -rf ~/updates.tar.xz
tar -cf - updates/ | xz -9e -c --threads=0 - > ~/updates.tar.xz

echo "Build completed"

