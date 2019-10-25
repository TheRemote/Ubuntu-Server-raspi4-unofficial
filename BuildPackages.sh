#!/usr/bin/env bash

# This script builds the packages used in the PPA to allow for automatic kernel/firmware updates via apt

# More information available at:
# https://jamesachambers.com/raspberry-pi-4-ubuntu-server-desktop-18-04-3-image-unofficial/
# https://github.com/TheRemote/Ubuntu-Server-raspi4-unofficial

# BUILD AND SIGN KERNEL PACKAGES FOR PPA
export DEBFULLNAME="James A. Chambers (https://jamesachambers.com)"
export DEBEMAIL="james@jamesachambers.com"

sudo apt install devscripts dput pgpgpg -y

cd ~
sudo rm -rf tmp
mkdir tmp
cd tmp
dpkg-source -x ../linux-*.dsc
cd linux-*/
sed -i 's;james <james@james-VirtualBox>;James A. Chambers (https://jamesachambers.com) <james@jamesachambers.com>;g' debian/changelog
debuild -S -sa

cd ..
dput ppa:theremote/ppa-ubuntu-raspi4 *.changes