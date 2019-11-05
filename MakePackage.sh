#!/bin/bash
export PACKAGE_VERSION=18
wget https://github.com/TheRemote/Ubuntu-Server-raspi4-unofficial/releases/download/v$PACKAGE_VERSION/updates.tar.xz
tar -xvf updates.tar.xz
rm ./updates/rootfs/lib/firmware/regulatory.db*
fpm -s dir -t deb -n linux-raspi4 -v $PACKAGE_VERSION \
		-p linux-raspi4-$PACKAGE_VERSION.deb \
		--deb-priority optional --category admin \
		--depends "libblockdev-mdraid2" \
		--depends "wireless-tools" \
		--depends "iw" \
		--depends "rfkill" \
		--depends "bluez" \
		--depends "haveged" \
		--depends "libnewt0.52" \
		--depends "whiptail" \
		--depends "lua5.1" \
		--depends "git" \
		--depends "bc" \
		--depends "bison" \
		--depends "flex" \
		--depends "libssl-dev" \
		--depends "sudo" \
		--conflicts "libraspberrypi-bin" \
		--conflicts "raspi-config, linux-raspi2, linux-image-raspi2, linux-headers-raspi2, linux-firmware-raspi2, ureadahead, libnih1, whoopsie" \
		--replaces "linux-firmware" \
		--after-install Updater.sh \
		--force \
		--url https://github.com/TheRemote/Ubuntu-Server-raspi4-unofficial \
		--description "Ubuntu Server 18.04.3 Raspberry Pi 4 Image" \
		-m "James A. Chambers <05jchambers@gmail.com>" \
		--license "Apache License" \
		--vendor "James A. Chambers" \
		-a arm64 ./updates/rootfs/=/ ./updates/bootfs/=/boot/firmware/