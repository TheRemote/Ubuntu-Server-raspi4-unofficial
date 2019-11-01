#!/bin/bash
#
# More information available at:
# https://jamesachambers.com/raspberry-pi-4-ubuntu-server-desktop-18-04-3-image-unofficial/
# https://github.com/TheRemote/Ubuntu-Server-raspi4-unofficial

sudo apt-get update && sudo apt-get install git curl unzip build-essential libgmp-dev libmpfr-dev libmpc-dev libssl-dev bison flex -y

cd /usr/src/4.19*
sudo make -j$(nproc) bcm2711_defconfig
sudo cp -f /boot/config .config
sudo make -j$(nproc) prepare
sudo make -j$(nproc) modules_prepare

# Line below compiles the whole kernel
#sudo make -j$(nproc)