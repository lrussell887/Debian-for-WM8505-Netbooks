# Debian for Wondermedia 8505 Netbooks
This repository is a further amalgamation of work done by many others to bring Debian to WM8505-powered netbooks. In my case, the Sylvania SYNET07526. While they have gotten close, no other projects have offered a fully-functioning build for the device. This project aims to change that, creating a kernel build complete with modules and a Debian system complete with all standard utilities.

## Credits
Much of this work has been inspired by [wh0's bookconfig](https://github.com/wh0/bookconfig) project. The *kernel.tar.xz* file included is a direct clone of their kernel repository, simply included for ease of use. They were able to bring the custom device drivers needed in the kernel to a more modern Linux 4.5. Many of the scripts (including networking and udev) found in the *etc* folder were borrowed from their repository as well. Key build steps were also taken from [jubinson's debian-rootfs](https://github.com/jubinson/debian-rootfs) in order to effectively use Multistrap in the build process. I would also like to thank those involved in the [linux-vtwm](https://github.com/linux-wmt/linux-vtwm) project for their work in developing Kernel support for these devices.

## Build disclosures
* Debian is pre-configured during the build process, it will boot directly in a ready-to-use system.
* You will need to first login as root, which has no password set. I recommend immediately setting one and creating user account(s).
* The hostname is set to *netbook* by default.
* A 512 MB swap file is generated and enabled on first boot. I suggest keeping this given these systems have only 128 MB of RAM.
* WPA Supplicant and OpenSSH Server are also included beyond the standard utilities.
* *Predictable Network Interface Names* have been disabled in Systemd for the sake of Wi-Fi configuration.
* The *resolv.conf* configuration file is set to use Google DNS.
* The *eth0* interface is set to allow-hotplug and to use DHCP. Interface *wlan0* is set to manual, *wpa-cli* may be used to configure Wi-Fi.

## Pre-compiled builds
Builds are available under the releases page, download both the *boot.zip* and *rootfs.tar.gz* files for the build you would like and skip to the "Using the build" section.

## Build procedure
I recommend building this on a Debian system closely matching the version you are building. I personally used Debian 9.8 with XFCE in a virtual machine. Clone this repository to your machine and ensure the necessary packages are installed. Set *build.sh* to executable if it's not already, and run it! Once it has completed, you will have *boot.zip* and *rootfs.tar.gz* files in the parent directory.

### Required packages
* aptitude
* bc
* binfmt-support
* build-essential
* debian-archive-keyring
* debootstrap
* gcc-arm-linux-gnueabi
* libncurses5-dev
* libssl-dev
* multistrap
* qemu-user-static
* u-boot-tools
* zip

## Using the build
In order to get a build running, you will need an 8 GB SD card (recommended, it can be smaller) and a Linux machine with GParted. On the card, first create a 16 MB FAT16 partition, followed by an EXT4 partition that fills the rest of the card. You will then want to extract the *boot.zip* file to the FAT16 partition, and *rootfs.tar.gz* file to the EXT4 partition. Once that is completed, insert the card into your netbook and boot into your new Debian system!

### Extraction example
```
cd /mnt
mkdir boot rootfs
mount /dev/sd*1 boot/
mount /dev/sd*2 rootfs/
unzip /path/to/boot.zip -d boot/
tar xvzf /path/to/rootfs.tar.gz -C rootfs/
umount boot/ rootfs/
eject /dev/sd*
```

### Partition example
![GParted partition example screenshot](http://i.imgur.com/ar47xMb.png)
