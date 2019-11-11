#!/bin/bash
#
# More information available at:
# https://jamesachambers.com/raspberry-pi-4-ubuntu-server-desktop-18-04-3-image-unofficial/
# https://github.com/TheRemote/Ubuntu-Server-raspi4-unofficial

# Check for sudo
if [ -z "$SUDO_USER" ]; then
    echo "Error: must run as sudo (sudo ./Updater.sh)"
    exit
fi

echo "Checking dependencies ..."

# Add updated mesa repository for video driver support
sudo add-apt-repository ppa:ubuntu-x-swat/updates -ynr
sudo add-apt-repository ppa:ubuntu-raspi2/ppa -ynr
sudo add-apt-repository ppa:oibaf/graphics-drivers -yn

# Fix cups
if [ -f /etc/modules-load.d/cups-filters.conf ]; then
  rm -f /etc/modules-load.d/cups-filters.conf
  systemctl restart systemd-modules-load cups
fi

# Install dependencies
sudo apt update && sudo apt install libblockdev-mdraid2 wireless-tools iw rfkill bluez libnewt0.52 whiptail lua5.1 git bc bison flex libssl-dev -y
sudo apt-get dist-upgrade -y

echo "Checking for updates ..."

if [ -d ".updates" ]; then
    cd .updates
    if [ -d "Ubuntu-Server-raspi4-unofficial" ]; then
        cd Ubuntu-Server-raspi4-unofficial
        sudo git pull
        sudo git reset --hard origin/master
        cd ..
    else
        sudo git clone https://github.com/TheRemote/Ubuntu-Server-raspi4-unofficial.git
    fi
else
    sudo mkdir .updates
    cd .updates
    sudo git clone https://github.com/TheRemote/Ubuntu-Server-raspi4-unofficial.git
fi
cd ..

# Check if Updater.sh has been updated
UpdatesHashOld=$(sha1sum "Updater.sh" | cut -d" " -f1 | xargs)
UpdatesHashNew=$(sha1sum ".updates/Ubuntu-Server-raspi4-unofficial/Updater.sh" | cut -d" " -f1 | xargs)

if [ "$UpdatesHashOld" != "$UpdatesHashNew" ]; then
    echo "Updater has update available.  Updating now ..."
    sudo rm -rf Updater.sh
    sudo cp -f .updates/Ubuntu-Server-raspi4-unofficial/Updater.sh Updater.sh
    sudo chmod +x Updater.sh
    exec $(readlink -f "Updater.sh")
    exit
fi

echo "Updater is up to date.  Checking system ..."

# Find currently installed and latest release
cd .updates
LatestRelease=$(cat "Ubuntu-Server-raspi4-unofficial/BuildPiKernel64bit.sh" | grep "IMAGE_VERSION=" | cut -d"=" -f2 | xargs)
CurrentRelease="0"

if [ -e "/etc/imgrelease" ]; then
    read -r CurrentRelease < "/etc/imgrelease"
fi

if [ "$LatestRelease" == "$CurrentRelease" ]; then
    echo "You have release ${LatestRelease}. No updates are currently available!"
    exit
fi

# Update is available, confirm insatallation with user
echo "Release v${LatestRelease} is available!  Make sure you have made a full backup."
echo "Note: your /boot cmdline.txt and config.txt files will be reset to the newest version.  Make a backup of those first!"
echo -n "Update now? (y/n)"
read answer
if [ "$answer" == "${answer#[Yy]}" ]; then
    echo "Update has been aborted!"
    exit
fi

# Cleaning up old stuff
sudo apt -qq purge libraspberrypi-bin raspi-config -y >/dev/null 2>&1

echo "Downloading update package ..."
if [ -e "updates.tar.xz" ]; then rm -rf "updates.tar.xz"; fi
sudo curl --location "https://github.com/TheRemote/Ubuntu-Server-raspi4-unofficial/releases/download/v${LatestRelease}/updates.tar.xz" --output "updates.tar.xz"
if [ ! -e "updates.tar.xz" ]; then
    echo "Update has failed to download -- please try again later"
    exit
fi

# Download was successful, extract and copy updates
echo "Extracting update package - This can take several minutes on the Pi ..."
sudo rm -rf updates
sudo tar -xf "updates.tar.xz"

