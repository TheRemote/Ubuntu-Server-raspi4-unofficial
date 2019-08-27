sudo apt-get install build-essential libgmp-dev libmpfr-dev libmpc-dev libssl-dev bison flex

# TOOLCHAIN

cd ~
mkdir -p toolchains/aarch64
cd toolchains/aarch64

export TOOLCHAIN=`pwd`

cd "$TOOLCHAIN"
wget https://ftp.gnu.org/gnu/binutils/binutils-2.32.tar.bz2
tar -xf binutils-2.32.tar.bz2
mkdir binutils-2.32-build
cd binutils-2.32-build
../binutils-2.32/configure --prefix="$TOOLCHAIN" --target=aarch64-linux-gnu --disable-nls
make -j4
make install

cd "$TOOLCHAIN"
wget https://ftp.gnu.org/gnu/gcc/gcc-9.1.0/gcc-9.1.0.tar.gz
tar -xf gcc-9.1.0.tar.gz
mkdir gcc-9.1.0-build
cd gcc-9.1.0-build
../gcc-9.1.0/configure --prefix="$TOOLCHAIN" --target=aarch64-linux-gnu --with-newlib --without-headers --disable-nls --disable-shared --disable-threads --disable-libssp --disable-decimal-float --disable-libquadmath --disable-libvtv --disable-libgomp --disable-libatomic --enable-languages=c
make all-gcc -j4
make install-gcc


# BUILD RPI TOOLS FOR ARMSTUB8

cd ~
git clone https://github.com/raspberrypi/tools.git rpi-tools
cd rpi-tools/armstubs
git checkout 7f4a937e1bacbc111a22552169bc890b4bb26a94
PATH=$PATH:$TOOLCHAIN/bin make armstub8-gic.bin


# GET FIRMWARE NON-FREE

cd ~
git clone https://github.com/RPi-Distro/firmware-nonfree firmware-nonfree


# BUILD KERNEL

cd ~
git clone https://github.com/raspberrypi/linux.git rpi-linux
cd rpi-linux
git checkout origin/rpi-4.19.y # change the branch name for newer versions
mkdir kernel-build
PATH=$PATH:$TOOLCHAIN/bin make O=./kernel-build/ ARCH=arm64 CROSS_COMPILE=aarch64-linux-gnu-  bcm2711_defconfig
PATH=$PATH:$TOOLCHAIN/bin make -j4 O=./kernel-build/ ARCH=arm64 CROSS_COMPILE=aarch64-linux-gnu-
export KERNEL_VERSION=`cat ./kernel-build/include/generated/utsrelease.h | sed -e 's/.*"\(.*\)".*/\1/'` 
sudo make -j4 O=./kernel-build/ DEPMOD=echo MODLIB=./kernel-install/lib/modules/${KERNEL_VERSION} INSTALL_FW_PATH=./kernel-install/lib/firmware modules_install

depmod --basedir kernel-build/kernel-install "$KERNEL_VERSION"
export KERNEL_BUILD_DIR=`realpath kernel-build` # used if you want to deploy it to Raspbian, ignore otherwise
cd ~

# BUILD IMAGE

xzcat ubuntu-18.04.3-preinstalled-server-arm64+raspi4.img.xz > ubuntu-18.04.3-preinstalled-server-arm64+raspi4.img
sudo kpartx -av ubuntu-18.04.3-preinstalled-server-arm64+raspi4.img

sudo mount /dev/mapper/loop2p2 /mnt
sudo mount /dev/mapper/loop2p1 /mnt/boot/firmware

sudo cp rpi-linux/kernel-build/arch/arm64/boot/Image /mnt/boot/firmware/kernel8.img
sudo cp rpi-tools/armstubs/armstub8-gic.bin /mnt/boot/firmware/armstub8-gic.bin
sudo cp -avf rpi-linux/kernel-build/kernel-install/lib/modules/${KERNEL_VERSION} /mnt/lib/modules/
git clone https://github.com/RPi-Distro/firmware-nonfree firmware-nonfree
sudo cp -avf firmware-nonfree/* /mnt/lib/firmware

sudo mkdir /mnt/boot/firmware/overlays
sudo cp -vf rpi-linux/kernel-build/arch/arm64/boot/dts/broadcom/*.dtb /mnt/boot/firmware
sudo cp -vf rpi-linux/kernel-build/arch/arm64/boot/dts/overlays/*.dtb* /mnt/boot/firmware/overlays
sudo cp -vf rpi-linux/kernel-build/System.map /mnt/boot/firmware/


# QUIRKS

# % Fix WiFi
sudo sed -i "s:0x48200100:0x44200100:g" /mnt/lib/firmware/brcm/brcmfmac43455-sdio.txt

#The Pi4 version returns boardflags3=0x44200100
#The Pi3 version returns boardflags3=0x48200100

sudo umount /mnt/boot/firmware
sudo umount /mnt
sudo kpartx -dv ubuntu-18.04.3-preinstalled-server-arm64+raspi4.img
sudo losetup -d /dev/loop2