#!/bin/bash
#
# More information available at:
# https://jamesachambers.com/raspberry-pi-4-ubuntu-server-desktop-18-04-3-image-unofficial/
# https://github.com/TheRemote/Ubuntu-Server-raspi4-unofficial

cd ~
sudo rm -rf rpi-linux 
sudo rm -rf rpi-source
sudo rm -rf firmware-build

sudo rm -rf ~/linux-*
sudo rm -rf updates
sudo rm -rf updates.tar.xz 
sudo rm -rf ubuntu*.img *+raspi4.img.xz

# Even more thorough options

#sudo rm -rf firmware
#sudo rm -rf firmware-nonfree