if [[ -d "updates" && -d "updates/rootfs" && -d "updates/bootfs" ]]; then
    echo "Removing old kernel source code ..."
    sudo rm -rf /usr/src/4.19*
    
    echo "Copying updates to rootfs ..."
    sudo cp -rav --no-preserve=ownership updates/rootfs/* /

    echo "Copying updates to bootfs ..."
    sudo cp -rav --no-preserve=ownership updates/bootfs/* /boot/firmware

    # Update initramfs so our new kernel and modules are picked up
    echo "Updating kernel and modules ..."
    export KERNEL_VERSION="$(ls updates/rootfs/lib/modules)"
    sudo depmod "${KERNEL_VERSION}"

    # Create kernel and component symlinks
    sudo rm -rf /boot/initrd.img
    sudo rm -rf /boot/vmlinux
    sudo rm -rf /boot/System.map
    sudo rm -rf /boot/Module.symvers
    sudo rm -rf /boot/config
    sudo ln -s /boot/initrd.img-"${KERNEL_VERSION}" /boot/initrd.img
    sudo ln -s /boot/vmlinux-"${KERNEL_VERSION}" /boot/vmlinux
    sudo ln -s /boot/System.map-"${KERNEL_VERSION}" /boot/System.map
    sudo ln -s /boot/Module.symvers-"${KERNEL_VERSION}" /boot/Module.symvers
    sudo ln -s /boot/config-"${KERNEL_VERSION}" /boot/config

    # Create kernel header symlink
    sudo rm -rf /lib/modules/"${KERNEL_VERSION}"/build 
    sudo rm -rf /lib/modules/"${KERNEL_VERSION}"/source
    sudo ln -s /usr/src/"${KERNEL_VERSION}"/ /lib/modules/"${KERNEL_VERSION}"/build
    sudo ln -s /usr/src/"${KERNEL_VERSION}"/ /lib/modules/"${KERNEL_VERSION}"/source

    # Call update-initramfs to finish kernel setup
    sha1sum=$(sha1sum /boot/vmlinux-"${KERNEL_VERSION}")
    echo "$sha1sum  /boot/vmlinux-${KERNEL_VERSION}" | sudo tee /var/lib/initramfs-tools/"${KERNEL_VERSION}" >/dev/null;
    sudo update-initramfs -k "${KERNEL_VERSION}" -u

    echo "Cleaning up downloaded files ..."
    sudo rm -rf "updates.tar.xz"
    sudo rm -rf updates

    # Save our new updated release to .lastupdate file
    sudo touch /etc/imgrelease
    echo "$LatestRelease" | sudo tee /etc/imgrelease >/dev/null;
else
    sudo rm -rf "updates.tar.xz"
    echo "Update has failed to extract.  Please try again later!"
    exit
fi

# % Add various groups to account such as the video group to allow access to vcgencmd and other userland utilities
sudo groupadd -f spi
sudo groupadd -f i2c
sudo groupadd -f gpio
sudo usermod -aG adm,dialout,cdrom,sudo,audio,video,plugdev,games,users,input,netdev,spi,i2c,gpio,geoclue,colord,pulse "$SUDO_USER"

# % Clear /var/crash
sudo rm -rf /var/crash/*

# % Fix /lib/firmware symlink, overlays symlink
if [ ! -d "/etc/firmware" ]; then sudo ln -s /lib/firmware /etc/firmware; fi
if [ ! -d "/boot/overlays" ]; then sudo ln -s /boot/firmware/overlays /boot/overlays; fi

# % Add udev rule so users can use vcgencmd without sudo
sudo echo "SUBSYSTEM==\"vchiq\", GROUP=\"video\", MODE=\"0660\"" > /etc/udev/rules.d/10-local-rpi.rules

# Startup tweaks to fix common issues
sudo rm /etc/ubuntufixes.sh
sudo touch /etc/ubuntufixes.sh
cat << \EOF | sudo tee /etc/ubuntufixes.sh >/dev/null
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
Driver "fbdev"
EndSection
EOF2
    systemctl restart lightdm
  fi
fi

echo "Ubuntu fixes complete ..."

exit 0
EOF

# Create Ubuntu fixes startup service
sudo rm /etc/init.d/ubuntufixes
sudo touch /etc/init.d/ubuntufixes
cat << \EOF | sudo tee /etc/init.d/ubuntufixes >/dev/null
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
EOF
sudo chmod +x /etc/init.d/ubuntufixes
sudo update-rc.d ubuntufixes defaults
sudo /bin/bash /etc/ubuntufixes.sh >/dev/null 2>&1

# Remove old rc.local config method if present
if [ -f /etc/rc.local ]; then
  GrepCheck=$(cat /etc/rc.local | grep "which pulseaudio")
  if [ ! -z "$GrepCheck" ]; then
    echo "Removing old Ubuntu fix file ..."
    sudo rm -f /etc/rc.local
  fi
fi

echo "Update completed!"
echo "You should now reboot the system."