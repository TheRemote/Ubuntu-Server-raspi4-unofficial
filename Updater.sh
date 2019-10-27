#!/usr/bin/env bash

# More information available at:
# https://jamesachambers.com/raspberry-pi-4-ubuntu-server-desktop-18-04-3-image-unofficial/
# https://github.com/TheRemote/Ubuntu-Server-raspi4-unofficial

sudo apt install git -y

echo "Checking for updates ..."

if [ -d ".updates" ]; then
    cd .updates/Ubuntu-Server-raspi4-unofficial
    git pull
    git reset --hard
    cd ..
else
    mkdir .updates
    cd .updates
    git clone https://github.com/TheRemote/Ubuntu-Server-raspi4-unofficial.git
fi

UpdatesHashOld=$(sha1sum "../Updater.sh")
UpdatesHashNew=$(sha1sum "Ubuntu-Server-raspi4-unofficial/Updater.sh")
if [ "$UpdatesHashOld" != "$UpdatesHashNew" ]; then
    echo "Updater has update available.  Updating now ..."
    rm -f ../Updater.sh
    cp -f Ubuntu-Server-raspi4-unofficial/Updater.sh ../Updater.sh
    /bin/bash ../Updater.sh
    return 1
fi

LatestRelease=$(grep "IMAGE_VERSION=" .updates/Ubuntu-Server-raspi4-unofficial/BuildPiKernel64bit.sh | cut -d= -f2 | xargs)
CurrentRelease="0"

# Check what our last installed update release was
if [ -e ".lastupdate" ]; then
    read -r CurrentRelease < ".lastupdate"
    
fi

if [[ "$LatestRelease" == "$CurrentRelease" ]]; then
    echo "No updates are currently available!"
    return 0
else
    echo "Release v$LatestRelease is available!"

    echo -n "Update now? (y/n)"
    read answer
    echo $answer
    if [ "$answer" == "${answer#[Yy]}" ]; then
        echo "Update has been aborted"
        return 1
    fi
    
    echo "Downloading update package ..."
    if [ -e "updates.tar.xz" ]; then rm -f "updates.tar.xz"; fi
    curl --location "https://github.com/TheRemote/Ubuntu-Server-raspi4-unofficial/releases/download/v$LatestRelease/updates.tar.xz" --output updates.tar.xz
    if [ ! -e "updates.tar.xz" ]; then
        echo "Update has failed to download -- please try again later"
        return 1
    fi

    echo "Extracing update package ..."
    tar -xf updates.tar.gz

    echo "Copying updates to rootfs ..."
    sudo cp --verbose --archive --no-preserve=ownership updates/rootfs/* /mnt

    echo "Copying updates to bootfs ..."
    sudo cp --verbose --archive --no-preserve=ownership updates/bootfs/* /mnt/boot/firmware

    # Update initramfs so our new kernel and modules are picked up
    echo "Updating kernel and modules ..."
    sudo update-initramfs -u

    # Save our new updated release to .lastupdate file
    echo "$LatestRelease" > .lastupdate

    echo "Update completed!  Please reboot your system."
fi