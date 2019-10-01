## Introduction

This is an initial testing pre-release of a unofficial build of Ubuntu Server 18.04.3 preinstalled server for the new
(and currently unsupported officially) Raspberry Pi 4.

I have included both the script to create it yourself from the official images as a base as well as a precompiled image
that you can download and simply write straight to your SD card.
The included script makes the process of modifying the current official release to work on the Raspberry Pi 4 much 
easier.

For more information visit https://jamesachambers.com/raspberry-pi-4-ubuntu-server-desktop-18-04-3-image-unofficial/ or
including a walkthrough and lots of comments / discussion.

All 4 GB of RAM are available in this preinstalled image.
WiFi, Bluetooth, and other drivers have been updated for the Raspberry Pi 4.

This will hold the package so it doesn't break your installation while letting you fully update everything else until
official support is released.

To download the prebuilt image go to the ["Releases"](releases) section to get the download.

## Building the Image

You will need [GNU Make](https://www.gnu.org/software/make/),
[Hashicorp Vagrant](https://www.vagrantup.com) and one of 
[Oracle Virtualbox](https://www.virtualbox.org), 
[VMWare Fusion](https://www.vmware.com/products/fusion.html) (on macOS) or
[VMWare Workstation Pro](https://www.vmware.com/products/workstation-pro.html) (on Linux).
Windows is not supported at this time.

Once you've checked out this repository and `cd`ed into it, do:

    make

This will provision a virtual machine and run the build process in it.
Once succeeded, you will find the image in `vagrant/build/ubuntu-18.04.3-preinstalled-server-arm64+raspi4.img`.

Enjoy!
