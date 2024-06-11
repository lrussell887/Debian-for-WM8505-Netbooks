# Debian for Wondermedia 8505 Netbooks
This project delivers a complete Debian build for WM8505-powered netbooks. It has been specifically built for the Sylvania SYNET07526, though it should work on similar devices. The [kernel](https://github.com/lrussell887/linux-vtwm) used is a rebase of linux-vtwm, a repository with patches for VIA VT8500 and Wondermedia WM8xxx SoCs. For kernel config, `config.armel_none_marvell` from Debian's [linux-config-6.1](https://packages.debian.org/bookworm/armel/linux-config-6.1) package is used as a base, and adapted to be compatible with the netbook.  Finally, `multistrap` is used to build the root filesystem, including all standard system utilities. This ensures you have a modern kernel with all the expected packages and modules of a standard Debian system.

![Netbook running Debian](https://i.imgur.com/73nZJa5.png)

## Credits
This work is largely based on [wh0's bookconfig](https://github.com/wh0/bookconfig). My linux-vtwm repository is a rebase of wh0's kernel branch, which itself is a rebase of the abandoned [linux-vtwm](https://github.com/linux-wmt/linux-vtwm) project. It goes without saying this would not have been possible without them.

## Project Details
- **Packages:** The `multistrap.conf` file integrates all of Debian's standard system utilities by explicitly listing priority `important` and `standard` packages. Additional packages are included to provide Wi-Fi support, along with `openssh-server`, `sudo`, and `htop`.
- **First Boot:** It takes approximately 25 minutes to finish setting up packages on first boot. You will be prompted to set a hostname, configure your timezone, and create a user account. This user is added to the `sudo` group since a root password is not configured.
- **Swap File:** A 256 MB swap file is created and activated at first boot. It is handled by `var-swapfile.swap`.
- **Wi-Fi Configuration:** The Wi-Fi adapter is enabled on boot by default using `wlan-gpio.service`. You can configure your network via `nmtui`.
- **Display Brightness:** Brightness is managed by `/etc/udev/rules.d/10-display.rules` and defaults to full brightness (value 128). Changes require file modification and a reboot. The kernel also now defaults to 128 (rather than 16), meaning the screen will be full brightness during startup.
- **Audio Support:** Built-in audio is currently not working, though USB sound cards are tested to work normally.
- **Performance:** The WM8505 was not fast even when new, and especially not now with a modern operating system. Even `apt` updates and installations can take quite some time, and there is no graphics acceleration. Consider this a vintage computer.

## Pre-compiled Builds
Pre-compiled builds are available on the Releases page. Download the `boot.zip` and `rootfs.tar.gz` files for the current build, then proceed to the "Using the Build" section below.

## Build Procedure
Building requires a Debian-based system due to its use of `multistrap`. You must also run as root. Follow these steps:
1. Clone this repository.
2. Install the necessary packages: `bc binfmt-support build-essential debian-archive-keyring gcc-arm-linux-gnueabi libncurses5-dev libssl-dev multistrap u-boot-tools zip`
3. Run `build.sh` to start the build process. The resulting `boot.zip` and `rootfs.tar.gz` files will be created in the parent directory.

## Using the Build
### Partitioning
You will need an SD card (tested up to 64 GB) with two partitions:
1. A 32 MB FAT32 partition
2. An EXT4 partition using the remaining space

![GParted partition example screenshot](https://i.imgur.com/gRDMqo1.png)

### Extraction
After partitioning your SD card, do the following as root, substituting `/dev/sdX` with the correct device:
```bash
cd /mnt
mkdir boot rootfs
mount /dev/sdX1 boot/
mount /dev/sdX2 rootfs/
unzip /path/to/boot.zip -d boot/
tar xvzf /path/to/rootfs.tar.gz -C rootfs/
umount boot/ rootfs/
eject /dev/sdX
```
