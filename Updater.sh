#!/bin/bash
#
# More information available at:
# https://jamesachambers.com/raspberry-pi-4-ubuntu-server-desktop-18-04-3-image-unofficial/
# https://github.com/TheRemote/Ubuntu-Server-raspi4-unofficial


sudo apt install git curl -y

echo "Checking for updates ..."

if [ -d ".updates" ]; then
    cd .updates
    if [ -d "Ubuntu-Server-raspi4-unofficial" ]; then
        cd Ubuntu-Server-raspi4-unofficial
        git fetch --all
        git reset --hard origin/master
        cd ..
    else
        git clone https://github.com/TheRemote/Ubuntu-Server-raspi4-unofficial.git
    fi
else
    mkdir .updates
    cd .updates
    git clone https://github.com/TheRemote/Ubuntu-Server-raspi4-unofficial.git
fi
cd ..

# Check if Updater.sh has been updated
UpdatesHashOld=$(sha1sum "Updater.sh" | cut -d" " -f1 | xargs)
UpdatesHashNew=$(sha1sum ".updates/Ubuntu-Server-raspi4-unofficial/Updater.sh" | cut -d" " -f1 | xargs)

echo "$UpdatesHashOld - $UpdatesHashNew"

if [ "$UpdatesHashOld" != "$UpdatesHashNew" ]; then
    echo "Updater has update available.  Updating now ..."
    rm -f Updater.sh
    cp -f .updates/Ubuntu-Server-raspi4-unofficial/Updater.sh Updater.sh
    chmod +x Updater.sh
    exec $(readlink -f "Updater.sh")
    exit
fi

echo "Updater is up to date.  Checking system ..."

# Find currently installed and latest release
cd .updates
LatestRelease=$(cat "Ubuntu-Server-raspi4-unofficial/BuildPiKernel64bit.sh" | grep "IMAGE_VERSION=" | cut -d"=" -f2 | xargs)
CurrentRelease="0"
if [ -e "/etc/imagerelease" ]; then
    read -r CurrentRelease < "/etc/imagerelease"
fi

if [ "$LatestRelease" == "$CurrentRelease" ]; then
    echo "No updates are currently available!"
    exit
else
    echo "Release v${LatestRelease} is available!"

    echo -n "Update now? (y/n)"
    read answer
    if [ "$answer" == "${answer#[Yy]}" ]; then
        echo "Update has been aborted"
        exit
    fi
    
    echo "Downloading update package ..."
    if [ -e "updates.tar.xz" ]; then rm -f "updates.tar.xz"; fi
    curl --location "https://github.com/TheRemote/Ubuntu-Server-raspi4-unofficial/releases/download/v${LatestRelease}/updates.tar.xz" --output "updates.tar.xz"
    if [ ! -e "updates.tar.xz" ]; then
        echo "Update has failed to download -- please try again later"
        exit
    fi

    # Download was successful, extract and copy updates
    echo "Extracting update package ..."
    tar -xf "updates.tar.gz"
    rm -f "updates.tar.gz"

    if [ -d "updates" && -d "updates/rootfs" && -d "updates/bootfs" ]; then
        echo "Copying updates to rootfs ..."
        sudo cp --verbose --archive --no-preserve=ownership "updates/rootfs/*" "/mnt"

        echo "Copying updates to bootfs ..."
        sudo cp --verbose --archive --no-preserve=ownership "updates/bootfs/*" "/mnt/boot/firmware"

        # Update initramfs so our new kernel and modules are picked up
        echo "Updating kernel and modules ..."
        #sudo update-initramfs -u

        # Save our new updated release to .lastupdate file
        echo "$LatestRelease" | sudo tee -a /etc/imgrelease >/dev/null;
    else
        echo "Update has failed to extract.  Please try again later!"
    fi

    echo "Update completed!  Please reboot your system."
fi