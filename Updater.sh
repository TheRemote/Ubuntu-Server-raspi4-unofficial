#!/bin/bash
#
# More information available at:
# https://jamesachambers.com/raspberry-pi-4-ubuntu-server-desktop-18-04-3-image-unofficial/
# https://github.com/TheRemote/Ubuntu-Server-raspi4-unofficial

# Add updated mesa repository for video driver support
sudo add-apt-repository ppa:ubuntu-x-swat/updates -ynr
sudo add-apt-repository ppa:ubuntu-raspi2/ppa -ynr
sudo add-apt-repository ppa:oibaf/graphics-drivers -yn

# Fix cups
if [ -e /etc/modules-load.d/cups-filters.conf ]; then
  rm /etc/modules-load.d/cups-filters.conf
  systemctl restart systemd-modules-load cups
fi

echo "Note: your /boot cmdline.txt and config.txt files will be reset to the newest version.  Make a backup of those first!"

    # Update initramfs so our new kernel and modules are picked up
    echo "Updating kernel and modules ..."
    export KERNEL_VERSION="$(ls -1 /lib/modules/ | grep v8 | sort -V | tail -n 1)"
    sudo depmod "${KERNEL_VERSION}"

    # Create kernel and component symlinks
    sudo rm -f /boot/initrd.img
    sudo rm -f /boot/vmlinux
    sudo rm -f /boot/System.map
    sudo rm -f /boot/Module.symvers
    sudo rm -f /boot/config
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

# % Add various groups to account such as the video group to allow access to vcgencmd and other userland utilities
sudo groupadd -f spi
sudo groupadd -f i2c
sudo groupadd -f gpio
#sudo usermod -aG adm,dialout,cdrom,sudo,audio,video,plugdev,games,users,input,netdev,spi,i2c,gpio "$SUDO_USER"

# % Clear /var/crash
sudo rm -rf /var/crash/*

# % Fix /lib/firmware symlink, overlays symlink
sudo ln -s /lib/firmware /etc/firmware
sudo ln -s /boot/firmware/overlays /boot/overlays

# % Fix WiFi
# % The Pi 4 version returns boardflags3=0x44200100
# % The Pi 3 version returns boardflags3=0x48200100cd
sudo sed -i "s:0x48200100:0x44200100:g" /lib/firmware/brcm/brcmfmac43455-sdio.txt

# % Disable ib_iser iSCSI cloud module to prevent an error during systemd-modules-load at boot
sudo sed -i "s/ib_iser/#ib_iser/g" /lib/modules-load.d/open-iscsi.conf
sudo sed -i "s/iscsi_tcp/#iscsi_tcp/g" /lib/modules-load.d/open-iscsi.conf

# % Add udev rule so users can use vcgencmd without sudo
sudo echo "SUBSYSTEM==\"vchiq\", GROUP=\"video\", MODE=\"0660\"" > /etc/udev/rules.d/10-local-rpi.rules

# % Fix update-initramfs mdadm.conf warning
#sudo grep "ARRAY devices" /etc/mdadm/mdadm.conf >/dev/null || echo "ARRAY devices=/dev/sda" | sudo tee -a /etc/mdadm/mdadm.conf >/dev/null;

# Startup tweaks to fix bluetooth and sound issues
sudo rm /etc/rc.local
sudo touch /etc/rc.local
cat << EOF | sudo tee /etc/rc.local
#!/bin/bash
#
# rc.local
#

# Fix sound by setting tsched = 0 and disabling analog mapping so Pulse maps the devices in stereo
if [ -n "`which pulseaudio`" ]; then
  GrepCheck=$(cat /etc/pulse/default.pa | grep "tsched=0")
  if [ -z "$GrepCheck" ]; then
    sed -i "s:load-module module-udev-detect:load-module module-udev-detect tsched=0:g" /etc/pulse/default.pa
  else
    GrepCheck=$(cat /etc/pulse/default.pa | grep "tsched=0 tsched=0")
    if [ ! -z "$GrepCheck" ]; then
        sed -i 's/tsched=0//g' /etc/pulse/default.pa
        sed -i "s:load-module module-udev-detect:load-module module-udev-detect tsched=0:g" /etc/pulse/default.pa
    fi
  fi

  GrepCheck=$(cat /usr/share/pulseaudio/alsa-mixer/profile-sets/default.conf | grep "device-strings = fake")
  if [ -z "$GrepCheck" ]; then
    sed -i '/^\[Mapping analog-mono\]/,+1s/device-strings = hw\:\%f.*/device-strings = fake\:\%f/' /usr/share/pulseaudio/alsa-mixer/profile-sets/default.conf
    pulseaudio -k
    pulseaudio --start
  fi
fi

# Fix cups
if [ -e /etc/modules-load.d/cups-filters.conf ]; then
  rm /etc/modules-load.d/cups-filters.conf
  systemctl restart systemd-modules-load cups
fi

# Enable bluetooth
if [ -n "`which hciattach`" ]; then
  echo "Attaching Bluetooth controller ..."
  hciattach /dev/ttyAMA0 bcm43xx 921600
fi

# Makes udev mounts visible
if [ "$(systemctl show systemd-udevd | grep 'MountFlags' | cut -d = -f 2)" != "shared" ]; then
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
sudo rm -f /lib/systemd/system/triggerhappy.socket

exit 0
EOF
sudo chmod +x /etc/rc.local

# Fix netplan
GrepCheck=$(cat /etc/netplan/50-cloud-init.yaml | grep "optional: true")
if [ -z "$GrepCheck" ]; then
    sudo rm -f /etc/netplan/50-cloud-init.yaml
    sudo touch /etc/netplan/50-cloud-init.yaml
    cat << EOF | sudo tee /etc/netplan/50-cloud-init.yaml
    network:
        ethernets:
            eth0:
                dhcp4: true
                optional: true
        version: 2
EOF
    sudo netplan generate 
    sudo netplan --debug apply
fi

echo "Update completed!"
echo "Note: it is recommended to periodically clean out the old kernel source from /usr/src, it's quite large!"
echo "You should now reboot the system."